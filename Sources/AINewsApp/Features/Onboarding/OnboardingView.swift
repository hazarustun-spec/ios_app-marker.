import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentPage = 0
    @State private var selectedTopicIds: [String] = []
    @State private var selectedTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var didSignIn = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgPrimary.ignoresSafeArea()

            // Pages — manual switch, no swipe gesture (user must complete step)
            Group {
                switch currentPage {
                case 0:
                    WelcomePage(didSignIn: $didSignIn, onSignedIn: {
                        withAnimation(.easeInOut) { currentPage = 1 }
                    })
                case 1:
                    TopicSelectionPage(
                        selectedIds: $selectedTopicIds,
                        isPremium: appState.profile.isPremium,
                        onContinue: {
                            withAnimation(.easeInOut) { currentPage = 2 }
                        }
                    )
                case 2:
                    DeliveryTimePage(
                        selectedTime: $selectedTime,
                        onContinue: { finishOnboarding() }
                    )
                default:
                    EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Color.textPrimary : Color.borderDefault)
                        .frame(width: i == currentPage ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            .padding(.bottom, 14)
        }
    }

    private func finishOnboarding() {
        for id in selectedTopicIds {
            if let topic = Topic.all.first(where: { $0.id == id }) {
                appState.selectTopic(topic)
            }
        }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        Task {
            await appState.updateDeliveryTime(hour: comps.hour ?? 8, minute: comps.minute ?? 0)
        }
        appState.completeOnboarding()
    }
}

// MARK: - Welcome (splash) Page
private struct WelcomePage: View {
    @EnvironmentObject private var appState: AppState
    @Binding var didSignIn: Bool
    let onSignedIn: () -> Void
    @State private var isAuthenticating = false
    @State private var legalSheet: LegalDocument? = nil

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                // Top bar — close to safe area
                HStack {
                    BriefLogo(size: 28)
                    Spacer()
                    Text("v1.0 · GÜNLÜK")
                        .font(.labelSM)
                        .foregroundStyle(Color.textTertiary)
                        .tracking(1)
                }
                .padding(.top, 8)
                .padding(.horizontal, 28)

                Spacer().frame(maxHeight: 40)

                // Big serif title with italic "yapay"
                VStack(alignment: .leading, spacing: -4) {
                    Text("Bugün")
                        .font(Font.custom("InstrumentSerif-Regular", size: 64))
                        .foregroundStyle(Color.textPrimary)
                    Text("yapay")
                        .font(Font.custom("InstrumentSerif-Italic", size: 64))
                        .foregroundStyle(Color.textPrimary)
                    Text("zekâda.")
                        .font(Font.custom("InstrumentSerif-Regular", size: 64))
                        .foregroundStyle(Color.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 18)

                Text("Günlük, otomatik özet.\nAltı haber. Beş dakika. Gürültüsüz.")
                    .font(.bodyLG)
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 22)
                    .padding(.horizontal, 28)

