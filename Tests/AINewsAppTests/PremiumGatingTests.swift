import XCTest
@testable import AINewsApp

@MainActor
final class PremiumGatingTests: XCTestCase {

    // canFullyRead premium kullanıcıya tüm haberlere erişim verir
    func test_premiumUser_canReadAnyTopic() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(),
            isPremium: true,
            deliveryTime: "08:00",
            timezone: "Europe/Istanbul",
            apnsToken: nil,
            selectedTopicIds: ["llms"]
        )

        let robotics = makeNews(topicId: "robotics")
        let healthcare = makeNews(topicId: "healthcare")

        XCTAssertTrue(appState.canFullyRead(robotics))
        XCTAssertTrue(appState.canFullyRead(healthcare))
    }

    // Free kullanıcı SADECE seçtiği topic'leri okuyabilir
    func test_freeUser_onlyReadsSelectedTopics() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(),
            isPremium: false,
            deliveryTime: "08:00",
            timezone: "Europe/Istanbul",
            apnsToken: nil,
            selectedTopicIds: ["llms", "research", "vision"]
        )

        let llms = makeNews(topicId: "llms")
        let research = makeNews(topicId: "research")
        let robotics = makeNews(topicId: "robotics")
        let policy = makeNews(topicId: "policy")

        XCTAssertTrue(appState.canFullyRead(llms))
        XCTAssertTrue(appState.canFullyRead(research))
        XCTAssertFalse(appState.canFullyRead(robotics))
        XCTAssertFalse(appState.canFullyRead(policy))
    }

    // Free kullanıcı 0 topic seçmiş ise hiçbir şey okuyamaz
    func test_freeUser_emptySelection_locksAll() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(),
            isPremium: false,
            deliveryTime: "08:00",
            timezone: "Europe/Istanbul",
            apnsToken: nil,
            selectedTopicIds: []
        )

        let llms = makeNews(topicId: "llms")
        XCTAssertFalse(appState.canFullyRead(llms))
    }

    // MARK: - Helpers
    private func makeNews(topicId: String) -> NewsItem {
        NewsItem(
            id: UUID(),
            topicId: topicId,
            date: Date(),
            title: "Test başlığı",
            summary: "Test özet.",
            body: "Test gövde.",
            sourceUrls: ["https://example.com"],
            createdAt: Date()
        )
    }
}
