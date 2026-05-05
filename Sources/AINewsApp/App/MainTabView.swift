import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .today

    enum Tab: String, CaseIterable {
        case today    = "Bugün"
        case feed     = "Akış"
        case saved    = "Kaydedilenler"
        case settings = "Otomasyon"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgPrimary.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .today:    HomeView()
                case .feed:     FeedView()
                case .saved:    SavedView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Black pill bottom nav
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    let isActive = selectedTab == tab
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(isActive ? Color.textPrimary : Color.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isActive ? Capsule().fill(Color.brandPrimary) : Capsule().fill(Color.clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Capsule().fill(Color.navBackground))
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
