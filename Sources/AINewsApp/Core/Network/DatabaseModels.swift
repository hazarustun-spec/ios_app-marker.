import Foundation

// MARK: - Database row types (Supabase → Swift)
// These mirror the exact column names from schema.sql

struct ProfileRow: Codable {
    let id: UUID
    var isPremium: Bool
    var deliveryTime: String
    var timezone: String
    var apnsToken: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case isPremium   = "is_premium"
        case deliveryTime = "delivery_time"
        case timezone
        case apnsToken   = "apns_token"
        case createdAt   = "created_at"
    }

    func toUserProfile(selectedTopicIds: [String]) -> UserProfile {
        UserProfile(
            id: id,
            isPremium: isPremium,
            deliveryTime: deliveryTime,
            timezone: timezone,
            apnsToken: apnsToken,
            selectedTopicIds: selectedTopicIds
        )
    }
}

struct ProfileUpdate: Encodable {
    var isPremium: Bool? = nil
    var deliveryTime: String? = nil
    var apnsToken: String? = nil

    enum CodingKeys: String, CodingKey {
        case isPremium   = "is_premium"
        case deliveryTime = "delivery_time"
        case apnsToken   = "apns_token"
    }
}

struct TopicRow: Codable {
    let id: String
    let name: String
    let emoji: String
    let description: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, description
        case sortOrder = "sort_order"
    }

    func toTopic() -> Topic {
        Topic(id: id, name: name, emoji: emoji, description: description)
    }
}

struct UserTopicRow: Codable {
    let topicId: String

    enum CodingKeys: String, CodingKey {
        case topicId = "topic_id"
    }
}

struct NewsItemRow: Codable {
    let id: UUID
    let topicId: String
    let date: String       // "YYYY-MM-DD"
    let title: String
    let summary: String
    let body: String
    let sourceUrls: [String]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case topicId    = "topic_id"
        case date
        case title
        case summary
        case body
        case sourceUrls = "source_urls"
        case createdAt  = "created_at"
    }

    func toNewsItem() -> NewsItem {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let parsedDate = dateFormatter.date(from: date) ?? Date()

        return NewsItem(
            id: id,
            topicId: topicId,
            date: parsedDate,
            title: title,
            summary: summary,
            body: body,
            sourceUrls: sourceUrls,
            createdAt: createdAt
        )
    }
}

struct SavedNewsRow: Codable {
    let newsItems: NewsItemRow

    enum CodingKeys: String, CodingKey {
        case newsItems = "news_items"
    }
}
