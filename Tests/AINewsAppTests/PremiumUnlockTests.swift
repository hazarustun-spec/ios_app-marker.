import XCTest
@testable import AINewsApp

@MainActor
final class PremiumUnlockTests: XCTestCase {

    // Premium aldıktan sonra canFullyRead anında değişir (UI re-render tetikler)
    func test_purchasePremium_immediatelyUnlocksAllTopics() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(), isPremium: false, deliveryTime: "08:00",
            timezone: "Europe/Istanbul", apnsToken: nil,
            selectedTopicIds: ["llms", "research"]  // sadece 2 seçili
        )

        // Free kullanıcı için: vision haberi locked
        let visionNews = makeNews(topicId: "vision")
        XCTAssertFalse(appState.canFullyRead(visionNews))

        // Premium aktivasyonu — refreshPremiumStatus benzeri davranış
        appState.profile.isPremium = true

        // Hemen tüm topic'ler unlock olmalı
        XCTAssertTrue(appState.canFullyRead(visionNews))
        XCTAssertTrue(appState.canFullyRead(makeNews(topicId: "robotics")))
        XCTAssertTrue(appState.canFullyRead(makeNews(topicId: "healthcare")))
    }

    // Premium iptal edilirse (subscription expired) eski free kuralları geri gelir
    func test_premiumExpiry_relocksUnselectedTopics() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(), isPremium: true, deliveryTime: "08:00",
            timezone: "Europe/Istanbul", apnsToken: nil,
            selectedTopicIds: ["llms"]
        )

        let robotics = makeNews(topicId: "robotics")
        XCTAssertTrue(appState.canFullyRead(robotics))

        // Subscription expired
        appState.profile.isPremium = false

        XCTAssertFalse(appState.canFullyRead(robotics))
        XCTAssertTrue(appState.canFullyRead(makeNews(topicId: "llms"))) // seçili olan hala açık
    }

    // Selected topic'ler değişirse free kullanıcının erişimi de değişir
    func test_changingSelectedTopics_updatesAccess() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(), isPremium: false, deliveryTime: "08:00",
            timezone: "Europe/Istanbul", apnsToken: nil,
            selectedTopicIds: ["llms"]
        )

        XCTAssertFalse(appState.canFullyRead(makeNews(topicId: "vision")))

        // Kullanıcı vision'ı seçti
        appState.profile.selectedTopicIds.append("vision")

        XCTAssertTrue(appState.canFullyRead(makeNews(topicId: "vision")))
    }

    // MARK: - Helpers
    private func makeNews(topicId: String) -> NewsItem {
        NewsItem(
            id: UUID(), topicId: topicId, date: Date(),
            title: "Test", summary: "Özet.", body: "Gövde.",
            sourceUrls: ["https://example.com"], createdAt: Date()
        )
    }
}
