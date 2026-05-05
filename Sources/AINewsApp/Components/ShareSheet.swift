import SwiftUI
import UIKit
import LinkPresentation

// MARK: - SwiftUI bridge for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let news: NewsItem
    let shareImage: UIImage?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let source = NewsActivityItemSource(news: news, image: shareImage)
        var items: [Any] = [source]
        if let img = shareImage {
            items.append(img)
        }
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Per-platform formatting
final class NewsActivityItemSource: NSObject, UIActivityItemSource {
    let news: NewsItem
    let image: UIImage?
    private let appURL = "https://marker.app"

    init(news: NewsItem, image: UIImage?) {
        self.news = news
        self.image = image
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        news.title
    }

    func activityViewController(_ controller: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        guard let type = activityType else { return formatDefault() }

        switch type {
        case .postToTwitter:
            // Twitter: short headline + url, fits 280 chars
            let title = news.title.count > 200 ? String(news.title.prefix(200)) + "…" : news.title
            return "📰 \(title)\n\n\(appURL) #marker #YapayZeka"

        case .mail:
            // Email: title in subject (handled separately), body = summary + body excerpt
            let preview = news.summary.isEmpty ? String(news.body.prefix(300)) : news.summary
            return """
            \(news.title)

            \(preview)

            ─────────
            marker. uygulamasından paylaşıldı
            \(appURL)
            """

        case UIActivity.ActivityType("net.whatsapp.WhatsApp.ShareExtension"),
             UIActivity.ActivityType("net.whatsapp.WhatsApp.ShareExtension-Inplace"):
            // WhatsApp: emoji + title + summary + url
            return "📰 *\(news.title)*\n\n\(news.summary)\n\n🔗 \(appURL)"

        case UIActivity.ActivityType("com.burbn.instagram.shareextension"),
             UIActivity.ActivityType("com.instagram.shareExtension"):
            // Instagram only takes the image; image is already provided
            return image ?? formatDefault()

        case .copyToPasteboard:
            return "\(news.title)\n\n\(news.summary)\n\n\(appURL)"

        case .message:
            return "\(news.title)\n\n\(appURL)"

        default:
            return formatDefault()
        }
    }

    func activityViewController(_ controller: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        // Used for email subject
        return news.title
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = news.title
        metadata.originalURL = URL(string: appURL)
        if let img = image {
            metadata.imageProvider = NSItemProvider(object: img)
        }
        return metadata
    }

    private func formatDefault() -> String {
        "\(news.title)\n\n\(news.summary)\n\n\(appURL)"
    }
}

// MARK: - Share image generator (Instagram Story / link preview)
@MainActor
struct ShareImageGenerator {
    static func generate(news: NewsItem) -> UIImage? {
        let card = ShareCardView(news: news)
            .frame(width: 1080, height: 1920)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        return renderer.uiImage
    }
}

// MARK: - Story-formatted share card (1080×1920)
private struct ShareCardView: View {
    let news: NewsItem
    private var tone: CardTone { CardTone.forTopicId(news.topicId) }

    var body: some View {
        ZStack {
            tone.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Brand
                HStack(spacing: 16) {
                    BriefLogo(size: 56)
                    Text("marker.")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text("BUGÜN")
                        .font(.system(size: 24, weight: .medium).monospaced())
                        .foregroundStyle(tone.sub)
                        .tracking(2)
                }
                .padding(.top, 100)

                Spacer().frame(height: 80)

                // Topic chip
                Text((news.topic?.name ?? news.topicId).uppercased())
                    .font(.system(size: 28, weight: .semibold).monospaced())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer().frame(height: 60)

                // Headline (Instrument Serif if available)
                Text(news.title + ".")
                    .font(Font.custom("InstrumentSerif-Regular", size: 100))
                    .foregroundStyle(Color.textPrimary)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Footer
                VStack(alignment: .leading, spacing: 16) {
                    Rectangle()
                        .fill(tone.sub.opacity(0.3))
                        .frame(height: 2)
                    HStack {
                        Text("marker.app")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(tone.sub)
                        Spacer()
                        Text(news.readTime.uppercased())
                            .font(.system(size: 28, weight: .medium).monospaced())
                            .foregroundStyle(tone.sub)
                    }
                }
                .padding(.bottom, 100)
            }
            .padding(.horizontal, 90)
        }
        .frame(width: 1080, height: 1920)
    }
}
