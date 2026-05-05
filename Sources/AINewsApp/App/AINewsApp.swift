import SwiftUI
import Sentry

@main
struct AINewsApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        SentrySDK.start { options in
            options.dsn = "https://52d17a87df3e5b8ab321c3c2f807a614@o4511334895386625.ingest.de.sentry.io/4511334898335824"
            options.debug = false
            options.tracesSampleRate = 0.2
            options.enableAutoPerformanceTracing = true
            options.enableUserInteractionTracing = true
            #if DEBUG
            options.environment = "debug"
            options.enabled = false   // DEBUG'da kapalı; gerçek crash'ler sadece TestFlight/App Store'dan toplanır
            #else
            options.environment = "production"
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isOnboardingComplete {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(appState)
            .preferredColorScheme(.light)
            // Dynamic Type: large→accessibility2 arası destekle, daha büyüğüne
            // çıkmasın (custom font'lar UI layout'unu kıracak boyutlara ulaşır)
            .dynamicTypeSize(.large ... .accessibility2)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationManager.shared.clearBadge()
                Task { await appState.refreshPremiumStatus() }
            }
        }
    }
}
