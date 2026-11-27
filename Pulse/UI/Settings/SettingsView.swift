import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var settings: PulseSettings

    @State private var includeIPsInExport = false
    @State private var statusBanner: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Settings", subtitle: "Monitoring, appearance, menu bar, and data retention")

                // General
                settingsSection("GENERAL") {
                    switchRow("Launch at login", isOn: $settings.launchAtLogin)
                    hairlineDivider
                    switchRow("Start minimized (Menu Bar only)", isOn: $settings.startMinimized)
                    hairlineDivider
                    switchRow("Show Pulse in Dock", isOn: $settings.showInDock)
                    hairlineDivider
                    HStack {
                        Text("Appearance")
                            .font(.system(size: 12.5))
                            .foregroundStyle(PulseTheme.primaryText)
                        Spacer()
                        PulseSegmentedControl(
                            options: AppearancePreference.allCases.map { ($0, $0.rawValue) },
                            selection: $settings.appearance
                        )
                    }
                    hairlineDivider
                    HStack {
                        Text("Default Dashboard")
                            .font(.system(size: 12.5))
                            .foregroundStyle(PulseTheme.primaryText)
                        Spacer()
                        PulseDropdown(
                            options: NavigationSection.allCases.map { ($0, $0.title) },
                            selection: $settings.defaultSection
                        )
                    }
                }

                // Monitoring
                settingsSection("MONITORING & INTERVALS") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155))], alignment: .leading, spacing: 10) {
                        switchRow("CPU", isOn: $settings.monitorCPU)
                        switchRow("Memory", isOn: $settings.monitorMemory)
                        switchRow("GPU", isOn: $settings.monitorGPU)
                        switchRow("Battery", isOn: $settings.monitorBattery)
                        switchRow("Thermal", isOn: $settings.monitorThermal)
                        switchRow("Storage", isOn: $settings.monitorStorage)
                        switchRow("Network", isOn: $settings.monitorNetwork)
                        switchRow("Processes", isOn: $settings.monitorProcesses)
                    }
                    hairlineDivider
                    intervalRow("CPU Polling", value: $settings.cpuInterval, range: 1...10)
                    hairlineDivider
                    intervalRow("Memory Polling", value: $settings.memoryInterval, range: 1...10)
                    hairlineDivider
                    intervalRow("Network Polling", value: $settings.networkInterval, range: 1...10)
                    hairlineDivider
                    intervalRow("Battery Polling", value: $settings.batteryInterval, range: 5...60)
                    hairlineDivider
                    switchRow("Persist historical metrics to SQLite", isOn: $settings.historyCollectionEnabled)
                }

                // Menu Bar
                settingsSection("MENU BAR INDICATORS") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 175))], alignment: .leading, spacing: 10) {
                        switchRow("CPU %", isOn: $settings.showMenuBarCPU)
                        switchRow("Memory %", isOn: $settings.showMenuBarMemory)
                        switchRow("Memory Pressure", isOn: $settings.showMenuBarPressure)
                        switchRow("Battery %", isOn: $settings.showMenuBarBattery)
                        switchRow("Download Speed", isOn: $settings.showMenuBarDownload)
                        switchRow("Upload Speed", isOn: $settings.showMenuBarUpload)
                    }
                    hairlineDivider
                    switchRow("Compact menu bar formatting", isOn: $settings.menuBarCompact)
                }

                // Notifications
                settingsSection("NOTIFICATIONS") {
                    VStack(alignment: .leading, spacing: 8) {
                        switchRow("High CPU usage alert (≥ \(Int(settings.highCPUThreshold))%)", isOn: $settings.notifyHighCPU)
                        Slider(value: $settings.highCPUThreshold, in: 70...98, step: 1)
                            .tint(PulseTheme.accent)
                    }
                    hairlineDivider
                    switchRow("Elevated memory pressure alert", isOn: $settings.notifyHighMemoryPressure)
                    hairlineDivider
                    switchRow("Low storage alert (< \(Int(settings.lowStorageThresholdPercent))% free)", isOn: $settings.notifyLowStorage)
                    hairlineDivider
                    switchRow("Thermal warning alert", isOn: $settings.notifyThermalWarning)
                    hairlineDivider
                    switchRow("Low battery alert", isOn: $settings.notifyLowBattery)
                }

                // Data & Privacy
                settingsSection("DATA & PRIVACY") {
                    KeyValueRow(key: "SQLite Storage", value: "~/Library/Application Support/Pulse/pulse.sqlite")
                    hairlineDivider
                    HStack {
                        Text("History Retention")
                            .font(.system(size: 12.5))
                            .foregroundStyle(PulseTheme.primaryText)
                        Spacer()
                        PulseDropdown(
                            options: [(1, "1 Day"), (3, "3 Days"), (7, "7 Days"), (14, "14 Days"), (30, "30 Days")],
                            selection: $settings.retentionDays
                        )
                    }
                    hairlineDivider
                    switchRow("Include interface IP addresses in exported reports", isOn: $includeIPsInExport)
                    hairlineDivider
                    HStack(spacing: 10) {
                        Button("Export Diagnostic Report…") { exportReport() }
                            .buttonStyle(.borderedProminent)
                            .tint(PulseTheme.accent)
                        Button("Clear Historical Metrics", role: .destructive) {
                            Task {
                                await monitor.clearHistory()
                                statusBanner = "Historical metrics cleared."
                            }
                        }
                        .buttonStyle(.bordered)
                        Button("Reset Settings") {
                            settings.resetToDefaults()
                            statusBanner = "Settings reset to defaults."
                        }
                        .buttonStyle(.bordered)
                    }
                    if let statusBanner {
                        Text(statusBanner)
                            .font(.system(size: 11))
                            .foregroundStyle(PulseTheme.accent)
                    }
                }

                // About
                PulseCard {
                    HStack(spacing: 16) {
                        PulseBrandIcon(size: 48, cornerRadius: 11)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Pulse for macOS")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PulseTheme.primaryText)
                            Text("Version 1.0.0 (Build 1) · Native SwiftUI, Metal, IOKit & Mach APIs")
                                .font(.system(size: 11.5))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Text("100% local-first. Zero telemetry.")
                                .font(.system(size: 11))
                                .foregroundStyle(PulseTheme.tertiaryText)
                        }
                        Spacer()
                    }
                }
            }
            .padding(22)
        }
        .background(PulseTheme.background)
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(PulseTheme.tertiaryText)
                .padding(.leading, 4)

            PulseCard(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    content()
                }
            }
        }
    }

    private var hairlineDivider: some View {
        Rectangle()
            .fill(PulseTheme.hairline)
            .frame(height: 1)
    }

    private func switchRow(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(PulseTheme.primaryText)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(PulseTheme.accent)
    }

    private func intervalRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(PulseTheme.primaryText)
            Spacer()
            Text("\(Int(value.wrappedValue))s")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(PulseTheme.secondaryText)
                .frame(width: 34, alignment: .trailing)
            Slider(value: value, in: range, step: 1)
                .tint(PulseTheme.accent)
                .frame(width: 170)
        }
    }

    private func exportReport() {
        let report = DiagnosticExporter.generateMarkdownReport(
            identity: monitor.identity,
            cpu: monitor.cpu,
            memory: monitor.memory,
            gpu: monitor.gpu,
            battery: monitor.battery,
            thermal: monitor.thermal,
            storage: monitor.storage,
            network: monitor.network,
            topProcesses: monitor.topCPUProcesses,
            insights: monitor.insights,
            includeNetworkIPs: includeIPsInExport
        )
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Pulse-Diagnostics-\(Int(Date().timeIntervalSince1970)).md"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? report.write(to: url, atomically: true, encoding: .utf8)
            statusBanner = "Diagnostic report saved to \(url.lastPathComponent)."
        }
    }
}
