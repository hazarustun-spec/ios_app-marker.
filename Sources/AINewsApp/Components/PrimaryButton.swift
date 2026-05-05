import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var style: Style = .filled
    var isLoading: Bool = false
    let action: () -> Void

    enum Style {
        case filled, outlined, ghost
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(style == .filled ? .textPrimary : .brandPrimary)
                        .scaleEffect(0.8)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.headingMD)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(background)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(borderColor, lineWidth: style == .outlined ? 1.5 : 0)
            )
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .filled:
            Color.textPrimary  // solid black, matches design
        case .outlined, .ghost:
            Color.clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .filled:   return .white
        case .outlined: return .textPrimary
        case .ghost:    return .textSecondary
        }
    }

    private var borderColor: Color {
        switch style {
        case .outlined: return .textPrimary.opacity(0.3)
        default: return .clear
        }
    }
}

// MARK: - Apple Sign In Button
struct AppleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .medium))
                Text("Sign in with Apple")
                    .font(.headingMD)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.textPrimary)
            .foregroundStyle(Color.bgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Get Started", icon: "arrow.right") {}
        PrimaryButton(title: "Loading", isLoading: true) {}
        PrimaryButton(title: "Outlined", style: .outlined) {}
        PrimaryButton(title: "Ghost", style: .ghost) {}
        AppleSignInButton {}
    }
    .padding()
    .background(Color.bgPrimary)
}
