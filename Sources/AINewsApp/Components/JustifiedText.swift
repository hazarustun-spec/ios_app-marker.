import SwiftUI
import UIKit

// Two-edge justified body text. SwiftUI'nin Text'i justified hizalama desteklemediği için UILabel sarmalı.
struct JustifiedText: UIViewRepresentable {
    let text: String
    var font: UIFont
    var textColor: UIColor = UIColor(Color.textPrimary)
    var lineSpacing: CGFloat = 5

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        let style = NSMutableParagraphStyle()
        style.alignment = .justified
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping
        style.hyphenationFactor = 1.0

        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: style,
        ])
        uiView.attributedText = attr
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }
}
