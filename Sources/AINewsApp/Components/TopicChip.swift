import SwiftUI

struct TopicChip: View {
    let topic: Topic
    var isSelected: Bool = false
    var isDisabled: Bool = false
    var showCheckmark: Bool = true
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                Text(topic.emoji)
                    .font(.system(size: 16))

                Text(topic.name)
                    .font(.labelLG)
                    .foregroundStyle(labelColor)

                if showCheckmark && isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(topic.color)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 2)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Radius.full))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.full)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
    }

    private var background: Color {
        isSelected ? topic.color.opacity(0.15) : Color.bgCard
    }

    private var borderColor: Color {
        isSelected ? topic.color.opacity(0.5) : Color.borderDefault
    }

    private var labelColor: Color {
        isSelected ? topic.color : Color.textSecondary
    }
}

// MARK: - Small inline chip (for cards)
struct TopicBadge: View {
    let topic: Topic

    var body: some View {
        HStack(spacing: 4) {
            Text(topic.emoji)
                .font(.system(size: 11))
            Text(topic.name)
                .font(.labelSM)
                .foregroundStyle(topic.color)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(topic.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Topic.all) { topic in
                    TopicChip(topic: topic, isSelected: [0, 2].contains(Topic.all.firstIndex(of: topic) ?? -1)) {}
                }
            }
            .padding(.horizontal)
        }

        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Topic.all.prefix(5)) { topic in
                    TopicBadge(topic: topic)
                }
            }
            .padding(.horizontal)
        }
    }
    .padding(.vertical)
    .background(Color.bgPrimary)
}
