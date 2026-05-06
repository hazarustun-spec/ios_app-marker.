import XCTest
@testable import AINewsApp

@MainActor
final class SavedNewsCacheTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "savedNewsCache")
        UserDefaults.standard.removeObject(forKey: "savedNewsIds")
    }

    // Yer imi eklenince lokal cache'e yazılır (offline çalışsın)
    func test_toggleSave_persistsLocally() {
        let appState = AppState()
        appState.profile = UserProfile(
            id: UUID(), isPremium: false, deliveryTime: "08:00",
            timezone: "Europe/Istanbul", apnsToken: nil, selectedTopicIds: ["llms"]
        )

        let news = makeNews(topicId: "llms", title: "Test haberi 1")
        XCTAssertFalse(appState.isSaved(news))

        appState.toggleSave(news: news)
        XCTAssertTrue(appState.isSaved(news))

        // Cache yenisi: aynı haber lokal storage'da var mı?
        let cached = appState.loadCachedSavedNews()
        XCTAssertEqual(cached.count, 1)
        XCTAssertEqual(cached.first?.id, news.id)
        XCTAssertEqual(cached.first?.title, "Test haberi 1")
    }

    // Yer imini geri kaldırınca cache'den de silinir
    func test_toggleSave_unsavesAndRemovesFromCache() {
        let appState = AppState()
        appState.profile = .default

        let news = makeNews(topicId: "llms", title: "Silinecek haber")
        appState.toggleSave(news: news)
        XCTAssertEqual(appState.loadCachedSavedNews().count, 1)

        appState.toggleSave(news: news)
        XCTAssertFalse(appState.isSaved(news))
        XCTAssertEqual(appState.loadCachedSavedNews().count, 0)
    }

    // Birden fazla haber kayıtlı tutulabilir
    func test_multipleSaved_allCached() {
        let appState = AppState()
        appState.profile = .default

        for i in 1...3 {
            appState.toggleSave(news: makeNews(topicId: "llms", title: "Haber \(i)"))
        }

        XCTAssertEqual(appState.savedNewsIds.count, 3)
        XCTAssertEqual(appState.loadCachedSavedNews().count, 3)
    }

    // App restart sonrası cache'den ID'ler yüklenir
    func test_loadCachedSavedIds_reloadsFromDisk() {
        let appState1 = AppState()
        appState1.profile = .default
        let news = makeNews(topicId: "llms", title: "Persistent")
        appState1.toggleSave(news: news)

        // Yeni AppState — init'te cache load edilmeli
        let appState2 = AppState()
        XCTAssertTrue(appState2.savedNewsIds.contains(news.id))
    }

    // MARK: - Helpers
    private func makeNews(topicId: String, title: String = "Test") -> NewsItem {
        NewsItem(
            id: UUID(), topicId: topicId, date: Date(),
            title: title, summary: "Özet.", body: "Gövde.",
            sourceUrls: ["https://example.com"], createdAt: Date()
        )
    }
}
