import SwiftUI

// MARK: - Today screen
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var news: [NewsItem] = []
    @State private var isLoading = true
    @State private var selectedNews: NewsItem? = nil

    private var topStory: NewsItem? { news.first }
    private var restStories: [NewsItem] { news.dropFirst().map { $0 } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        topBar
                        if isLoading {
                            loadingState
                        } else if news.isEmpty {
                            emptyState
                        } else {
                            heroSection
                            alsoTodaySection
                            Spacer().frame(height: 110)
                        }
                    }
                }
            }
        }
        .task { await loadNews() }
        .sheet(item: $selectedNews) { item in
            NewsDetailView(news: item, allNews: news)
                .environmentObject(appState)
        }
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack {
            BriefLogo()
            Spacer()
            HStack(spacing: 6) {
                Text(headerDateLabel)
                    .font(.labelSM)
                    .foregroundStyle(Color.textTertiary)

                if !isLoading && !news.isEmpty {
                    Circle().fill(Color.success).frame(width: 5, height: 5)
                    Text("TAZE")
                        .font(.labelSM)
                        .foregroundStyle(Color.success)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    // Header date — always today (we never fall back to older content)
    private var headerDateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEE · dd MMM"
        return f.string(from: Date()).uppercased()
    }

    // News are guaranteed delivered by 06:30 IST. Before that → "preparing".
    // Computed in user's local time but referenced to IST cutoff.
    private var isBeforeDailyCutoff: Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let now = Date()
        let cutoff = cal.date(bySettingHour: 6, minute: 30, second: 0, of: now) ?? now
        return now < cutoff
    }

    // MARK: - Hero section
    @ViewBuilder
    private var heroSection: some View {
        if let top = topStory {
            VStack(alignment: .leading, spacing: 0) {
                // Big serif headline (color split: first 3 words bold, middle italic gray, rest normal)
                Button { selectedNews = top } label: {
                    heroHeadlineView(top.title)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)

                // Glass orb
                GlassOrbView()
                    .frame(height: 220)
                    .background(Color(hex: "#F2F4EC"))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                    .padding(.horizontal, 22)

                // Hero meta
                HStack(spacing: 10) {
                    Text((top.topic?.name ?? top.topicId).uppercased())
                        .font(.labelSM)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(top.readTime)
                        .font(.labelSM)
                        .foregroundStyle(Color.textTertiary)

                    Text("·")
                        .font(.labelSM)
                        .foregroundStyle(Color.textTertiary)

                    Text(top.topic?.name ?? top.topicId)
                        .font(.labelSM)
                        .foregroundStyle(Color.textTertiary)

                    Spacer()

                    Button {
                        appState.toggleSave(news: top)
                    } label: {
                        Image(systemName: appState.isSaved(top) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
            }
            .padding(.bottom, 8)
        }
    }

    // Hero serif headline with italic styling on middle words (matches design)
    private func heroHeadlineView(_ title: String) -> some View {
        let words = title.split(separator: " ").map(String.init)
        var first = AttributedString()
        var middle = AttributedString()
        var last = AttributedString()
        let firstCount = min(3, words.count)
        let middleEnd = min(8, words.count)

        for i in 0..<firstCount {
            var w = AttributedString(words[i] + " ")
            w.font = Font.custom("InstrumentSerif-Regular", size: 36)
            w.foregroundColor = .textPrimary
            first.append(w)
        }
        if firstCount < middleEnd {
            for i in firstCount..<middleEnd {
                var w = AttributedString(words[i] + " ")
                w.font = Font.custom("InstrumentSerif-Italic", size: 36)
                w.foregroundColor = .textTertiary
                middle.append(w)
            }
        }
        if middleEnd < words.count {
            for i in middleEnd..<words.count {
                var w = AttributedString(words[i] + (i < words.count - 1 ? " " : "."))
                w.font = Font.custom("InstrumentSerif-Regular", size: 36)
                w.foregroundColor = .textPrimary
                last.append(w)
            }
        } else {
            // Add period if it ends in middle
            var period = AttributedString(".")
            period.font = Font.custom("InstrumentSerif-Italic", size: 36)
            period.foregroundColor = .textTertiary
            middle.append(period)
        }

        var combined = AttributedString()
        combined.append(first)
        combined.append(middle)
        combined.append(last)
        return Text(combined).lineSpacing(2)
    }

    // MARK: - Also today section
    private var alsoTodaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AYRICA BUGÜN")
                    .font(.headingSM)
                    .foregroundStyle(Color.textPrimary)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)

            ForEach(Array(restStories.enumerated()), id: \.element.id) { idx, story in
                StoryCardView(
                    news: story,
                    index: idx + 2,
                    isSaved: appState.isSaved(story),
                    isLocked: !appState.canFullyRead(story),
                    onTap: { selectedNews = story },
                    onBookmark: { appState.toggleSave(news: story) }
                )
                .padding(.horizontal, 22)
            }
        }
    }

    // MARK: - Loading / empty
    private var loadingState: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.bgSecondary)
                    .frame(height: 140)
                    .padding(.horizontal, 22)
                    .redacted(reason: .placeholder)
            }
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private var emptyState: some View {
        if isBeforeDailyCutoff {
            preparingState
        } else {
            generalEmptyState
        }
    }

    // Before 06:30 IST: news being generated/delivered
    private var preparingState: some View {
        VStack(spacing: 18) {
            // Subtle animated indicator
            ZStack {
                Circle()
                    .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 4)
                    .frame(width: 64, height: 64)
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.bottom, 4)

            Text("Yeni özet hazırlanıyor.")
                .font(.displayXS)
                .foregroundStyle(Color.textPrimary)

            Text("Günün haberleri saat 06:30'da telefonuna düşecek.")
                .font(.bodySM)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 40)
        }
        .padding(.top, 100)
    }

    // After 06:30 IST but no news yet — should be very rare
    private var generalEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(Color.textTertiary)
                .padding(.bottom, 4)

            Text("Henüz haber yok.")
                .font(.displayXS)
                .foregroundStyle(Color.textPrimary)
            Text("Bağlantını kontrol et veya birazdan tekrar dene.")
                .font(.bodySM)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 100)
    }

    // MARK: - Helpers
    private func loadNews() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Free users see only their selected topics. Premium see all.
            let topicIds = appState.profile.isPremium ? [] : appState.profile.selectedTopicIds

            // ONLY today's news. No fallback to yesterday — yesterday's stories are
            // hidden from the app (still accessible in Saved if user bookmarked them).
            let rows = try await SupabaseManager.shared.fetchTodayNews(topicIds: topicIds)
            news = rows.map { $0.toNewsItem() }
        } catch {
            Log.error("News load error: \(error)")
        }
    }
}

