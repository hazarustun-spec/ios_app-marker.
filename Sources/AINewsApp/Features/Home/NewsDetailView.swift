import SwiftUI

struct NewsDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let news: NewsItem
    let allNews: [NewsItem]

    @State private var showPaywall = false
    @State private var showShare = false
    @State private var shareImage: UIImage? = nil
    @State private var scrollProgress: CGFloat = 0

    private var nextNews: NewsItem? {
        guard let idx = allNews.firstIndex(where: { $0.id == news.id }),
              idx + 1 < allNews.count else { return nil }
        return allNews[idx + 1]
    }

    private var canFullyRead: Bool { appState.canFullyRead(news) }

    private var bodySentences: [String] {
        var result: [String] = []
        var current = ""
        for char in news.body {
            current.append(char)
            if char == "." || char == "!" || char == "?" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { result.append(trimmed) }
                current = ""
            }
        }
        let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { result.append(last) }
        return result
    }

    private var bodyParagraphs: [String] {
        let parts = news.body
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if parts.count > 1 { return parts }
        // Fallback: split into 2-sentence chunks
        let s = bodySentences
        return stride(from: 0, to: s.count, by: 2).map { i in
            s[i..<min(i+2, s.count)].joined(separator: " ")
        }
    }

    private var visibleParagraphs: [String] {
        if canFullyRead { return bodyParagraphs }
        let s = bodySentences
        return [s.prefix(4).joined(separator: " ")]
    }

    private var tone: CardTone { CardTone.forTopicId(news.topicId) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(hex: "#FBFBF6").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        aiDisclosureBanner
                        heroMeta
                        headlineSection
                        dekSection
                        bylineRow
                        primarySourceCTA
                        heroOrb
                        tldrCard
                        bodySection
                        if !canFullyRead {
                            paywallBlock.padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 20)
                        }
                        if canFullyRead {
                            sectionHeading(label: "§ 02", title: "Neden", italic: "önemli", suffix: ".")
                            whyItMattersSection
                            statRow
                            editorNote
                            keyTermsSection
                            sourcesSection
                            reactionBar
                        }
                        if let next = nextNews {
                            upNextCard(next)
                        }
                        Spacer().frame(height: 40)
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetKey.self,
                                value: -proxy.frame(in: .named("scroll")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    let totalScrollable: CGFloat = 2000
                    scrollProgress = max(0, min(1, offset / totalScrollable))
                }

                stickyHeader
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPaywall) {
                PaywallView().environmentObject(appState)
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(news: news, shareImage: shareImage)
                    .presentationDetents([.medium, .large])
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Sticky header
    private var stickyHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Geri")

                Spacer()

                Text((news.topic?.name ?? news.topicId).uppercased() + " · DERİN İNCELEME")
                    .font(.system(size: 10, weight: .medium).monospaced())
                    .foregroundStyle(Color(hex: "#666666"))
                    .tracking(1.2)
                    .accessibilityHidden(true) // category shown in combined label

                Spacer()

                Button {
                    appState.toggleSave(news: news)
                } label: {
                    Image(systemName: appState.isSaved(news) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(appState.isSaved(news) ? "Kayıttan çıkar" : "Kaydedilenlere ekle")

                Button {
                    shareImage = ShareImageGenerator.generate(news: news)
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Paylaş")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            // Progress bar
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.black.opacity(0.05)).frame(height: 2)
                Rectangle().fill(Color.textPrimary).frame(width: max(0, scrollProgress * UIScreen.main.bounds.width), height: 2)
            }
        }
        .background(Color(hex: "#FBFBF6").opacity(0.92))
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Hero meta
    private var heroMeta: some View {
        HStack(spacing: 8) {
            Text("ÖNE ÇIKAN")
                .font(.system(size: 10, weight: .semibold).monospaced())
                .foregroundStyle(Color.white)
                .tracking(1.2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(news.readTime.uppercased())
                .font(.system(size: 10, weight: .medium).monospaced())
                .foregroundStyle(Color(hex: "#666666"))
                .tracking(1.2)

            Text("·")
                .foregroundStyle(Color(hex: "#666666"))

            Text(news.formattedDate.uppercased())
                .font(.system(size: 10, weight: .medium).monospaced())
                .foregroundStyle(Color(hex: "#666666"))
                .tracking(1.2)

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    // MARK: - AI disclosure banner (just below sticky header)
    private var aiDisclosureBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(Color.textPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("YAPAY ZEKÂ ÜRETİMİ")
                    .font(.system(size: 10, weight: .semibold).monospaced())
                    .foregroundStyle(Color.textPrimary)
                    .tracking(1)

                Text("Bu içerik marker. tarafından çoklu kaynaktan otomatik olarak derlendi.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#555555"))
                    .lineSpacing(1)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.brandPrimary.opacity(0.4))
        .padding(.top, 60) // sticky header altı için boşluk
    }

    // MARK: - Headline (mixed weights with mint highlight)
    private var headlineSection: some View {
        // Split title: first 6 words regular, next 2 italic-mint, rest regular
        let words = news.title.split(separator: " ").map(String.init)
        let breakA = min(6, words.count)
        let breakB = min(breakA + 2, words.count)
        let firstChunk = words[..<breakA].joined(separator: " ")
        let accentChunk = words[breakA..<breakB].joined(separator: " ")
        let restChunk = words[breakB...].joined(separator: " ")

        return VStack(alignment: .leading, spacing: 0) {
            (
                Text(firstChunk + " ")
                    .font(Font.custom("InstrumentSerif-Regular", size: 38))
                    .foregroundColor(Color.textPrimary)
                + Text(accentChunk)
                    .font(Font.custom("InstrumentSerif-Italic", size: 38))
                    .foregroundColor(Color.textPrimary)
                + Text(restChunk.isEmpty ? "." : " " + restChunk + ".")
                    .font(Font.custom("InstrumentSerif-Regular", size: 38))
                    .foregroundColor(Color.textPrimary)
            )
            .lineSpacing(2)

            // Mint highlight underline behind italic word (visual treat)
            if !accentChunk.isEmpty {
                Rectangle()
                    .fill(Color.brandPrimary)
                    .frame(height: 6)
                    .frame(maxWidth: 80, alignment: .leading)
                    .padding(.top, -16)
                    .padding(.leading, CGFloat(firstChunk.count) * 4 + 4)
                    .opacity(0.6)
            }
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Dek
    private var dekSection: some View {
        Text(news.summary)
            .font(Font.custom("InstrumentSerif-Italic", size: 18))
            .foregroundStyle(Color(hex: "#444444"))
            .lineSpacing(3)
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 22)
    }

    // MARK: - Byline
    private var bylineRow: some View {
        HStack(spacing: 12) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#C8DC92"), Color(hex: "#9ec8ff")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                Text("AI")
                    .font(.system(size: 13, weight: .semibold).monospaced())
                    .foregroundStyle(Color.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("marker. tarafından derlendi")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("\(news.sourceUrls.count) KAYNAK · WEB ARAMASI")
                    .font(.system(size: 10, weight: .medium).monospaced())
                    .foregroundStyle(Color(hex: "#888888"))
                    .tracking(0.5)
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: "#3a4f1a"))
                Text("AI ÜRETİMİ")
                    .font(.system(size: 10, weight: .medium).monospaced())
                    .foregroundStyle(Color(hex: "#3a4f1a"))
                    .tracking(0.5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: "#F0F2E6"))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .top)
        .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Primary source CTA (opens first URL)
    @ViewBuilder
    private var primarySourceCTA: some View {
        if let first = news.sourceUrls.first, let url = URL(string: first) {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Birincil kaynağa git")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Hero orb
    private var heroOrb: some View {
        ZStack(alignment: .bottom) {
            GlassOrbView()
                .frame(height: 220)
                .background(Color(hex: "#F2F4EC"))

            HStack {
                Text("FIG 01 · GÖRSEL")
                    .font(.system(size: 9, weight: .medium).monospaced())
                    .foregroundStyle(Color.black.opacity(0.5))
                    .tracking(1)
                Spacer()
                Text("BRIEF AI · 2026")
                    .font(.system(size: 9, weight: .medium).monospaced())
                    .foregroundStyle(Color.black.opacity(0.5))
                    .tracking(1)
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 24)
    }

    // MARK: - TL;DR card with framed border
    private var tldrCard: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                Spacer().frame(height: 6)
                ForEach(Array(tldrBullets.enumerated()), id: \.offset) { idx, bullet in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.textPrimary.opacity(0.7))
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Text(bullet)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "#1a1a1a"))
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.textPrimary, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))

            // "TL;DR" tab
            Text("ÖZET")
                .font(.system(size: 10, weight: .semibold).monospaced())
                .foregroundStyle(Color.brandPrimary)
                .tracking(1.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .offset(x: 16, y: -10)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }

    // MARK: - Body with drop cap
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(visibleParagraphs.enumerated()), id: \.offset) { idx, para in
                if idx == 0 {
                    DropCapParagraph(text: para)
                } else if idx == 1 {
                    sectionHeading(label: "§ 01", title: "Detaylar", italic: "", suffix: "")
                    paragraph(para)
                } else {
                    paragraph(para)
                }
            }
        }
        .padding(.horizontal, 22)
    }

    private func paragraph(_ text: String) -> some View {
        EnrichedParagraph(text: text)
    }

    // MARK: - Section heading
    private func sectionHeading(label: String, title: String, italic: String, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 11, weight: .medium).monospaced())
                    .foregroundStyle(Color(hex: "#888888"))
                    .tracking(1.5)
                Rectangle().fill(Color.black.opacity(0.15)).frame(height: 1)
            }

            (
                Text(title + (italic.isEmpty ? "" : " "))
                    .font(Font.custom("InstrumentSerif-Regular", size: 28))
                    .foregroundColor(Color.textPrimary)
                + Text(italic)
                    .font(Font.custom("InstrumentSerif-Italic", size: 28))
                    .foregroundColor(Color.textPrimary)
                + Text(suffix)
                    .font(Font.custom("InstrumentSerif-Regular", size: 28))
                    .foregroundColor(Color.textPrimary)
            )
            .lineSpacing(2)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 14)
    }

    // MARK: - Why it matters
    private var whyItMattersSection: some View {
        EnrichedParagraph(text: bodySentences.suffix(3).joined(separator: " "))
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
    }

    // MARK: - Stat row (3-up)
    private var statRow: some View {
        HStack(spacing: 8) {
            statCard(value: "\(news.readTime.split(separator: " ").first ?? "5")", label: "DAKİKA\nOKUMA", bg: Color.toneMint)
            statCard(value: "10", label: "GÜNLÜK\nKONU", bg: Color.toneSage)
            statCard(value: "40+", label: "KAYNAK\nİZLENİYOR", bg: Color.toneCream)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }

    private func statCard(value: String, label: String, bg: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(Font.custom("InstrumentSerif-Regular", size: 32))
                .foregroundStyle(Color.textPrimary)

            Text(label)
                .font(.system(size: 9, weight: .medium).monospaced())
                .foregroundStyle(Color(hex: "#3a3f2a"))
                .tracking(1)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Editor's note
    private var editorNote: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.textPrimary)
                    .frame(width: 28, height: 28)
                Text("i")
                    .font(Font.custom("InstrumentSerif-Italic", size: 18))
                    .foregroundStyle(Color(hex: "#FFD45A"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("EDİTÖR NOTU")
                    .font(.system(size: 10, weight: .medium).monospaced())
                    .foregroundStyle(Color(hex: "#7a6020"))
                    .tracking(1)

                Text("Bu haber marker. tarafından çoklu kaynaklardan otomatik olarak derlenmiştir. Haberle ilgili gelişmeler oldukça güncellenebilir.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color(hex: "#3a2f0a"))
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .background(Color(hex: "#FFF8E0"))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#E8D88A"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }

    // MARK: - Key terms
    private var keyTermsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ANAHTAR TERİMLER · 3")
                .font(.system(size: 10, weight: .medium).monospaced())
                .foregroundStyle(Color(hex: "#888888"))
                .tracking(1.5)
                .padding(.bottom, 12)

            ForEach(Array(keyTerms.enumerated()), id: \.offset) { idx, term in
                HStack(alignment: .top, spacing: 14) {
                    Text(String(format: "%02d", idx + 1))
                        .font(.system(size: 10, weight: .medium).monospaced())
                        .foregroundStyle(Color(hex: "#888888"))
                        .frame(width: 20, alignment: .leading)
                        .padding(.top, 3)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(term.term)
                            .font(Font.custom("InstrumentSerif-Italic", size: 17))
                            .foregroundStyle(Color.textPrimary)
                        Text(term.def)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#555555"))
                            .lineSpacing(2)
                    }
                }
                .padding(.vertical, 12)
                .overlay(Rectangle().fill(Color.black.opacity(idx == 0 ? 0.1 : 0)).frame(height: 1), alignment: .top)
                .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }

    // MARK: - Sources used (real URLs from news_items.source_urls)
    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if news.sourceUrls.isEmpty {
                EmptyView()
            } else {
                Text("KULLANILAN KAYNAKLAR · \(news.sourceUrls.count)")
                    .font(.system(size: 10, weight: .medium).monospaced())
                    .foregroundStyle(Color(hex: "#888888"))
                    .tracking(1.5)
                    .padding(.bottom, 12)

                VStack(spacing: 8) {
                    ForEach(Array(news.sourceUrls.enumerated()), id: \.offset) { idx, urlStr in
                        SourceLink(index: idx + 1, urlString: urlStr)
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }

    // MARK: - Reaction bar
    private var reactionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bu özet nasıldı?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("Yarınki özeti iyileştirmemize yardımcı olur.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#888888"))
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(["👍", "👎", "✨"], id: \.self) { e in
                    Button {} label: {
                        Text(e)
                            .font(.system(size: 16))
                            .frame(width: 38, height: 38)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Color(hex: "#F2F4EC"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }

    // MARK: - Up next card
    private func upNextCard(_ next: NewsItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("OKUMAYA DEVAM ET")
                .font(.system(size: 10, weight: .medium).monospaced())
                .foregroundStyle(Color(hex: "#888888"))
                .tracking(1.5)
                .padding(.horizontal, 22)

            Button {
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text("SIRADAKİ · \((next.topic?.name ?? next.topicId).uppercased())")
                        .font(.system(size: 10, weight: .medium).monospaced())
                        .foregroundStyle(Color(hex: "#3a4f1a"))
                        .tracking(1)
                        .padding(.bottom, 8)

                    Text(next.title + ".")
                        .font(Font.custom("InstrumentSerif-Regular", size: 22))
                        .foregroundStyle(Color.textPrimary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Text(next.readTime.uppercased())
                            .font(.system(size: 10, weight: .medium).monospaced())
                            .foregroundStyle(Color(hex: "#3a4f1a"))
                        Spacer()
                        ZStack {
                            Circle().fill(Color.textPrimary).frame(width: 36, height: 36)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 14)
                }
                .padding(18)
                .background(Color.brandPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
        }
        .padding(.top, 12)
    }

    // MARK: - Paywall block
    private var paywallBlock: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.textPrimary)

            Text("Bu haber Premium'a özel.")
                .font(Font.custom("InstrumentSerif-Regular", size: 24))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text("Seçtiğin konular dışındaki haberleri tam olarak okumak için Premium'a geç.")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "#555555"))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)

            Button { showPaywall = true } label: {
                Text("Premium'a yükselt")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 4)
        }
        .padding(22)
        .background(Color.toneCream)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Helpers
    private var tldrBullets: [String] {
        let summarySentences = news.summary
            .components(separatedBy: ". ")
            .map { $0.hasSuffix(".") ? $0 : $0 + "." }
            .filter { $0.count > 4 }
        if summarySentences.count >= 3 { return Array(summarySentences.prefix(3)) }
        var bullets = summarySentences
        bullets.append(contentsOf: bodySentences.prefix(3 - bullets.count))
        return Array(bullets.prefix(3))
    }

    private struct KeyTerm { let term: String; let def: String }
    private var keyTerms: [KeyTerm] {
        // Extract noun-phrase-like first 3 capitalized terms from body for "key terms"
        let topic = news.topic?.name ?? news.topicId
        return [
            KeyTerm(term: topic, def: news.summary.prefix(120) + (news.summary.count > 120 ? "…" : "")),
            KeyTerm(term: "Yapay zekâ", def: "marker.'ın günlük olarak izlediği 10 alandan biri."),
            KeyTerm(term: "Otomasyon", def: "marker. özetleri her sabah 06:30'da otomatik olarak hazırlanır."),
        ]
    }
}

// MARK: - Tappable source link (opens in Safari)
private struct SourceLink: View {
    let index: Int
    let urlString: String

    @Environment(\.openURL) private var openURL

    private var domain: String {
        guard let host = URL(string: urlString)?.host else { return urlString }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private var pathHint: String {
        guard let url = URL(string: urlString) else { return "" }
        let path = url.path
        return path.count > 60 ? String(path.prefix(60)) + "…" : path
    }

    var body: some View {
        Button {
            if let url = URL(string: urlString) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 12) {
                Text(String(format: "%02d", index))
                    .font(.system(size: 10, weight: .medium).monospaced())
                    .foregroundStyle(Color(hex: "#888888"))
                    .frame(width: 20, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(domain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    if !pathHint.isEmpty {
                        Text(pathHint)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#888888"))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(hex: "#F0F2E6"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Drop cap paragraph
private struct DropCapParagraph: View {
    let text: String

    var body: some View {
        let firstChar = String(text.prefix(1))
        let rest = String(text.dropFirst())

        HStack(alignment: .top, spacing: 0) {
            Text(firstChar)
                .font(Font.custom("InstrumentSerif-Regular", size: 64))
                .foregroundStyle(Color.textPrimary)
                .padding(.trailing, 8)
                .padding(.top, 4)
                .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }

            EnrichedParagraph(text: rest)
        }
    }
}

// MARK: - Enriched body paragraph (UILabel justified, with bold/italic/highlights)
private struct EnrichedParagraph: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        let baseFont = UIFont(name: "InstrumentSerif-Regular", size: 18) ?? .systemFont(ofSize: 18)
        let italicFont = UIFont(name: "InstrumentSerif-Italic", size: 18) ?? .italicSystemFont(ofSize: 18)
        let boldDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? baseFont.fontDescriptor
        let boldFont = UIFont(descriptor: boldDescriptor, size: 18)

        let style = NSMutableParagraphStyle()
        style.alignment = .justified
        style.lineSpacing = 6
        style.lineBreakMode = .byWordWrapping
        style.hyphenationFactor = 1.0

        let primary = UIColor(Color(hex: "#1a1a1a"))
        let mintBg = UIColor(Color.brandPrimary).withAlphaComponent(0.55)

        let attr = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: primary,
            .paragraphStyle: style,
        ])

        // Italic for quoted text
        applyRegex(pattern: "\"[^\"]+\"", to: attr, attrs: [.font: italicFont])
        applyRegex(pattern: "“[^”]+”", to: attr, attrs: [.font: italicFont])

        // Mint highlight for numbers
        applyRegex(pattern: "\\b\\d+([.,]\\d+)?\\s?(%|milyon|milyar|bin|TL|\\$|€)?\\b", to: attr, attrs: [
            .backgroundColor: mintBg,
        ])

        // Bold for proper nouns (skipping first match)
        applyRegex(pattern: "\\b[A-ZĞÜŞİÖÇ][A-Za-zğüşıöçĞÜŞİÖÇ0-9]+(?:\\s[A-ZĞÜŞİÖÇ][A-Za-zğüşıöçĞÜŞİÖÇ0-9]+){0,2}", to: attr, attrs: [
            .font: boldFont,
        ], skip: 1)

        uiView.attributedText = attr
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }

    private func applyRegex(pattern: String, to attr: NSMutableAttributedString, attrs: [NSAttributedString.Key: Any], skip: Int = 0) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let range = NSRange(location: 0, length: attr.length)
        let matches = regex.matches(in: attr.string, options: [], range: range)
        for (idx, match) in matches.enumerated() {
            if idx < skip { continue }
            attr.addAttributes(attrs, range: match.range)
        }
    }
}

// MARK: - Flow chips
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                Text(item)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(idx == items.count - 1 ? Color.white : Color(hex: "#3a4f1a"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(idx == items.count - 1 ? Color.textPrimary : Color(hex: "#F0F2E6"))
                    .clipShape(Capsule())
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxH: CGFloat = 0
        for subview in subviews {
            let sz = subview.sizeThatFits(.unspecified)
            if x + sz.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, sz.height); x += sz.width + spacing
            maxH = max(maxH, y + rowH)
        }
        return CGSize(width: width, height: maxH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for subview in subviews {
            let sz = subview.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            rowH = max(rowH, sz.height); x += sz.width + spacing
        }
    }
}

// Scroll progress preference
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NewsDetailView(news: .mock, allNews: NewsItem.mockList)
        .environmentObject(AppState())
}
