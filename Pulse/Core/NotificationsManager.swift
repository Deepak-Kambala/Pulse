import Foundation
import UserNotifications
import AppKit

@MainActor
final class NotificationsManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationsManager()

    private var lastSent: [String: Date] = [:]
    private let cooldown: TimeInterval = 600 // 10 minutes
    private var hasConfiguredDelegate = false
    private var hasRequestedAuthorization = false
    private var activeSound: NSSound?

    private var isBundledApp: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    func configure() {
        guard isBundledApp, !hasConfiguredDelegate else { return }
        hasConfiguredDelegate = true
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationIfNeeded() {
        guard isBundledApp, !hasRequestedAuthorization else { return }
        configure()
        hasRequestedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Sends a macOS notification. Only `mustSee` notifications pop onto the screen;
    /// non-urgent ones stay quiet in Notification Center / Insights without interrupting.
    func sendIfAllowed(
        key: String,
        title: String,
        body: String,
        soundName: String? = nil,
        mustSee: Bool = false,
        bypassCooldown: Bool = false
    ) {
        let now = Date()
        if !bypassCooldown, let prev = lastSent[key], now.timeIntervalSince(prev) < cooldown {
            return
        }
        lastSent[key] = now

        if mustSee, let soundName {
            playSound(named: soundName)
        }

        guard isBundledApp else { return }
        requestAuthorizationIfNeeded()

        // Only force onto screen if mustSee; otherwise keep it silent in the background
        guard mustSee else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = ["mustSee": mustSee]
        if soundName == nil {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "pulse.\(key).\(Int(now.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let mustSee = (notification.request.content.userInfo["mustSee"] as? Bool) ?? false
        if mustSee {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.list])
        }
    }

    func playSound(named name: String) {
        let url = Bundle.main.url(forResource: name, withExtension: "mp3") ?? moduleSoundURL(named: name)
        guard let url, let sound = NSSound(contentsOf: url, byReference: true) else { return }
        activeSound?.stop()
        activeSound = sound
        sound.play()
    }

    private func moduleSoundURL(named name: String) -> URL? {
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: name, withExtension: "mp3")
        #else
        return nil
        #endif
    }
}
