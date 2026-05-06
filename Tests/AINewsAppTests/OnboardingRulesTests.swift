import XCTest
@testable import AINewsApp

@MainActor
final class OnboardingRulesTests: XCTestCase {

    // Free user maksimum 3 topic seçebilir (regression koruması)
    func test_freeUser_topicLimitIs3() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(), isPremium: false, deliveryTime: "08:00",
            timezone: "Europe/Istanbul", apnsToken: nil, selectedTopicIds: []
        )
        XCTAssertEqual(appState.profile.topicLimit, 3)
    }

    // Premium user 10 topic seçebilir
    func test_premiumUser_topicLimitIs10() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(), isPremium: true, deliveryTime: "08:00",
            timezone: "Europe/Istanbul", apnsToken: nil, selectedTopicIds: []
        )
        XCTAssertEqual(appState.profile.topicLimit, 10)
    }

    // Topic.all listesi 10 olmalı (DB ile uyumlu)
    func test_topicCatalog_has10Topics() {
        XCTAssertEqual(Topic.all.count, 10, "DB schema 10 topic seed ediyor — Topic.all eşleşmeli")
    }

    // canAddMoreTopics free için 3'te kapanır
    func test_canAddMoreTopics_blocksAfter3() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(), isPremium: false, deliveryTime: "08:00",
            timezone: "Europe/Istanbul", apnsToken: nil,
            selectedTopicIds: ["llms", "robotics", "research"]
        )
        XCTAssertFalse(appState.profile.canAddMoreTopics)
    }

    // canAddMoreTopics premium için 10'da kapanır
    func test_canAddMoreTopics_premiumBlocksAfter10() {
        let allIds = Topic.all.map(\.id)
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(), isPremium: true, deliveryTime: "08:00",
            timezone: "Europe/Istanbul", apnsToken: nil,
            selectedTopicIds: allIds
        )
        XCTAssertFalse(appState.profile.canAddMoreTopics)
    }
}
