import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @Binding var selection: NavigationSection

    private let columns = [
        GridItem(.adaptive(minimum: 310, maximum: 520), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerBanner

                LazyVGrid(columns: columns, spacing: 14) {
                    cpuCard
                    memoryCard
                    gpuCard
                    batteryCard
                    thermalCard
                    storageCard
                    networkCard
                    topProcessesCard
                }

                insightsCard
            }
            .padding(22)
        }
        .background(PulseTheme.background)
    }

    private var headerBanner: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("System Overview")
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(PulseTheme.primaryText)
                Text("\(monitor.identity.deviceModel) · \(monitor.identity.chipName) · \(monitor.identity.osVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            HStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("UPTIME")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(PulseTheme.tertiaryText)
                    Text(PulseFormat.uptime(monitor.identity.uptimeSeconds))
                        .font(.system(size: 12.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(PulseTheme.primaryText)
                }
                StatusPill(
                    status: monitor.isMonitoring ? .healthy : .neutral,
                    customLabel: monitor.isMonitoring ? "Live" : "Paused"
                )
            }
        }
        .padding(.bottom, 4)
    }

    private var cpuCard: some View {
        let points = monitor.cpuHistory.suffix(45).map { ($0.timestamp, $0.total) }
        let peak = points.map(\.1).max() ?? monitor.cpu.totalUsage
        return Button { selection = .cpu } label: {
            PulseCard(isInteractive: true) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("CPU", systemImage: "cpu")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        Spacer()
                        StatusPill(status: monitor.cpu.status)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(PulseFormat.percent(monitor.cpu.totalUsage))
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(PulseTheme.primaryText)
                        Text("CPU Usage")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseTheme.secondaryText)
                        Spacer()
                        Text("Peak \(PulseFormat.percent(peak))")
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    SparklineChart(points: points, color: PulseTheme.accent, maxY: 100)
                        .frame(height: 56)
                    HStack {
                        Text("User \(PulseFormat.percent(monitor.cpu.userUsage, decimals: 1))")
                        Text("·")
                        Text("System \(PulseFormat.percent(monitor.cpu.systemUsage, decimals: 1))")
                        Spacer()
                        Text("\(monitor.cpu.logicalCoreCount) Cores")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var memoryCard: some View {
        let points = monitor.memoryHistory.suffix(45).map {
            ($0.timestamp, monitor.memory.physicalBytes > 0 ? (Double($0.usedBytes) / Double(monitor.memory.physicalBytes)) * 100.0 : 0)
        }
        return Button { selection = .memory } label: {
            PulseCard(isInteractive: true) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Memory", systemImage: "memorychip")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        Spacer()
                        StatusPill(status: monitor.memory.pressureLevel.status, customLabel: monitor.memory.pressureLevel.rawValue)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(PulseFormat.bytes(monitor.memory.usedBytes))")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(PulseTheme.primaryText)
                        Text("/ \(PulseFormat.bytes(monitor.memory.physicalBytes, decimals: 0))")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseTheme.secondaryText)
                        Spacer()
                        Text("Avail \(PulseFormat.bytes(monitor.memory.availableBytes))")
                            .font(.system(size: 11))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    SparklineChart(points: points, color: PulseTheme.secondaryAccent, maxY: 100)
                        .frame(height: 56)
                    HStack {
                        Text("Wired \(PulseFormat.bytes(monitor.memory.wiredBytes))")
                        Text("·")
                        Text("Comp \(PulseFormat.bytes(monitor.memory.compressedBytes))")
                        Spacer()
                        Text("Swap \(PulseFormat.bytes(monitor.memory.swapUsedBytes))")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var gpuCard: some View {
        Button { selection = .gpu } label: {
            PulseCard(isInteractive: true) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("GPU", systemImage: "display")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        Spacer()
                        StatusPill(status: monitor.gpu.isAvailable ? .healthy : .neutral, customLabel: monitor.gpu.isAvailable ? "Metal" : "Unavailable")
                    }
                    if let gpu = monitor.gpu.primaryDevice {
                        Text(gpu.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                            .lineLimit(1)
                        Text(gpu.familyDescription)
                            .font(.system(size: 11))
                            .foregroundStyle(PulseTheme.secondaryText)
                        Divider().overlay(PulseTheme.border)
                        KeyValueRow(
                            key: "Utilization",
                            value: gpu.utilizationPercent.map { PulseFormat.percent($0, decimals: 1) } ?? "Unavailable (public API)"
                        )
                        KeyValueRow(
                            key: "Max Working Set",
                            value: PulseFormat.bytes(gpu.recommendedMaxWorkingSetBytes)
                        )
                        KeyValueRow(
                            key: "Unified Memory",
                            value: gpu.hasUnifiedMemory ? "Yes" : "Discrete"
                        )
                    } else {
                        Text("No Metal GPU detected.")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var batteryCard: some View {
        Button { selection = .battery } label: {
            PulseCard(isInteractive: true) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Battery", systemImage: "battery.75percent")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        Spacer()
                        StatusPill(status: monitor.battery.status, customLabel: monitor.battery.stateDescription)
                    }
                    if monitor.battery.hasBattery {
                        HStack(alignment: .firstTextBaseline) {
                            Text(PulseFormat.percent(monitor.battery.percentage))
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(PulseTheme.primaryText)
                            Text("Battery")
                                .font(.system(size: 12))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Spacer()
                            if let mins = monitor.battery.timeRemainingMinutes {
                                Text("\(PulseFormat.timeRemaining(minutes: mins)) left")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                        ProgressView(value: monitor.battery.percentage, total: 100)
                            .tint(PulseTheme.color(for: monitor.battery.status))
                        HStack {
                            Text("Health: \(monitor.battery.condition)")
                            if let cap = monitor.battery.maxCapacityPercent {
                                Text("· \(PulseFormat.percent(cap, decimals: 0)) Max")
                            }
                            Spacer()
                            if let cycles = monitor.battery.cycleCount {
                                Text("\(cycles) cycles")
                            }
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.secondaryText)
                    } else {
                        Text("No internal battery present (Desktop Mac).")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .padding(.vertical, 24)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var thermalCard: some View {
        Button { selection = .thermal } label: {
            PulseCard(isInteractive: true) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Thermal", systemImage: "thermometer.medium")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        Spacer()
                        StatusPill(status: monitor.thermal.state.status, customLabel: monitor.thermal.state.rawValue)
                    }
                    Text(monitor.thermal.state.rawValue)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(PulseTheme.primaryText)
                    Text(monitor.thermal.state.summaryDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(2)
                    Divider().overlay(PulseTheme.border)
                    KeyValueRow(key: "CPU / GPU Temp", value: "Unavailable (public API)", valueColor: PulseTheme.secondaryText)
                    KeyValueRow(key: "Fan Speed", value: "Unavailable (public API)", valueColor: PulseTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var storageCard: some View {
        Button { selection = .storage } label: {
            PulseCard(isInteractive: true) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Storage", systemImage: "internaldrive")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        Spacer()
                        if let vol = monitor.storage.primaryVolume {
                            StatusPill(status: vol.status, customLabel: "\(PulseFormat.percent(vol.usedPercentage)) Used")
                        }
                    }
                    if let vol = monitor.storage.primaryVolume {
                        HStack(alignment: .firstTextBaseline) {
                            Text(PulseFormat.decimalBytes(vol.availableBytes))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(PulseTheme.primaryText)
                            Text("Available")
                                .font(.system(size: 12))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Spacer()
                            Text("of \(PulseFormat.decimalBytes(vol.totalBytes))")
                                .font(.system(size: 11))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        ProgressView(value: vol.usedPercentage, total: 100)
                            .tint(PulseTheme.color(for: vol.status))
                        HStack {
                            Text("\(vol.name) (\(vol.fileSystemType))")
                            Spacer()
                            Text("\(monitor.storage.volumes.count) volume(s)")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.secondaryText)
                    } else {
                        Text("Reading volume metadata…")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var networkCard: some View {
        let downPoints = monitor.networkHistory.suffix(45).map { ($0.timestamp, $0.downloadBytesPerSec / 1024.0) }
        return Button { selection = .network } label: {
            PulseCard(isInteractive: true) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Network", systemImage: "network")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        Spacer()
                        StatusPill(status: monitor.network.activeInterfacesCount > 0 ? .healthy : .neutral, customLabel: "\(monitor.network.activeInterfacesCount) Active")
                    }
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Download")
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Text(PulseFormat.speed(monitor.network.downloadBytesPerSec))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(PulseTheme.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upload")
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Text(PulseFormat.speed(monitor.network.uploadBytesPerSec))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(PulseTheme.secondaryAccent)
                        }
                        Spacer()
                    }
                    SparklineChart(points: downPoints, color: PulseTheme.accent, maxY: nil)
                        .frame(height: 44)
                    HStack {
                        Text("Rx \(PulseFormat.bytes(monitor.network.totalBytesReceived))")
                        Spacer()
                        Text("Tx \(PulseFormat.bytes(monitor.network.totalBytesSent))")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var topProcessesCard: some View {
        Button { selection = .processes } label: {
            PulseCard(isInteractive: true) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Top Processes", systemImage: "list.bullet.rectangle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        Spacer()
                        Text("View All →")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    if monitor.topCPUProcesses.isEmpty {
                        Text("Sampling processes…")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(monitor.topCPUProcesses.prefix(5)) { proc in
                            HStack(spacing: 8) {
                                Text(proc.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PulseTheme.primaryText)
                                    .lineLimit(1)
                                Spacer()
                                Text("PID \(proc.pid)")
                                    .font(.system(size: 10))
                                    .monospacedDigit()
                                    .foregroundStyle(PulseTheme.secondaryText)
                                Text(PulseFormat.bytes(proc.memoryBytes))
                                    .font(.system(size: 11))
                                    .monospacedDigit()
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .frame(width: 64, alignment: .trailing)
                                Text(PulseFormat.percent(proc.cpuPercent, decimals: 1))
                                    .font(.system(size: 11, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(proc.cpuPercent >= 50 ? PulseTheme.warning : PulseTheme.accent)
                                    .frame(width: 52, alignment: .trailing)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var insightsCard: some View {
        let active = monitor.insights.filter { !$0.isDismissed }
        return PulseCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Pulse Insights", systemImage: "lightbulb")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PulseTheme.primaryText)
                    Spacer()
                    Button("Open Insights →") {
                        selection = .insights
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
                }

                if active.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PulseTheme.healthy)
                        Text("No performance anomalies detected from current monitoring data.")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(active.prefix(3)) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.severity.symbolName)
                                .foregroundStyle(PulseTheme.color(for: item.severity.status))
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PulseTheme.primaryText)
                                Text(item.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            Spacer()
                            Text(PulseFormat.shortTimeFormatter.string(from: item.detectedAt))
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(PulseTheme.secondaryCard)
                        )
                    }
                }
            }
        }
    }
}
