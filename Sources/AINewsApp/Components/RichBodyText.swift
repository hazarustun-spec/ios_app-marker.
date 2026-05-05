import SwiftUI
import UIKit

// MARK: - Rich body renderer
// Plain Claude body'sini paragraph başlıkları, bold lede, italic alıntı, renkli sayı vurgusu ile zenginleştirir.
// Justified hizalama korunur.
struct RichBodyText: View {
    let bodyText: String

    private struct Paragraph: Identifiable {
        let id = UUID()
        let heading: String?
        let text: String
    }

    private var paragraphs: [Paragraph] {
        let parts = bodyText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let headings = ["Detaylar", "Arka plan", "Çıkarımlar", "Sonraki adımlar", "Sektör tepkisi", "Etki"]
        return parts.enumerated().map { idx, text in
            // First paragraph has no heading (it's the lede). Others get rotating subheads.
            let h = idx == 0 ? nil : headings[(idx - 1) % headings.count]
            return Paragraph(heading: h, text: text)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(Array(paragraphs.enumerated()), id: \.element.id) { idx, paragraph in
                if let heading = paragraph.heading {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.brandPrimary)
                            .frame(width: 4, height: 22)
                        Text(heading.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .tracking(1.5)
                    }
                    .padding(.top, 4)
                }

                JustifiedAttributedText(
                    text: paragraph.text,
                    isLede: idx == 0
                )
            }
        }
    }
}

// MARK: - Justified body renderer with inline emphasis
struct JustifiedAttributedText: UIViewRepresentable {
    let text: String
    let isLede: Bool

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.attributedText = buildAttributed()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }

    private func buildAttributed() -> NSAttributedString {
        let baseFont = UIFont(name: "InstrumentSerif-Regular", size: 19) ?? .systemFont(ofSize: 19)
        let italicFont = UIFont(name: "InstrumentSerif-Italic", size: 19) ?? .italicSystemFont(ofSize: 19)
        let boldDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? baseFont.fontDescriptor
        let boldFont = UIFont(descriptor: boldDescriptor, size: 19)

        let style = NSMutableParagraphStyle()
        style.alignment = .justified
        style.lineSpacing = 6
        style.lineBreakMode = .byWordWrapping
        style.hyphenationFactor = 1.0

        let primaryColor = UIColor(Color(hex: "#1a1a1a"))
        let accentColor  = UIColor(Color(hex: "#3a4f1a"))   // dark mint accent
        let highlightBg  = UIColor(Color(hex: "#C8DC92")).withAlphaComponent(0.5)

        let attr = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: primaryColor,
            .paragraphStyle: style,
        ])

        let ns = text as NSString

        // 1. Lede emphasis: first sentence of first paragraph in semibold larger
        if isLede {
            let firstSentenceEnd = ns.range(of: ".")
            if firstSentenceEnd.location != NSNotFound {
                let ledeRange = NSRange(location: 0, length: firstSentenceEnd.location + 1)
                attr.addAttributes([.font: boldFont], range: ledeRange)
            }
        }

        // 2. Quoted text → italic
        applyRegex(pattern: "\"[^\"]+\"", to: attr, attrs: [.font: italicFont])
        applyRegex(pattern: "“[^”]+”", to: attr, attrs: [.font: italicFont])

        // 3. Numbers / percentages / prices → mint highlight
        applyRegex(pattern: "\\b\\d+([.,]\\d+)?\\s?(%|milyon|milyar|bin|TL|\\$|€)?\\b", to: attr, attrs: [
            .backgroundColor: highlightBg,
            .foregroundColor: UIColor(Color.textPrimary),
        ])

        // 4. Capitalized multi-word proper nouns (e.g. "OpenAI", "Google DeepMind") → semibold
        applyRegex(pattern: "\\b[A-ZĞÜŞİÖÇ][A-Za-zğüşıöçĞÜŞİÖÇ0-9]+(?:\\s[A-ZĞÜŞİÖÇ][A-Za-zğüşıöçĞÜŞİÖÇ0-9]+){0,2}", to: attr, attrs: [
            .font: boldFont,
            .foregroundColor: accentColor,
        ], skip: 3)  // skip first match to avoid bolding sentence-starting words

        return attr
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
