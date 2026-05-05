import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let notificationId = "daily-news"

    var isAuthorized: Bool = false

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // Schedule (or reschedule) daily notification at the given hour/minute
    func scheduleDailyNotification(hour: Int, minute: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "marker. hazır"
        content.body = "Günlük AI haber özetin seni bekliyor."
        content.sound = .default
        content.badge = 1

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)

        try? await center.add(request)
    }

    func cancelNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
    }

    // Clear badge when app opens
    func clearBadge() {
        center.setBadgeCount(0)
    }
}
