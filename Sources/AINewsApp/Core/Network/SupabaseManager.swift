import Foundation
import Supabase

// MARK: - Singleton client
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.url)!,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
}

// MARK: - Auth
extension SupabaseManager {
    var auth: AuthClient { client.auth }

    func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        try await auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
    }

    func signOut() async throws {
        try await auth.signOut()
    }

    var currentUser: User? {
        get async { try? await auth.user() }
    }
}

// MARK: - Profile
extension SupabaseManager {
    func fetchProfile(userId: UUID) async throws -> ProfileRow {
        try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    func updateProfile(_ update: ProfileUpdate, userId: UUID) async throws {
        try await client
            .from("profiles")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func updateAPNSToken(_ token: String, userId: UUID) async throws {
        try await updateProfile(ProfileUpdate(apnsToken: token), userId: userId)
    }
}

// MARK: - Topics
extension SupabaseManager {
    func fetchTopics() async throws -> [TopicRow] {
        try await client
            .from("topics")
            .select()
            .order("sort_order")
            .execute()
            .value
    }
}

// MARK: - User Topics
extension SupabaseManager {
    func fetchUserTopics(userId: UUID) async throws -> [String] {
        let rows: [UserTopicRow] = try await client
            .from("user_topics")
            .select("topic_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return rows.map(\.topicId)
    }

    func addUserTopic(userId: UUID, topicId: String) async throws {
        try await client
            .from("user_topics")
            .insert(["user_id": userId.uuidString, "topic_id": topicId])
            .execute()
    }

    func removeUserTopic(userId: UUID, topicId: String) async throws {
        try await client
            .from("user_topics")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("topic_id", value: topicId)
            .execute()
    }
}

// MARK: - News Items
extension SupabaseManager {
    func fetchTodayNews(topicIds: [String]) async throws -> [NewsItemRow] {
        let today = ISO8601DateFormatter.dateOnly.string(from: Date())
        if topicIds.isEmpty {
            return try await client
                .from("news_items")
                .select()
                .eq("date", value: today)
                .order("created_at")
                .execute()
                .value
        } else {
            return try await client
                .from("news_items")
                .select()
                .eq("date", value: today)
                .in("topic_id", values: topicIds)
                .order("created_at")
                .execute()
                .value
        }
    }

    func fetchNewsForDate(_ date: Date, topicIds: [String]) async throws -> [NewsItemRow] {
        let dateStr = ISO8601DateFormatter.dateOnly.string(from: date)
        if topicIds.isEmpty {
            return try await client
                .from("news_items")
                .select()
                .eq("date", value: dateStr)
                .order("created_at")
                .execute()
                .value
        } else {
            return try await client
                .from("news_items")
                .select()
                .eq("date", value: dateStr)
                .in("topic_id", values: topicIds)
                .order("created_at")
                .execute()
                .value
        }
    }
}

// MARK: - Saved News
extension SupabaseManager {
    func fetchSavedNews(userId: UUID) async throws -> [NewsItemRow] {
        // Join saved_news with news_items
        try await client
            .from("saved_news")
            .select("news_items(*)")
            .eq("user_id", value: userId.uuidString)
            .order("saved_at", ascending: false)
            .execute()
            .value
    }

    func saveNews(userId: UUID, newsId: UUID) async throws {
        try await client
            .from("saved_news")
            .insert(["user_id": userId.uuidString, "news_id": newsId.uuidString])
            .execute()
    }

    func unsaveNews(userId: UUID, newsId: UUID) async throws {
        try await client
            .from("saved_news")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("news_id", value: newsId.uuidString)
            .execute()
    }
}

// MARK: - Date helper
private extension ISO8601DateFormatter {
    static let dateOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }()
}
