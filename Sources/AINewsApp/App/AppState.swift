import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published state
    @Published var isAuthenticated: Bool = false
    @Published var isOnboardingComplete: Bool = false
    @Published var profile: UserProfile = .default
    @Published var savedNewsIds: Set<UUID> = []
    @Published var isLoadingAuth: Bool = true
    @Published var notificationsEnabled: Bool = false
    @Published var authError: String? = nil

    private let db = SupabaseManager.shared
    let notifications = NotificationManager.shared
    private var currentNonce: String = ""

    // Delivery time in minutes since midnight (default 08:00)
    var deliveryHour: Int {
        get { UserDefaults.standard.integer(forKey: "deliveryHour") == 0 ? 8 : UserDefaults.standard.integer(forKey: "deliveryHour") }
        set { UserDefaults.standard.set(newValue, forKey: "deliveryHour") }
    }
    var deliveryMinute: Int {
        get { UserDefaults.standard.integer(forKey: "deliveryMinute") }
        set { UserDefaults.standard.set(newValue, forKey: "deliveryMinute") }
    }

    init() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")
        loadCachedProfile()
        loadCachedSavedIds()
        Task {
            await restoreSession()
            await notifications.checkAuthorization()
            notificationsEnabled = notifications.isAuthorized
        }
    }

    // MARK: - Session restore
    func restoreSession() async {
        defer { isLoadingAuth = false }
        guard let user = await db.currentUser else { return }
        isAuthenticated = true
        await loadProfileFromSupabase(userId: user.id)
    }

    // MARK: - Apple Sign In
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        // Consume nonce immediately so a stale value can't be reused
        let consumedNonce = currentNonce
        currentNonce = ""

        authError = nil
        switch result {
        case .failure(let err):
            let nsErr = err as NSError
            if nsErr.code == 1001 {
                // User cancelled — silent
                return
            }
            Log.error("Apple sign-in error: \(err)")
            authError = "Apple ile giriş başarısız oldu. Tekrar dene."

        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8)
            else {
                authError = "Apple kimlik bilgisi okunamadı."
                return
            }

            guard !consumedNonce.isEmpty else {
                authError = "Oturum doğrulaması zamanlama hatası. Tekrar dene."
                return
            }

            do {
                let session = try await db.signInWithApple(idToken: idToken, nonce: consumedNonce)
                isAuthenticated = true
                authError = nil
                await loadProfileFromSupabase(userId: session.user.id)
            } catch {
                Log.error("Supabase sign-in error: \(error)")
                authError = "Sunucu doğrulaması başarısız. Tekrar dene."
            }
        }
    }


    // MARK: - Notifications
    func requestNotificationPermission() async -> Bool {
        let granted = await notifications.requestPermission()
        notificationsEnabled = granted
        if granted {
            await notifications.scheduleDailyNotification(hour: deliveryHour, minute: deliveryMinute)
        }
        return granted
    }

    func updateDeliveryTime(hour: Int, minute: Int) async {
        deliveryHour = hour
        deliveryMinute = minute
        if notificationsEnabled {
            await notifications.scheduleDailyNotification(hour: hour, minute: minute)
        }
    }

    func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Premium (StoreKit)
    func refreshPremiumStatus() async {
        let isPremium = await StoreKitManager.shared.hasActivePremium()
        if isPremium != profile.isPremium {
            profile.isPremium = isPremium
            cacheProfile()
            if isAuthenticated, let user = db.client.auth.currentUser {
                try? await db.updateProfile(ProfileUpdate(isPremium: isPremium), userId: user.id)
            }
        }
    }

    // MARK: - Delete account (GDPR / App Store requirement)
    func deleteAccount() async {
        guard isAuthenticated, let user = db.client.auth.currentUser else { return }
        // Profile deletion cascades to user_topics, saved_news via FK
        do {
            // Delete profile (cascades user data)
            try await db.client.from("profiles").delete().eq("id", value: user.id.uuidString).execute()
            // Sign out from auth
            try? await db.signOut()
        } catch {
            Log.error("Account deletion error: \(error)")
        }
        // Wipe local
        UserDefaults.standard.removeObject(forKey: "onboardingComplete")
        UserDefaults.standard.removeObject(forKey: "cachedProfile")
        UserDefaults.standard.removeObject(forKey: "savedNewsCache")
        UserDefaults.standard.removeObject(forKey: "savedNewsIds")
        isAuthenticated = false
        isOnboardingComplete = false
        profile = .default
        savedNewsIds = []
    }

    // MARK: - Sign out
    func signOut() {
        Task {
            try? await db.signOut()
        }
        isAuthenticated = false
        isOnboardingComplete = false
        profile = .default
        savedNewsIds = []
        UserDefaults.standard.removeObject(forKey: "onboardingComplete")
        UserDefaults.standard.removeObject(forKey: "cachedProfile")
    }

    // MARK: - Onboarding
    func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        Task { await syncTopicsToSupabase() }
    }

    // MARK: - Profile loading
    private func loadProfileFromSupabase(userId: UUID) async {
        do {
            let row = try await db.fetchProfile(userId: userId)
            let topicIds = try await db.fetchUserTopics(userId: userId)
            profile = row.toUserProfile(selectedTopicIds: topicIds)
            cacheProfile()
        } catch {
            Log.error("Profile load error: \(error)")
            loadCachedProfile()
        }
    }

    // MARK: - Topic management
    func selectTopic(_ topic: Topic) {
        guard !profile.selectedTopicIds.contains(topic.id),
              profile.canAddMoreTopics else { return }
        profile.selectedTopicIds.append(topic.id)
        cacheProfile()
        if isAuthenticated, let userId = try? UUID(uuidString: SupabaseManager.shared.client.auth.currentUser?.id.uuidString ?? "") {
            Task { try? await db.addUserTopic(userId: userId, topicId: topic.id) }
        }
    }

    func deselectTopic(_ topic: Topic) {
        profile.selectedTopicIds.removeAll { $0 == topic.id }
        cacheProfile()
        if isAuthenticated, let userId = try? UUID(uuidString: SupabaseManager.shared.client.auth.currentUser?.id.uuidString ?? "") {
            Task { try? await db.removeUserTopic(userId: userId, topicId: topic.id) }
        }
    }

    private func syncTopicsToSupabase() async {
        guard isAuthenticated,
              let user = await db.currentUser else { return }
        for topicId in profile.selectedTopicIds {
            try? await db.addUserTopic(userId: user.id, topicId: topicId)
        }
    }

    // MARK: - Saved news
    func toggleSave(news: NewsItem) {
        if savedNewsIds.contains(news.id) {
            savedNewsIds.remove(news.id)
            removeSavedNewsCache(id: news.id)
            if isAuthenticated, let user = SupabaseManager.shared.client.auth.currentUser {
                Task { try? await db.unsaveNews(userId: user.id, newsId: news.id) }
            }
        } else {
            savedNewsIds.insert(news.id)
            cacheSavedNews(news)
            if isAuthenticated, let user = SupabaseManager.shared.client.auth.currentUser {
                Task { try? await db.saveNews(userId: user.id, newsId: news.id) }
            }
        }
    }

    func isSaved(_ news: NewsItem) -> Bool {
        savedNewsIds.contains(news.id)
    }

    // MARK: - Local saved news cache (works offline / unauthenticated)
    private let savedNewsCacheKey = "savedNewsCache"
    private let savedNewsIdsKey = "savedNewsIds"

    func loadCachedSavedNews() -> [NewsItem] {
        guard let data = UserDefaults.standard.data(forKey: savedNewsCacheKey),
              let items = try? JSONDecoder().decode([NewsItem].self, from: data)
        else { return [] }
        return items
    }

    private func cacheSavedNews(_ news: NewsItem) {
        var items = loadCachedSavedNews()
        if !items.contains(where: { $0.id == news.id }) {
            items.insert(news, at: 0)
        }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: savedNewsCacheKey)
        }
        persistSavedNewsIds()
    }

    private func removeSavedNewsCache(id: UUID) {
        var items = loadCachedSavedNews()
        items.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: savedNewsCacheKey)
        }
        persistSavedNewsIds()
    }

    private func persistSavedNewsIds() {
        let ids = savedNewsIds.map { $0.uuidString }
        UserDefaults.standard.set(ids, forKey: savedNewsIdsKey)
    }

    func loadCachedSavedIds() {
        guard let strs = UserDefaults.standard.array(forKey: savedNewsIdsKey) as? [String] else { return }
        savedNewsIds = Set(strs.compactMap(UUID.init))
    }

    // Premium gating: free users can only fully read news from selected topics
    func canFullyRead(_ news: NewsItem) -> Bool {
        if profile.isPremium { return true }
        return profile.selectedTopicIds.contains(news.topicId)
    }

    // MARK: - Nonce for Sign in with Apple
    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess { fatalError("SecRandomCopyBytes failed") }
                return random
            }
            randoms.forEach { byte in
                if remainingLength == 0 { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Local cache
    private func cacheProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "cachedProfile")
        }
    }

    private func loadCachedProfile() {
        guard let data = UserDefaults.standard.data(forKey: "cachedProfile"),
              let saved = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return }
        profile = saved
    }
}
