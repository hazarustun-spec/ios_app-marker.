import SwiftUI

struct NewsCard: View {
    let news: NewsItem
    var isSaved: Bool = false
    var onSave: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    if let topic = news.topic {
                        TopicBadge(topic: topic)
                    }
                    Spacer()
                    Text(news.formattedDate)
                        .font(.labelSM)
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)

                // Title
                Text(news.title)
                    .font(.headingMD)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(3)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)

                // Summary
                Text(news.summary)
                    .font(.bodySM)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(3)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)

                // Footer
                HStack {
                    Label(news.readTime, systemImage: "clock")
                        .font(.labelSM)
                        .foregroundStyle(Color.textTertiary)

                    Spacer()

                    if let onSave {
                        Button(action: onSave) {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 16))
                                .foregroundStyle(isSaved ? Color.brandPrimary : Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact variant for Saved tab
struct NewsCardCompact: View {
    let news: NewsItem
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                if let topic = news.topic {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(topic.color)
                        .frame(width: 3)
                        .padding(.vertical, 2)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if let topic = news.topic {
                        HStack(spacing: 4) {
                            Text(topic.emoji).font(.system(size: 12))
                            Text(topic.name)
                                .font(.labelSM)
                                .foregroundStyle(topic.color)
                        }
                    }

                    Text(news.title)
                        .font(.headingSM)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)

                    Text(news.summary)
                        .font(.bodySM)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)

                    Text(news.formattedDate)
                        .font(.labelSM)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(Spacing.lg)
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            NewsCard(news: .mock, isSaved: false, onSave: {}, onTap: {})
            NewsCard(news: .mock, isSaved: true, onSave: {}, onTap: {})
            NewsCardCompact(news: .mock, onTap: {})
        }
        .padding()
    }
    .background(Color.bgPrimary)
}
