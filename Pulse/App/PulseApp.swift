import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            PulseSettings.shared.applyAppearance()
            PulseSettings.shared.applyDockPolicy()
            SystemMonitor.shared.start()

            if PulseSettings.shared.startMinimized {
                NSApp.windows.forEach { $0.close() }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in the menu bar when window is closed
        return false
    }
}

@main
struct PulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = SystemMonitor.shared
    @StateObject private var settings = PulseSettings.shared
    @State private var selection: NavigationSection = PulseSettings.shared.defaultSection

    var body: some Scene {
        Window("Pulse", id: "main") {
            MainShellView(selection: $selection)
                .environmentObject(monitor)
                .environmentObject(settings)
        }
        .defaultSize(width: 1250, height: 820)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarDropdownView(selection: $selection)
                .environmentObject(monitor)
                .environmentObject(settings)
        } label: {
            MenuBarLabelView()
                .environmentObject(monitor)
                .environmentObject(settings)
        }
        .menuBarExtraStyle(.window)
    }
}
