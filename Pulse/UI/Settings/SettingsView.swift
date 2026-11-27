import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var settings: PulseSettings

    @State private var includeIPsInExport = false
    @State private var statusBanner: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Settings", subtitle: "Configure Pulse monitoring, appearance, menu bar, and data retention")

                // General
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("General").font(.system(size: 14, weight: .semibold)).foregroundStyle(PulseTheme.primaryText)
                        Toggle("Launch at login", isOn: $settings.launchAtLogin)
                        Toggle("Start minimized (Menu Bar only)", isOn: $settings.startMinimized)
                        Toggle("Show Pulse in Dock", isOn: $settings.showInDock)
                        HStack {
                            Text("Appearance")
                            Spacer()
                            Picker("", selection: $settings.appearance) {
                                ForEach(AppearancePreference.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                        }
                        HStack {
                            Text("Default Dashboard")
                            Spacer()
                            Picker("", selection: $settings.defaultSection) {
                                ForEach(NavigationSection.allCases) { sec in
                                    Text(sec.title).tag(sec)
                                }
                            }
                            .frame(width: 190)
                        }
                    }
                }

                // Monitoring
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Monitoring & Intervals").font(.system(size: 14, weight: .semibold)).foregroundStyle(PulseTheme.primaryText)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], alignment: .leading, spacing: 8) {
                            Toggle("CPU", isOn: $settings.monitorCPU)
                            Toggle("Memory", isOn: $settings.monitorMemory)
                            Toggle("GPU", isOn: $settings.monitorGPU)
                            Toggle("Battery", isOn: $settings.monitorBattery)
                            Toggle("Thermal", isOn: $settings.monitorThermal)
                            Toggle("Storage", isOn: $settings.monitorStorage)
                            Toggle("Network", isOn: $settings.monitorNetwork)
                            Toggle("Processes", isOn: $settings.monitorProcesses)
                        }
                        Divider().overlay(PulseTheme.border)
                        intervalRow("CPU Polling", value: $settings.cpuInterval, range: 1...10)
                        intervalRow("Memory Polling", value: $settings.memoryInterval, range: 1...10)
                        intervalRow("Network Polling", value: $settings.networkInterval, range: 1...10)
                        intervalRow("Battery Polling", value: $settings.batteryInterval, range: 5...60)
                        Toggle("Persist historical metrics to SQLite", isOn: $settings.historyCollectionEnabled)
                    }
                }

                // Menu Bar
                PulseCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Menu Bar Indicators").font(.system(size: 14, weight: .semibold)).foregroundStyle(PulseTheme.primaryText)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], alignment: .leading, spacing: 8) {
                            Toggle("CPU %", isOn: $settings.showMenuBarCPU)
                            Toggle("Memory %", isOn: $settings.showMenuBarMemory)
                            Toggle("Memory Pressure", isOn: $settings.showMenuBarPressure)
                            Toggle("Battery %", isOn: $settings.showMenuBarBattery)
                            Toggle("Download Speed", isOn: $settings.showMenuBarDownload)
                            Toggle("Upload Speed", isOn: $settings.showMenuBarUpload)
                        }
                        Toggle("Compact menu bar formatting", isOn: $settings.menuBarCompact)
                    }
                }

                // Notifications
                PulseCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notifications").font(.system(size: 14, weight: .semibold)).foregroundStyle(PulseTheme.primaryText)
                        Toggle("High CPU usage alert (≥ \(Int(settings.highCPUThreshold))%)", isOn: $settings.notifyHighCPU)
                        Slider(value: $settings.highCPUThreshold, in: 70...98, step: 1)
                        Toggle("Elevated memory pressure alert", isOn: $settings.notifyHighMemoryPressure)
                        Toggle("Low storage alert (< \(Int(settings.lowStorageThresholdPercent))% free)", isOn: $settings.notifyLowStorage)
                        Toggle("Thermal warning alert", isOn: $settings.notifyThermalWarning)
                        Toggle("Low battery alert", isOn: $settings.notifyLowBattery)
                    }
                }

                // Data & Privacy
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data & Privacy").font(.system(size: 14, weight: .semibold)).foregroundStyle(PulseTheme.primaryText)
                        KeyValueRow(key: "Local SQLite Path", value: "~/Library/Application Support/Pulse/pulse.sqlite")
                        Stepper("Retention: \(settings.retentionDays) days", value: $settings.retentionDays, in: 1...90)
                        Toggle("Include interface IP addresses in exported reports", isOn: $includeIPsInExport)

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
                }

                // About
                PulseCard {
                    HStack(spacing: 16) {
                        PulseBrandIcon(size: 52, cornerRadius: 12)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Pulse for macOS")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PulseTheme.primaryText)
                            Text("Version 1.0.0 (Build 1) · Native SwiftUI, Metal, IOKit & Mach APIs")
                                .font(.system(size: 12))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Text("100% local-first. Zero telemetry, zero network dependencies.")
                                .font(.system(size: 11))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                    }
                }
            }
            .padding(22)
        }
        .background(PulseTheme.background)
    }

    private func intervalRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Int(value.wrappedValue))s")
                .monospacedDigit()
                .foregroundStyle(PulseTheme.secondaryText)
                .frame(width: 34)
            Slider(value: value, in: range, step: 1)
                .frame(width: 180)
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
