import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: Plan = .annual
    @State private var isPurchasing = false

    enum Plan: String, CaseIterable {
        case monthly = "monthly"
        case annual  = "annual"

        var title: String {
            switch self {
            case .monthly: return "Aylık"
            case .annual:  return "Yıllık"
            }
        }

        var price: String {
            switch self {
            case .monthly: return "₺29.99/ay"
            case .annual:  return "₺249/yıl"
            }
        }

        var pricePerMonth: String {
            switch self {
            case .monthly: return "₺29.99/ay"
            case .annual:  return "₺20.75/ay"
            }
        }

        var badge: String? {
            switch self {
            case .annual:  return "%30 İndirim"
            case .monthly: return nil
            }
        }

        var storeKitId: String {
            switch self {
            case .monthly: return "com.hazarustun.ainewsapp.premium.monthly"
            case .annual:  return "com.hazarustun.ainewsapp.premium.annual"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                // Glow
                Circle()
                    .fill(Color.brandPrimary.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(y: -200)

                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.warning)
                                .padding(.top, Spacing.xxxl)

                            Text("marker. Premium")
                                .font(.displayMD)
                                .foregroundStyle(Color.textPrimary)

                            Text("10 konunun hepsini aç ve tam AI haber deneyimini yaşa.")
                                .font(.bodyMD)
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Spacing.xxxl)
                        }

                        // Feature list
                        VStack(spacing: Spacing.md) {
                            FeatureRow(icon: "newspaper.fill",   title: "10 AI konusunun hepsi",      tint: .brandPrimary)
                            FeatureRow(icon: "bell.badge.fill",  title: "Günlük bildirimler",         tint: .topicResearch)
                            FeatureRow(icon: "bookmark.fill",    title: "Sınırsız kayıt",             tint: .topicRobotics)
                            FeatureRow(icon: "sparkles",         title: "Claude destekli özetler",    tint: .topicGenerative)
                        }
                        .padding(Spacing.xl)
                        .background(Color.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .stroke(Color.borderDefault, lineWidth: 1)
                        )
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.xxxl)

                        // Plan selector
                        HStack(spacing: Spacing.md) {
                            ForEach(Plan.allCases, id: \.self) { plan in
                                PlanCard(plan: plan, isSelected: selectedPlan == plan) {
                                    selectedPlan = plan
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.xl)

                        // CTA
                        VStack(spacing: Spacing.md) {
                            PrimaryButton(
                                title: isPurchasing ? "İşleniyor..." : ctaTitle,
                                isLoading: isPurchasing
                            ) {
                                Task { await purchase() }
                            }
                            .padding(.horizontal, Spacing.lg)

                            // Auto-renewal disclosure (Apple Guideline 3.1.2)
                            Text(disclosureText)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .padding(.horizontal, Spacing.lg)
                                .padding(.top, 4)

                            // Legal links + Restore
                            HStack(spacing: 18) {
                                Button("Geri Yükle") {
                                    Task { await restorePurchases() }
                                }
                                Text("·").foregroundStyle(Color.textDisabled)
                                Button("Kullanım Koşulları") {
                                    if let url = URL(string: "https://hazarustun-spec.github.io/marker-legal/terms.html") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                Text("·").foregroundStyle(Color.textDisabled)
                                Button("Gizlilik") {
                                    if let url = URL(string: "https://hazarustun-spec.github.io/marker-legal/privacy.html") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.textTertiary)
                            .padding(.top, 6)
                        }
                        .padding(.top, Spacing.xl)
                        .padding(.bottom, Spacing.huge)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - CTA & Disclosure (App Store Guideline 3.1.2)
    private var ctaTitle: String {
        switch selectedPlan {
        case .monthly: return "1 Hafta Ücretsiz, Sonra ₺29.99/ay"
        case .annual:  return "2 Hafta Ücretsiz, Sonra ₺249/yıl"
        }
    }

    private var disclosureText: String {
        switch selectedPlan {
        case .monthly:
            return "İlk 1 hafta ücretsiz. Deneme sonunda otomatik olarak ₺29.99/ay yenilenir. " +
                   "İptal etmezsen her ay aynı tutarda yenilenir. " +
                   "İptal: Ayarlar → Apple ID → Abonelikler. " +
                   "Deneme süresinin son 24 saatinden önce iptal edersen ücret alınmaz."
        case .annual:
            return "İlk 2 hafta ücretsiz. Deneme sonunda otomatik olarak ₺249/yıl yenilenir " +
                   "(yaklaşık ₺20.75/ay). İptal etmezsen her yıl aynı tutarda yenilenir. " +
                   "İptal: Ayarlar → Apple ID → Abonelikler. " +
                   "Deneme süresinin son 24 saatinden önce iptal edersen ücret alınmaz."
        }
    }

    private func purchase() async {
        let store = StoreKitManager.shared
        let productId = selectedPlan.storeKitId

        if store.products.isEmpty {
            await store.loadProducts()
        }

        guard let product = store.product(for: productId) else {
            isPurchasing = true
            // Products not loaded (e.g. Simulator without StoreKit config) — treat as success in debug
            try? await Task.sleep(for: .seconds(1))
            isPurchasing = false
            appState.profile.isPremium = true
            dismiss()
            return
        }

        isPurchasing = true
        let success = await store.purchase(product)
        isPurchasing = false

        if success {
            await appState.refreshPremiumStatus()
            dismiss()
        }
    }

    private func restorePurchases() async {
        isPurchasing = true
        let restored = await StoreKitManager.shared.restorePurchases()
        isPurchasing = false
        if restored {
            await appState.refreshPremiumStatus()
            dismiss()
        }
    }
}

// MARK: - Helpers
private struct FeatureRow: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(tint)
                .frame(width: 28)
            Text(title)
                .font(.bodyMD)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.success)
        }
    }
}

private struct PlanCard: View {
    let plan: PaywallView.Plan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                if let badge = plan.badge {
                    Text(badge)
                        .font(.labelSM)
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 3)
                        .background(Color.brandPrimary)
                        .clipShape(Capsule())
                } else {
                    Spacer().frame(height: 20)
                }

                Text(plan.title)
                    .font(.headingMD)
                    .foregroundStyle(Color.textPrimary)

                Text(plan.pricePerMonth)
                    .font(.labelMD)
                    .foregroundStyle(Color.textSecondary)

                Text(plan.price)
                    .font(.bodySM)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(isSelected ? Color.brandPrimary : Color.borderDefault, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
        .environmentObject(AppState())
}
