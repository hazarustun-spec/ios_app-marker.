import SwiftUI

struct SavedView: View {
    @EnvironmentObject private var appState: AppState
    @State private var savedNews: [NewsItem] = []
    @State private var isLoading = true
    @State private var selectedNews: NewsItem? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        BriefLogo()
                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Kayıtlı.")
                            .font(.displayLG)
                            .foregroundStyle(Color.textPrimary)

                        Text("\(savedNews.count) haber · cihazlar arası senkron")
                            .font(.bodyMD)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)

                    if isLoading {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: Radius.xl)
                                .fill(Color.bgSecondary)
                                .frame(height: 140)
                                .padding(.horizontal, 22)
                                .redacted(reason: .placeholder)
                        }
                    } else if savedNews.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(savedNews.enumerated()), id: \.element.id) { idx, item in
                                StoryCardView(
                                    news: item,
                                    index: idx + 1,
                                    isSaved: true,
                                    isLocked: !appState.canFullyRead(item),
                                    onTap: { selectedNews = item },
                                    onBookmark: { appState.toggleSave(news: item) }
                                )
                                .padding(.horizontal, 22)
                            }
                        }
                    }

                    Spacer().frame(height: 110)
                }
            }
        }
        .task { await loadSaved() }
        .onChange(of: appState.savedNewsIds) { _, _ in
            Task { await loadSaved() }
        }
        .sheet(item: $selectedNews) { item in
            NewsDetailView(news: item, allNews: savedNews)
                .environmentObject(appState)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(Color.bgSecondary)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "bookmark")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.textDisabled)
                )

            Text("Henüz kayıt yok.")
                .font(.displayXS)
                .foregroundStyle(Color.textPrimary)

            Text("Bir haberi sonra okumak için yer imi ikonuna dokun.")
                .font(.bodyMD)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func loadSaved() async {
        isLoading = true
        defer { isLoading = false }

        // Local cache first (immediate display)
        savedNews = appState.loadCachedSavedNews()

        // If authenticated, sync from Supabase (overrides local with server-truth)
        if appState.isAuthenticated, let user = SupabaseManager.shared.client.auth.currentUser {
            do {
                let rows = try await SupabaseManager.shared.fetchSavedNews(userId: user.id)
                let remote = rows.map { $0.toNewsItem() }
                if !remote.isEmpty { savedNews = remote }
            } catch {
                Log.error("Saved sync error (using cache): \(error)")
            }
        }
    }
}

#Preview {
    SavedView()
        .environmentObject(AppState())
}
