import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var delivery = "07:00"
    @State private var pushOn = true
    @State private var autoFetch = true
    @State private var showPaywall = false
    @State private var showSignOutAlert = false
    @State private var legalSheet: LegalDocument? = nil
    @State private var showDeleteAccountAlert = false

    // Notification times — news always arrive at 06:30 IST sharp, so options
    // start at 06:30. Earlier options would notify before content is ready.
    private let deliveryOptions = ["06:30", "07:00", "08:00", "09:00", "12:00", "18:00"]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header bar
                    HStack {
                        BriefLogo()
                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Otomasyon.")
                            .font(.displayLG)
                            .foregroundStyle(Color.textPrimary)
                        Text("Özetin her sabah 40+ kaynaktan derlenir.")
                            .font(.bodyMD)
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: 280, alignment: .leading)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)

                    // Delivery card (mint)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                                .overlay(Image(systemName: "clock").font(.system(size: 16)).foregroundStyle(Color.textPrimary))
                            Text("BİLDİRİM SAATİ")
                                .font(.labelSM)
                                .foregroundStyle(Color(hex: "#3a4f1a"))
                        }
                        .padding(.bottom, 18)

                        Text(delivery)
                            .font(.displayXL)
                            .foregroundStyle(Color.textPrimary)
                            .padding(.bottom, 6)

                        Text("Haberler 06:30'da hazır oluyor")
                            .font(.bodySM)
                            .foregroundStyle(Color(hex: "#3a4f1a"))
                            .padding(.bottom, 16)

                        FlowLayout(spacing: 6) {
                            ForEach(deliveryOptions, id: \.self) { t in
                                Button {
                                    delivery = t
                                    let parts = t.split(separator: ":").compactMap { Int($0) }
                                    if parts.count == 2 {
                                        Task { await appState.updateDeliveryTime(hour: parts[0], minute: parts[1]) }
                                    }
                                } label: {
                                    Text(t)
                                        .font(.labelMD)
                                        .foregroundStyle(delivery == t ? Color.white : Color.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule().fill(delivery == t ? Color.textPrimary : Color.white.opacity(0.6))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(22)
                    .background(Color.toneMint)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)

                    // Toggle list
                    VStack(spacing: 0) {
                        AutoToggleRow(
                            label: "Otomatik kaynak çekme",
                            help: "40+ araştırma blogu, makale ve haber sitesi",
                            isOn: $autoFetch
                        )
                        Divider().background(Color.borderSubtle)
                        AutoToggleRow(
                            label: "Sabah bildirimi",
                            help: "Seçtiğin saatte tek bildirim — özet 06:30'da hazır",
                            isOn: $pushOn,
                            onChange: {
                                if pushOn {
                                    Task {
                                        let granted = await appState.requestNotificationPermission()
                                        if !granted { appState.openNotificationSettings() }
                                    }
                                } else {
                                    appState.notifications.cancelNotification()
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)

                    // Topics shortcut
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KONULARIM")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .tracking(1.0)
                            .padding(.horizontal, 22)
                            .padding(.top, 16)

                        VStack(alignment: .leading, spacing: 14) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "square.grid.2x2.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.textPrimary)
                                )

                            Text(topicsLine)
                                .font(.bodyMD)
                                .foregroundStyle(Color.textPrimary)
                                .lineSpacing(3)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.toneSage)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        .padding(.horizontal, 22)
                    }

                    // Subscription
                    if !appState.profile.isPremium {
                        Button { showPaywall = true } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Premium'a yükselt")
                                        .font(.headingMD)
                                        .foregroundStyle(Color.white)
                                    Text("10 konu · günlük bildirim · sınırsız kayıt")
                                        .font(.bodySM)
                                        .foregroundStyle(Color.white.opacity(0.7))
                                }
                                Spacer()
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                            .padding(22)
                            .background(Color.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                    }

                    // Legal section
                    VStack(spacing: 0) {
                        legalRow(icon: "lock.shield", title: "Gizlilik Politikası") {
                            legalSheet = .privacy
                        }
                        Divider().background(Color.borderSubtle)
                        legalRow(icon: "doc.text", title: "Kullanım Koşulları") {
                            legalSheet = .terms
                        }
                        Divider().background(Color.borderSubtle)
                        legalRow(icon: "star.bubble", title: "Aboneliği yönet") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                        Divider().background(Color.borderSubtle)
                        legalRow(icon: "trash", title: "Hesabı Sil", tint: .error) {
                            showDeleteAccountAlert = true
                        }
                    }
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .padding(.horizontal, 22)
                    .padding(.top, 16)

                    // Brand block
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "#1a1a1a"))
                            .frame(width: 40, height: 40)
                            .overlay(BriefLogo(size: 20, color: .white))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("marker. · v1.0.0")
                                .font(.headingSM)
                                .foregroundStyle(Color.white)
                            Text("HER GÜN 06:30")
                                .font(.labelSM)
                                .foregroundStyle(Color.white.opacity(0.5))
                        }

                        Spacer()

                        Button("Çıkış") { showSignOutAlert = true }
                            .font(.bodySM)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .padding(22)
                    .background(Color.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                    .padding(.horizontal, 22)
                    .padding(.top, 12)

                    Spacer().frame(height: 110)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(appState)
        }
        .alert("Çıkış yap", isPresented: $showSignOutAlert) {
            Button("Çıkış", role: .destructive) { appState.signOut() }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Hesabından çıkış yapmak istediğine emin misin?")
        }
        .alert("Hesabı Sil", isPresented: $showDeleteAccountAlert) {
            Button("Hesabı Kalıcı Olarak Sil", role: .destructive) {
                Task { await appState.deleteAccount() }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Bu işlem geri alınamaz. Tüm verilerin (kayıtlı haberler, tercihler, profil) kalıcı olarak silinir.")
        }
        .sheet(item: $legalSheet) { doc in
            LegalView(document: doc)
        }
        .onAppear {
            let h = appState.deliveryHour
            let m = appState.deliveryMinute
            delivery = String(format: "%02d:%02d", h, m)
        }
    }

    @ViewBuilder
    private func legalRow(icon: String, title: String, tint: Color = .textPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                Text(title)
                    .font(.bodyMD)
                    .foregroundStyle(tint)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var topicsLine: String {
        let count = appState.profile.selectedTopicIds.count
        let limit = appState.profile.topicLimit
        return "Seçili \(count)/\(limit) konu. Premium ile 10 konunun hepsini açabilirsin."
    }
}

// MARK: - Toggle row
private struct AutoToggleRow: View {
    let label: String
    let help: String
    @Binding var isOn: Bool
    var onChange: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.headingMD)
                    .foregroundStyle(Color.textPrimary)
                Text(help)
                    .font(.bodySM)
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Button {
                isOn.toggle()
                onChange?()
            } label: {
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Color.textPrimary : Color(hex: "#e6e6e6"))
                        .frame(width: 50, height: 30)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .padding(3)
                }
                .animation(.easeInOut(duration: 0.2), value: isOn)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Flow layout for time pills
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, maxH: CGFloat = 0, rowH: CGFloat = 0
        for subview in subviews {
            let sz = subview.sizeThatFits(.unspecified)
            if x + sz.width > width && x > 0 {
                y += rowH + spacing; x = 0; rowH = 0
            }
            rowH = max(rowH, sz.height)
            x += sz.width + spacing
            maxH = max(maxH, y + rowH)
        }
        return CGSize(width: width, height: maxH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for subview in subviews {
            let sz = subview.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX {
                y += rowH + spacing; x = bounds.minX; rowH = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            rowH = max(rowH, sz.height)
            x += sz.width + spacing
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
