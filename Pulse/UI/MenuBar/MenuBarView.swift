import SwiftUI
import AppKit

struct MenuBarLabelView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var settings: PulseSettings

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform.path.ecg")
            let text = indicatorSummary
            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
    }

    private var indicatorSummary: String {
        var parts: [String] = []
        if settings.showMenuBarCPU && monitor.cpu.isAvailable {
            parts.append(settings.menuBarCompact ? "\(Int(monitor.cpu.totalUsage.rounded()))%" : "CPU \(Int(monitor.cpu.totalUsage.rounded()))%")
        }
        if settings.showMenuBarMemory && monitor.memory.isAvailable {
            parts.append(settings.menuBarCompact ? "M \(Int(monitor.memory.usedPercentage.rounded()))%" : "Mem \(Int(monitor.memory.usedPercentage.rounded()))%")
        }
        if settings.showMenuBarPressure {
            parts.append(monitor.memory.pressureLevel.rawValue)
        }
        if settings.showMenuBarBattery && monitor.battery.hasBattery {
            parts.append("B \(Int(monitor.battery.percentage.rounded()))%")
        }
        if settings.showMenuBarDownload {
            parts.append("↓\(PulseFormat.speed(monitor.network.downloadBytesPerSec))")
        }
        if settings.showMenuBarUpload {
            parts.append("↑\(PulseFormat.speed(monitor.network.uploadBytesPerSec))")
        }
        return parts.joined(separator: " · ")
    }
}

struct MenuBarDropdownView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @Environment(\.openWindow) private var openWindow
    @Binding var selection: NavigationSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Pulse", systemImage: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(monitor.identity.chipName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("CPU").foregroundStyle(.secondary)
                    Text(PulseFormat.percent(monitor.cpu.totalUsage, decimals: 1)).monospacedDigit()
                }
                GridRow {
                    Text("Memory").foregroundStyle(.secondary)
                    Text("\(PulseFormat.bytes(monitor.memory.usedBytes)) / \(PulseFormat.bytes(monitor.memory.physicalBytes, decimals: 0))").monospacedDigit()
                }
                GridRow {
                    Text("Pressure").foregroundStyle(.secondary)
                    Text(monitor.memory.pressureLevel.rawValue)
                        .foregroundStyle(PulseTheme.color(for: monitor.memory.pressureLevel.status))
                }
                if monitor.battery.hasBattery {
                    GridRow {
                        Text("Battery").foregroundStyle(.secondary)
                        Text("\(PulseFormat.percent(monitor.battery.percentage)) (\(monitor.battery.stateDescription))")
                    }
                }
                GridRow {
                    Text("Thermal").foregroundStyle(.secondary)
                    Text(monitor.thermal.state.rawValue)
                        .foregroundStyle(PulseTheme.color(for: monitor.thermal.state.status))
                }
            }
            .font(.system(size: 12))

            Divider()

            Text("Top Processes")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(monitor.topCPUProcesses.prefix(3)) { proc in
                HStack {
                    Text(proc.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer()
                    Text(PulseFormat.percent(proc.cpuPercent, decimals: 1))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Button("Open Pulse") {
                    openMainWindow(section: monitor.activeInsightsCount > 0 ? .insights : .overview)
                }
                .keyboardShortcut("o")

                Spacer()

                Button("Settings") {
                    openMainWindow(section: .settings)
                }

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .font(.system(size: 12))
        }
        .padding(12)
        .frame(width: 280)
    }

    private func openMainWindow(section: NavigationSection) {
        selection = section
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
    }
}
