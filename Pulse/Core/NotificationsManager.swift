import Foundation
import UserNotifications

@MainActor
final class NotificationsManager {
    static let shared = NotificationsManager()

    private var lastSent: [String: Date] = [:]
    private let cooldown: TimeInterval = 600 // 10 minutes
    private var hasRequestedAuthorization = false

    private var isBundledApp: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    func requestAuthorizationIfNeeded() {
        guard isBundledApp, !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendIfAllowed(key: String, title: String, body: String) {
        guard isBundledApp else { return }
        let now = Date()
        if let prev = lastSent[key], now.timeIntervalSince(prev) < cooldown {
            return
        }
        lastSent[key] = now

        requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "pulse.\(key).\(Int(now.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
