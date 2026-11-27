import Foundation
import UserNotifications
import AppKit

@MainActor
final class NotificationsManager {
    static let shared = NotificationsManager()

    private var lastSent: [String: Date] = [:]
    private let cooldown: TimeInterval = 600 // 10 minutes
    private var hasRequestedAuthorization = false
    private var activeSound: NSSound?

    private var isBundledApp: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    func requestAuthorizationIfNeeded() {
        guard isBundledApp, !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendIfAllowed(key: String, title: String, body: String, soundName: String? = nil, bypassCooldown: Bool = false) {
        let now = Date()
        if !bypassCooldown, let prev = lastSent[key], now.timeIntervalSince(prev) < cooldown {
            return
        }
        lastSent[key] = now

        if let soundName {
            playSound(named: soundName)
        }

        guard isBundledApp else { return }
        requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
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