                // AI disclosure
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textPrimary)
                    Text("İçerik yapay zekâ tarafından çoklu kaynaktan üretilir.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#555555"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.brandPrimary.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.top, 14)
                .padding(.horizontal, 28)

                Spacer()

                // Sign in with Apple — required to continue
                VStack(spacing: 12) {
                    if let err = appState.authError {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.error)
                                Text("GİRİŞ YAPILAMADI")
                                    .font(.labelSM)
                                    .foregroundStyle(Color.error)
                                    .tracking(0.5)
                            }
                            Text(err)
                                .font(.bodySM)
                                .foregroundStyle(Color.textSecondary)
                                .lineSpacing(2)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.error.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    ZStack {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = appState.generateNonce()
                            isAuthenticating = true
                        } onCompletion: { result in
                            Task {
                                await appState.handleAppleSignIn(result: result)
                                isAuthenticating = false
                                if appState.isAuthenticated {
                                    didSignIn = true
                                    onSignedIn()
                                }
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .opacity(isAuthenticating ? 0.55 : 1)
                        .allowsHitTesting(!isAuthenticating)

                        if isAuthenticating {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(.white)
                                Text("Doğrulanıyor…")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            .allowsHitTesting(false)
                        }
                    }

                    // Legal disclosure
                    HStack(spacing: 0) {
                        Text("Devam ederek ")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                        Button("Kullanım Koşulları") {
                            legalSheet = .terms
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        Text(" ve ")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                        Button("Gizlilik Politikası") {
                            legalSheet = .privacy
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        Text("'nı kabul etmiş olursun.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .multilineTextAlignment(.center)

                    Text(todayLabel)
                        .font(.labelSM)
                        .foregroundStyle(Color.textTertiary)
                        .tracking(0.5)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 50)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .sheet(item: $legalSheet) { doc in LegalView(document: doc) }
        }
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEE · dd MMM"
        return f.string(from: Date()).uppercased() + " · 10 KONU"
    }
}

// MARK: - Topic Selection Page
private struct TopicSelectionPage: View {
    @Binding var selectedIds: [String]
    let isPremium: Bool
    let onContinue: () -> Void

    private let minTopics = 3
    private var maxTopics: Int { isPremium ? 10 : 3 }
    private var isAtLimit: Bool { selectedIds.count >= maxTopics }
    private var canContinue: Bool { selectedIds.count >= minTopics }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("İlgi alanlarını seç.")
                        .font(Font.custom("InstrumentSerif-Regular", size: 36))
                        .foregroundStyle(Color.textPrimary)

                    Text(isPremium
                         ? "10 konunun hepsini seçebilirsin."
                         : "En az 3 konu seç. Premium ile 10'unun hepsi açılır.")
                        .font(.bodyMD)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)

                HStack {
                    Text("\(selectedIds.count) / \(maxTopics) seçildi")
                        .font(.labelSM)
                        .foregroundStyle(canContinue ? Color.success : Color.textTertiary)
                        .tracking(0.5)

                    Spacer()

                    if !canContinue {
                        Text("EN AZ \(minTopics) GEREKLİ")
                            .font(.labelSM)
                            .foregroundStyle(Color.textTertiary)
                            .tracking(0.5)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)

                // Topic list (scrollable, fills middle)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Topic.all) { topic in
                            let isSelected = selectedIds.contains(topic.id)
                            let isDisabled = !isSelected && isAtLimit

                            OnboardingTopicRow(
                                topic: topic,
                                isSelected: isSelected,
                                isDisabled: isDisabled
                            ) {
                                if isSelected {
                                    selectedIds.removeAll { $0 == topic.id }
                                } else if !isAtLimit {
                                    selectedIds.append(topic.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                }

                // Continue button (locked until 3 selected)
                Button {
                    if canContinue { onContinue() }
                } label: {
                    Text(canContinue
                         ? "Devam et (\(selectedIds.count) seçildi)"
                         : "Devam etmek için \(minTopics - selectedIds.count) konu daha seç")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(canContinue ? Color.textPrimary : Color.textPrimary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(!canContinue)
                .padding(.horizontal, 22)
                .padding(.bottom, 50)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Topic row
private struct OnboardingTopicRow: View {
    let topic: Topic
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    private var tone: CardTone { CardTone.forTopicId(topic.id) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tone.background)
                    .frame(width: 44, height: 44)
                    .overlay(Text(topic.emoji).font(.system(size: 18)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.name)
                        .font(.headingMD)
                        .foregroundStyle(Color.textPrimary)
                    Text(topic.description)
                        .font(.bodySM)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.textPrimary : Color.borderDefault, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(Color.textPrimary)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
            }
            .padding(14)
            .background(isSelected ? Color.toneMint.opacity(0.4) : Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
    }
}

// MARK: - Delivery Time Page
private struct DeliveryTimePage: View {
    @Binding var selectedTime: Date
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Haberlerini\nne zaman istiyorsun?")
                        .font(Font.custom("InstrumentSerif-Regular", size: 36))
                        .foregroundStyle(Color.textPrimary)

                    Text("Her gün bu saatte sana bildirim gönderiyoruz.")
                        .font(.bodyMD)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 24)

                Spacer()

                // Time picker
                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.toneMint)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .padding(.horizontal, 22)

                Spacer()

                Button(action: onContinue) {
                    Text("Başla")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 50)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
