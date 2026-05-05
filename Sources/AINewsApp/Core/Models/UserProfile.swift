import Foundation

struct UserProfile: Codable {
    let id: UUID
    var isPremium: Bool
    var deliveryTime: String   // "HH:mm" format
    var timezone: String
    var apnsToken: String?
    var selectedTopicIds: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case isPremium     = "is_premium"
        case deliveryTime  = "delivery_time"
        case timezone
        case apnsToken     = "apns_token"
        case selectedTopicIds
    }

    static let freeTopicLimit = 3
    static let premiumTopicLimit = 10

    var topicLimit: Int {
        isPremium ? UserProfile.premiumTopicLimit : UserProfile.freeTopicLimit
    }

    var canAddMoreTopics: Bool {
        selectedTopicIds.count < topicLimit
    }
}

extension UserProfile {
    static let `default` = UserProfile(
        id: UUID(),
        isPremium: false,
        deliveryTime: "08:00",
        timezone: "Europe/Istanbul",
        apnsToken: nil,
        selectedTopicIds: []
    )
}
