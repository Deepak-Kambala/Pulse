import Foundation
import SwiftUI
import AppKit
import ServiceManagement

enum AppearancePreference: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

enum MenuBarIndicator: String, CaseIterable, Identifiable, Codable {
    case cpu = "CPU %"
    case memory = "Memory %"
    case pressure = "Memory Pressure"
    case battery = "Battery %"
    case download = "Download Speed"
    case upload = "Upload Speed"

    var id: String { rawValue }
}

@MainActor
final class PulseSettings: ObservableObject {
    static let shared = PulseSettings()

    private let defaults = UserDefaults.standard

    // General
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    @Published var startMinimized: Bool { didSet { defaults.set(startMinimized, forKey: "startMinimized") } }
    @Published var defaultSection: NavigationSection {
        didSet { defaults.set(defaultSection.rawValue, forKey: "defaultSection") }
    }
    @Published var appearance: AppearancePreference {
        didSet {
            defaults.set(appearance.rawValue, forKey: "appearance")
            applyAppearance()
        }
    }
    @Published var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: "showInDock")
            applyDockPolicy()
        }
    }

    // Monitoring intervals (seconds)
    @Published var cpuInterval: Double { didSet { defaults.set(cpuInterval, forKey: "cpuInterval") } }
    @Published var memoryInterval: Double { didSet { defaults.set(memoryInterval, forKey: "memoryInterval") } }
    @Published var batteryInterval: Double { didSet { defaults.set(batteryInterval, forKey: "batteryInterval") } }
    @Published var networkInterval: Double { didSet { defaults.set(networkInterval, forKey: "networkInterval") } }
    @Published var historyCollectionEnabled: Bool { didSet { defaults.set(historyCollectionEnabled, forKey: "historyCollectionEnabled") } }
    @Published var retentionDays: Int { didSet { defaults.set(retentionDays, forKey: "retentionDays") } }

    // Enabled monitors
    @Published var monitorCPU: Bool { didSet { defaults.set(monitorCPU, forKey: "monitorCPU") } }
    @Published var monitorMemory: Bool { didSet { defaults.set(monitorMemory, forKey: "monitorMemory") } }
    @Published var monitorGPU: Bool { didSet { defaults.set(monitorGPU, forKey: "monitorGPU") } }
    @Published var monitorBattery: Bool { didSet { defaults.set(monitorBattery, forKey: "monitorBattery") } }
    @Published var monitorThermal: Bool { didSet { defaults.set(monitorThermal, forKey: "monitorThermal") } }
    @Published var monitorStorage: Bool { didSet { defaults.set(monitorStorage, forKey: "monitorStorage") } }
    @Published var monitorNetwork: Bool { didSet { defaults.set(monitorNetwork, forKey: "monitorNetwork") } }
    @Published var monitorProcesses: Bool { didSet { defaults.set(monitorProcesses, forKey: "monitorProcesses") } }

    // Menu bar
    @Published var showMenuBarCPU: Bool { didSet { defaults.set(showMenuBarCPU, forKey: "showMenuBarCPU") } }
    @Published var showMenuBarMemory: Bool { didSet { defaults.set(showMenuBarMemory, forKey: "showMenuBarMemory") } }
    @Published var showMenuBarPressure: Bool { didSet { defaults.set(showMenuBarPressure, forKey: "showMenuBarPressure") } }
    @Published var showMenuBarBattery: Bool { didSet { defaults.set(showMenuBarBattery, forKey: "showMenuBarBattery") } }
    @Published var showMenuBarDownload: Bool { didSet { defaults.set(showMenuBarDownload, forKey: "showMenuBarDownload") } }
    @Published var showMenuBarUpload: Bool { didSet { defaults.set(showMenuBarUpload, forKey: "showMenuBarUpload") } }
    @Published var menuBarCompact: Bool { didSet { defaults.set(menuBarCompact, forKey: "menuBarCompact") } }

    // Notifications
    @Published var notifyHighCPU: Bool { didSet { defaults.set(notifyHighCPU, forKey: "notifyHighCPU") } }
    @Published var highCPUThreshold: Double { didSet { defaults.set(highCPUThreshold, forKey: "highCPUThreshold") } }
    @Published var notifyHighMemoryPressure: Bool { didSet { defaults.set(notifyHighMemoryPressure, forKey: "notifyHighMemoryPressure") } }
    @Published var notifyLowStorage: Bool { didSet { defaults.set(notifyLowStorage, forKey: "notifyLowStorage") } }
    @Published var lowStorageThresholdPercent: Double { didSet { defaults.set(lowStorageThresholdPercent, forKey: "lowStorageThresholdPercent") } }
    @Published var notifyThermalWarning: Bool { didSet { defaults.set(notifyThermalWarning, forKey: "notifyThermalWarning") } }
    @Published var notifyLowBattery: Bool { didSet { defaults.set(notifyLowBattery, forKey: "notifyLowBattery") } }
    @Published var lowBatteryThreshold: Double { didSet { defaults.set(lowBatteryThreshold, forKey: "lowBatteryThreshold") } }
    @Published var notifyMaxBattery: Bool { didSet { defaults.set(notifyMaxBattery, forKey: "notifyMaxBattery") } }
    @Published var maxBatteryThreshold: Double { didSet { defaults.set(maxBatteryThreshold, forKey: "maxBatteryThreshold") } }

    private init() {
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.startMinimized = defaults.bool(forKey: "startMinimized")
        self.defaultSection = NavigationSection(rawValue: defaults.string(forKey: "defaultSection") ?? "overview") ?? .overview
        self.appearance = AppearancePreference(rawValue: defaults.string(forKey: "appearance") ?? "Dark") ?? .dark
        self.showInDock = defaults.object(forKey: "showInDock") as? Bool ?? true

        self.cpuInterval = defaults.object(forKey: "cpuInterval") as? Double ?? 2.0
        self.memoryInterval = defaults.object(forKey: "memoryInterval") as? Double ?? 2.0
        self.batteryInterval = defaults.object(forKey: "batteryInterval") as? Double ?? 10.0
        self.networkInterval = defaults.object(forKey: "networkInterval") as? Double ?? 2.0
        self.historyCollectionEnabled = defaults.object(forKey: "historyCollectionEnabled") as? Bool ?? true
        self.retentionDays = defaults.object(forKey: "retentionDays") as? Int ?? 7

        self.monitorCPU = defaults.object(forKey: "monitorCPU") as? Bool ?? true
        self.monitorMemory = defaults.object(forKey: "monitorMemory") as? Bool ?? true
        self.monitorGPU = defaults.object(forKey: "monitorGPU") as? Bool ?? true
        self.monitorBattery = defaults.object(forKey: "monitorBattery") as? Bool ?? true
        self.monitorThermal = defaults.object(forKey: "monitorThermal") as? Bool ?? true
        self.monitorStorage = defaults.object(forKey: "monitorStorage") as? Bool ?? true
        self.monitorNetwork = defaults.object(forKey: "monitorNetwork") as? Bool ?? true
        self.monitorProcesses = defaults.object(forKey: "monitorProcesses") as? Bool ?? true

        self.showMenuBarCPU = defaults.object(forKey: "showMenuBarCPU") as? Bool ?? true
        self.showMenuBarMemory = defaults.object(forKey: "showMenuBarMemory") as? Bool ?? true
        self.showMenuBarPressure = defaults.object(forKey: "showMenuBarPressure") as? Bool ?? false
        self.showMenuBarBattery = defaults.object(forKey: "showMenuBarBattery") as? Bool ?? false
        self.showMenuBarDownload = defaults.object(forKey: "showMenuBarDownload") as? Bool ?? false
        self.showMenuBarUpload = defaults.object(forKey: "showMenuBarUpload") as? Bool ?? false
        self.menuBarCompact = defaults.object(forKey: "menuBarCompact") as? Bool ?? true

        self.notifyHighCPU = defaults.object(forKey: "notifyHighCPU") as? Bool ?? true
        self.highCPUThreshold = defaults.object(forKey: "highCPUThreshold") as? Double ?? 90.0
        self.notifyHighMemoryPressure = defaults.object(forKey: "notifyHighMemoryPressure") as? Bool ?? true
        self.notifyLowStorage = defaults.object(forKey: "notifyLowStorage") as? Bool ?? true
        self.lowStorageThresholdPercent = defaults.object(forKey: "lowStorageThresholdPercent") as? Double ?? 15.0
        self.notifyThermalWarning = defaults.object(forKey: "notifyThermalWarning") as? Bool ?? true
        self.notifyLowBattery = defaults.object(forKey: "notifyLowBattery") as? Bool ?? true
        self.lowBatteryThreshold = defaults.object(forKey: "lowBatteryThreshold") as? Double ?? 20.0
        self.notifyMaxBattery = defaults.object(forKey: "notifyMaxBattery") as? Bool ?? true
        self.maxBatteryThreshold = defaults.object(forKey: "maxBatteryThreshold") as? Double ?? 80.0
    }

    func applyAppearance() {
        switch appearance {
        case .system: NSApp?.appearance = nil
        case .dark: NSApp?.appearance = NSAppearance(named: .darkAqua)
        case .light: NSApp?.appearance = NSAppearance(named: .aqua)
        }
    }

    func applyDockPolicy() {
        NSApp?.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    func resetToDefaults() {
        launchAtLogin = false
        startMinimized = false
        defaultSection = .overview
        appearance = .dark
        showInDock = true
        cpuInterval = 2.0
        memoryInterval = 2.0
        batteryInterval = 10.0
        networkInterval = 2.0
        historyCollectionEnabled = true
        retentionDays = 7
        monitorCPU = true
        monitorMemory = true
        monitorGPU = true
        monitorBattery = true
        monitorThermal = true
        monitorStorage = true
        monitorNetwork = true
        monitorProcesses = true
        showMenuBarCPU = true
        showMenuBarMemory = true
        showMenuBarPressure = false
        showMenuBarBattery = false
        showMenuBarDownload = false
        showMenuBarUpload = false
        menuBarCompact = true
        notifyHighCPU = true
        highCPUThreshold = 90.0
        notifyHighMemoryPressure = true
        notifyLowStorage = true
        lowStorageThresholdPercent = 15.0
        notifyThermalWarning = true
        notifyLowBattery = true
        lowBatteryThreshold = 20.0
        notifyMaxBattery = true
        maxBatteryThreshold = 80.0
    }
}
