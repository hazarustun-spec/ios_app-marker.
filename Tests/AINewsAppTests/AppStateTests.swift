import XCTest
@testable import AINewsApp

@MainActor
final class AppStateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Lokalden testlerin etkilenmemesi için temizle
        UserDefaults.standard.removeObject(forKey: "onboardingComplete")
        UserDefaults.standard.removeObject(forKey: "cachedProfile")
        UserDefaults.standard.removeObject(forKey: "savedNewsCache")
        UserDefaults.standard.removeObject(forKey: "savedNewsIds")
        UserDefaults.standard.removeObject(forKey: "deliveryHour")
        UserDefaults.standard.removeObject(forKey: "deliveryMinute")
    }

    // generateNonce her seferinde farklı bir hash döndürmeli
    func test_generateNonce_returnsUniqueHashes() {
        let appState = AppState()
        let nonce1 = appState.generateNonce()
        let nonce2 = appState.generateNonce()
        XCTAssertNotEqual(nonce1, nonce2, "Her nonce çağrısı yeni bir değer üretmeli")
        XCTAssertFalse(nonce1.isEmpty)
        XCTAssertEqual(nonce1.count, 64, "SHA256 hex 64 karakter olmalı")
    }

    // Onboarding tamamlanırsa UserDefaults'a yazılır
    func test_completeOnboarding_persistsFlag() {
        let appState = AppState()
        XCTAssertFalse(appState.isOnboardingComplete)
        appState.completeOnboarding()
        XCTAssertTrue(appState.isOnboardingComplete)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "onboardingComplete"))
    }

    // Topic seç/kaldır mantığı
    func test_topicSelectionToggle() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(),
            isPremium: false,
            deliveryTime: "08:00",
            timezone: "Europe/Istanbul",
            apnsToken: nil,
            selectedTopicIds: []
        )
        let topic = Topic.all[0]  // llms

        XCTAssertFalse(appState.profile.selectedTopicIds.contains(topic.id))
        appState.selectTopic(topic)
        XCTAssertTrue(appState.profile.selectedTopicIds.contains(topic.id))

        appState.deselectTopic(topic)
        XCTAssertFalse(appState.profile.selectedTopicIds.contains(topic.id))
    }

    // Free kullanıcı 3 topic limit'i
    func test_freeUser_topicLimit() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(),
            isPremium: false,
            deliveryTime: "08:00",
            timezone: "Europe/Istanbul",
            apnsToken: nil,
            selectedTopicIds: []
        )

        // 3 ekleyebilir
        for i in 0..<3 {
            appState.selectTopic(Topic.all[i])
        }
        XCTAssertEqual(appState.profile.selectedTopicIds.count, 3)

        // 4. eklenmeli mi? canAddMoreTopics false olmalı
        XCTAssertFalse(appState.profile.canAddMoreTopics)

        // selectTopic çağrısı sessizce reddedilmeli
        appState.selectTopic(Topic.all[3])
        XCTAssertEqual(appState.profile.selectedTopicIds.count, 3, "Free user 3'ten fazla topic seçemez")
    }

    // Premium kullanıcı 10'a kadar seçebilir
    func test_premiumUser_topicLimit() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(),
            isPremium: true,
            deliveryTime: "08:00",
            timezone: "Europe/Istanbul",
            apnsToken: nil,
            selectedTopicIds: []
        )

        for topic in Topic.all {
            appState.selectTopic(topic)
        }
        XCTAssertEqual(appState.profile.selectedTopicIds.count, 10)
    }

    // Sign out tüm state'i temizler
    func test_signOut_clearsState() {
        let appState = AppState()
        appState.isAuthenticated = true
        appState.isOnboardingComplete = true
        appState.profile = UserProfile(
            id: UUID(),
            isPremium: true,
            deliveryTime: "08:00",
            timezone: "Europe/Istanbul",
            apnsToken: nil,
            selectedTopicIds: ["llms", "research"]
        )

        appState.signOut()

        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertFalse(appState.isOnboardingComplete)
        XCTAssertEqual(appState.profile.selectedTopicIds, [])
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "onboardingComplete"))
    }
}
