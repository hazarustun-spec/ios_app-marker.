import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "Refresh"

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.08))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.brandPrimary.opacity(0.7))
            }

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.headingLG)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.bodyMD)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxxl)
            }

            if let action {
                PrimaryButton(title: actionTitle, style: .outlined, action: action)
                    .frame(width: 160)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xxxl)
    }
}

// MARK: - Loading shimmer placeholder
struct NewsCardSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(shimmerColor)
                    .frame(width: 80, height: 20)
                Spacer()
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(shimmerColor)
                    .frame(width: 60, height: 14)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)

            RoundedRectangle(cornerRadius: Radius.xs)
                .fill(shimmerColor)
                .frame(height: 20)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

            RoundedRectangle(cornerRadius: Radius.xs)
                .fill(shimmerColor)
                .frame(height: 20)
                .padding(.horizontal, Spacing.lg + 40)
                .padding(.top, Spacing.xs)

            RoundedRectangle(cornerRadius: Radius.xs)
                .fill(shimmerColor)
                .frame(height: 14)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

            RoundedRectangle(cornerRadius: Radius.xs)
                .fill(shimmerColor)
                .frame(height: 14)
                .padding(.horizontal, Spacing.lg + 20)
                .padding(.top, Spacing.xs)

            Spacer().frame(height: Spacing.xl)
        }
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
        .onAppear { isAnimating = true }
    }

    private var shimmerColor: Color {
        isAnimating
            ? Color.bgSecondary
            : Color.borderSubtle
    }
}

#Preview {
    VStack(spacing: 16) {
        EmptyStateView(
            icon: "newspaper",
            title: "Bugünün haberleri henüz hazırlanıyor...",
            subtitle: "AI haberler her gün 06:00'da hazır olur.",
            action: {},
            actionTitle: "Yenile"
        )

        NewsCardSkeleton()
            .padding(.horizontal)
    }
    .background(Color.bgPrimary)
}