// MARK: - Glass orb
struct GlassOrbView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color(hex: "#f4f6f0").opacity(0.7),
                                Color(hex: "#d8e3c0").opacity(0.55),
                                Color(hex: "#c8dc92").opacity(0.35),
                            ],
                            center: UnitPoint(x: 0.42, y: 0.38),
                            startRadius: 0,
                            endRadius: max(w, h) * 0.55
                        )
                    )
                    .frame(width: w * 0.78, height: h * 0.75)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#ff9ec7").opacity(0.4),
                                Color(hex: "#ffd29e").opacity(0.25),
                                Color(hex: "#9ec8ff").opacity(0.15),
                                Color.white.opacity(0),
                            ],
                            center: UnitPoint(x: 0.65, y: 0.70),
                            startRadius: 0,
                            endRadius: max(w, h) * 0.4
                        )
                    )
                    .frame(width: w * 0.78, height: h * 0.75)

                Ellipse()
                    .strokeBorder(
                        RadialGradient(
                            colors: [Color.clear, Color(hex: "#a8c878").opacity(0.35), Color.clear],
                            center: .center, startRadius: w * 0.3, endRadius: w * 0.5
                        ),
                        lineWidth: 2
                    )
                    .frame(width: w * 0.78, height: h * 0.75)

                Ellipse()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 70, height: 36)
                    .rotationEffect(.degrees(-25))
                    .offset(x: -w * 0.12, y: -h * 0.16)

                Ellipse()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 26, height: 10)
                    .rotationEffect(.degrees(-25))
                    .offset(x: -w * 0.06, y: -h * 0.1)
            }
            .frame(width: w, height: h)
        }
    }
}

// MARK: - Story card
struct StoryCardView: View {
    let news: NewsItem
    let index: Int
    let isSaved: Bool
    var isLocked: Bool = false
    let onTap: () -> Void
    let onBookmark: () -> Void

    private var tone: CardTone { CardTone.forTopicId(news.topicId) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: topicIcon(news.topicId))
                                .font(.system(size: 16))
                                .foregroundStyle(Color.textPrimary)
                        )

                    Text(String(format: "%02d · %@", index, (news.topic?.name ?? news.topicId).uppercased()))
                        .font(.labelSM)
                        .foregroundStyle(tone.sub)
                        .padding(.top, 4)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(tone.sub)
                            .padding(.top, 4)
                    }

                    Spacer()

                    Button(action: onBookmark) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 14))
                            .foregroundStyle(tone.text)
                    }
                    .padding(.top, 2)
                }
                .padding(.bottom, 14)

                // Headline (Instrument Serif)
                Text(news.title + ".")
                    .font(Font.custom("InstrumentSerif-Regular", size: 22))
                    .foregroundStyle(tone.text)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)

                // Summary
                Text(news.summary)
                    .font(.bodySM)
                    .foregroundStyle(tone.sub)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Footer meta
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(tone.sub)
                    Text(news.readTime)
                        .font(.labelSM)
                        .foregroundStyle(tone.sub)
                    Text("·")
                        .font(.labelSM)
                        .foregroundStyle(tone.sub)
                    Text((news.topic?.name ?? news.topicId).uppercased())
                        .font(.labelSM)
                        .foregroundStyle(tone.sub)
                    Spacer()
                    Text(news.formattedDate.uppercased())
                        .font(.labelSM)
                        .foregroundStyle(tone.sub)
                }
                .padding(.top, 14)
            }
            .padding(20)
            .background(tone.background)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        }
        .buttonStyle(.plain)
    }

    private func topicIcon(_ id: String) -> String {
        switch id {
        case "llms", "research":   return "sparkles"
        case "robotics":           return "gear"
        case "safety", "policy":   return "doc.text"
        case "vision":             return "eye"
        case "tools":              return "wrench.and.screwdriver"
        case "business":           return "arrow.up.right"
        case "generative":         return "wand.and.stars"
        case "healthcare":         return "heart"
        default:                   return "sparkles"
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
