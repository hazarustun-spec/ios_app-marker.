import SwiftUI
import Sentry

@main
struct AINewsApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        SentrySDK.start { options in
            // marker. iOS — DSN'i Sentry Dashboard'da proje açtıktan sonra al
            options.dsn = "https://YOUR_SENTRY_DSN@oXXXXXX.ingest.sentry.io/YYYYYY"
            options.debug = false
            options.tracesSampleRate = 0.2
            options.enableAutoPerformanceTracing = true
            options.enableUserInteractionTracing = true
            #if DEBUG
            options.environment = "debug"
            options.enabled = false   // DEBUG'da kapalı, gerçek crash sadece TestFlight/AppStore'dan
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
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationManager.shared.clearBadge()
                Task { await appState.refreshPremiumStatus() }
            }
        }
    }
}
