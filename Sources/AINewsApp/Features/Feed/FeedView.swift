import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var appState: AppState
    @State private var news: [NewsItem] = []
    @State private var isLoading = true
    @State private var selectedFilter: String = "Tümü"
    @State private var selectedNews: NewsItem? = nil

    private let filters = ["Tümü", "Konularım", "Premium"]

    private var filtered: [NewsItem] {
        switch selectedFilter {
        case "Tümü":       return news
        case "Konularım":  return news.filter { appState.profile.selectedTopicIds.contains($0.topicId) }
        case "Premium":    return news.filter { !appState.canFullyRead($0) }
        default:           return news
        }
    }

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
                        Text("Akış.")
                            .font(.displayLG)
                            .foregroundStyle(Color.textPrimary)

                        Text("Son 7 gün · 06:30'da otomatik güncellenir")
                            .font(.bodyMD)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)

                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { filter in
                                let isActive = selectedFilter == filter
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    Text(filter)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(isActive ? Color.white : Color.textPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(isActive ? Color.textPrimary : Color(hex: "#F2F2EC"))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 22)
                    }
                    .padding(.bottom, 20)

                    // Premium hint banner (free users)
                    if !appState.profile.isPremium {
                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textPrimary)
                            Text("Konularım dışındaki haberler kısıtlıdır.")
                                .font(.bodySM)
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.toneCream)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 22)
                        .padding(.bottom, 14)
                    }

                    // Feed rows
                    if isLoading {
                        ForEach(0..<5, id: \.self) { _ in
                            FeedRowSkeleton()
                                .padding(.horizontal, 22)
                        }
                    } else if filtered.isEmpty {
                        Text("Bu kategoride bu hafta haber yok.")
                            .font(.bodyMD)
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, item in
                                FeedRowView(
                                    news: item,
                                    index: idx + 1,
                                    isSaved: appState.isSaved(item),
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
        .task { await loadNews() }
        .sheet(item: $selectedNews) { item in
            NewsDetailView(news: item, allNews: news)
                .environmentObject(appState)
        }
    }

    private func loadNews() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Today only. Yesterday's stories are hidden from the app (only saved
            // ones survive in the Saved tab).
            let rows = try await SupabaseManager.shared.fetchTodayNews(topicIds: [])
            news = rows.map { $0.toNewsItem() }
        } catch {
            Log.error("Feed load error: \(error)")
        }
    }
}

struct FeedRowView: View {
    let news: NewsItem
    let index: Int
    let isSaved: Bool
    var isLocked: Bool = false
    let onTap: () -> Void
    let onBookmark: () -> Void

    private var tone: CardTone { CardTone.forTopicId(news.topicId) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tone.background)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                                .foregroundStyle(tone.text)
                        )

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white)
                            .frame(width: 18, height: 18)
                            .background(Color.textPrimary)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%02d · %@ · %@", index, (news.topic?.name ?? news.topicId).uppercased(), news.formattedDate.uppercased()))
                        .font(.labelSM)
                        .foregroundStyle(Color.textTertiary)

                    Text(news.title + ".")
                        .font(Font.custom("InstrumentSerif-Regular", size: 17))
                        .foregroundStyle(isLocked ? Color.textPrimary.opacity(0.7) : Color.textPrimary)
                        .lineSpacing(1)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onBookmark) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#999999"))
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 18)
            .overlay(
                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(height: 1),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FeedRowSkeleton: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgSecondary)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(Color.bgSecondary).frame(height: 10).frame(maxWidth: 120)
                RoundedRectangle(cornerRadius: 4).fill(Color.bgSecondary).frame(height: 16)
                RoundedRectangle(cornerRadius: 4).fill(Color.bgSecondary).frame(height: 16).frame(maxWidth: .infinity).padding(.trailing, 40)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 18)
        .redacted(reason: .placeholder)
    }
}

#Preview {
    FeedView()
        .environmentObject(AppState())
}
