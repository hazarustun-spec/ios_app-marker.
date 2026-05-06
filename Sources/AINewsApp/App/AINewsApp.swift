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

            // Performance — cold start tracking için
            options.tracesSampleRate = 1.0           // tüm cold start'ları topla (kritik metric)
            options.profilesSampleRate = 0.5         // %50 profiling — detaylı breakdown
            options.enableAutoPerformanceTracing = true   // app.start.cold/.warm transactions otomatik
            options.enableUserInteractionTracing = true

            // App Hang Detection — main thread donmalarını yakala (2s+ → cold start hedefini aşar)
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 2.0

            // Auto-track view appears + network calls
            options.enableNetworkTracking = true
            options.enableFileIOTracing = true

            #if DEBUG
            options.environment = "debug"
            options.enabled = false
            #else
            options.environment = "production"
            #endif
        }

        // Cold start breadcrumb — Sentry trace'inde görünür
        SentrySDK.addBreadcrumb({
            let crumb = Breadcrumb(level: .info, category: "app.lifecycle")
            crumb.message = "AINewsApp init complete"
            return crumb
        }())
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
