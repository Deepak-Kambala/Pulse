import SwiftUI
import Charts

enum CPUTimeFilter: String, CaseIterable, Identifiable {
    case oneMin = "1m"
    case fiveMin = "5m"
    case fifteenMin = "15m"
    case thirtyMin = "30m"
    case oneHour = "1h"
    case sixHours = "6h"

    var id: String { rawValue }
    var seconds: TimeInterval {
        switch self {
        case .oneMin: return 60
        case .fiveMin: return 300
        case .fifteenMin: return 900
        case .thirtyMin: return 1800
        case .oneHour: return 3600
        case .sixHours: return 21600
        }
    }
}

struct CPUDetailView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @State private var filter: CPUTimeFilter = .fiveMin
    @State private var hoverDate: Date?

    private var filteredSamples: [CPUSample] {
        let cutoff = Date().addingTimeInterval(-filter.seconds)
        return monitor.cpuHistory.filter { $0.timestamp >= cutoff }
    }

    private var hoveredSample: CPUSample? {
        guard let hoverDate else { return nil }
        return filteredSamples.min(by: { abs($0.timestamp.timeIntervalSince(hoverDate)) < abs($1.timestamp.timeIntervalSince(hoverDate)) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "CPU",
                    subtitle: "\(monitor.identity.chipName) · \(monitor.cpu.logicalCoreCount) logical cores"
                ) {
                    Picker("Window", selection: $filter) {
                        ForEach(CPUTimeFilter.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                }

                // Unified 5-column Metric Strip
                MetricStrip(items: [
                    MetricStripItem(label: "Current CPU", value: PulseFormat.percent(monitor.cpu.totalUsage, decimals: 1), status: monitor.cpu.status),
                    MetricStripItem(label: "User", value: PulseFormat.percent(monitor.cpu.userUsage, decimals: 1)),
                    MetricStripItem(label: "System", value: PulseFormat.percent(monitor.cpu.systemUsage, decimals: 1)),
                    MetricStripItem(label: "Idle", value: PulseFormat.percent(monitor.cpu.idleUsage, decimals: 1)),
                    MetricStripItem(label: "Logical Cores", value: "\(monitor.cpu.logicalCoreCount)")
                ])

                // Main Multi-Series CPU Chart
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("CPU Utilization History")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PulseTheme.primaryText)
                            Spacer()
                            if let s = hoveredSample {
                                HStack(spacing: 12) {
                                    Text(PulseFormat.shortTimeFormatter.string(from: s.timestamp))
                                    Text("User \(PulseFormat.percent(s.user, decimals: 1))").foregroundStyle(PulseTheme.accent)
                                    Text("Sys \(PulseFormat.percent(s.system, decimals: 1))").foregroundStyle(PulseTheme.secondaryAccent)
                                    Text("Idle \(PulseFormat.percent(s.idle, decimals: 1))").foregroundStyle(PulseTheme.secondaryText)
                                }
                                .font(.system(size: 11, design: .monospaced))
                            } else {
                                HStack(spacing: 12) {
                                    legendDot("User", color: PulseTheme.accent)
                                    legendDot("System", color: PulseTheme.secondaryAccent)
                                    legendDot("Idle", color: PulseTheme.neutral)
                                }
                            }
                        }

                        if filteredSamples.count < 2 {
                            Text("Collecting CPU samples…")
                                .font(.system(size: 12))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .frame(height: 220)
                                .frame(maxWidth: .infinity)
                        } else {
                            Chart {
                                ForEach(filteredSamples) { sample in
                                    LineMark(x: .value("Time", sample.timestamp), y: .value("User", sample.user), series: .value("Series", "User"))
                                        .foregroundStyle(PulseTheme.accent)
                                        .lineStyle(StrokeStyle(lineWidth: 2))
                                    LineMark(x: .value("Time", sample.timestamp), y: .value("System", sample.system), series: .value("Series", "System"))
                                        .foregroundStyle(PulseTheme.secondaryAccent)
                                        .lineStyle(StrokeStyle(lineWidth: 2))
                                    LineMark(x: .value("Time", sample.timestamp), y: .value("Idle", sample.idle), series: .value("Series", "Idle"))
                                        .foregroundStyle(PulseTheme.neutral.opacity(0.6))
                                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                                }
                                if let s = hoveredSample {
                                    RuleMark(x: .value("Hover", s.timestamp))
                                        .foregroundStyle(PulseTheme.border)
                                }
                            }
                            .chartYScale(domain: 0...100)
                            .chartYAxis {
                                AxisMarks(values: [0, 25, 50, 75, 100]) { val in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(PulseTheme.border)
                                    AxisValueLabel {
                                        if let v = val.as(Int.self) { Text("\(v)%").font(.system(size: 10)) }
                                    }
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(PulseTheme.border.opacity(0.5))
                                    AxisValueLabel(format: .dateTime.hour().minute().second())
                                }
                            }
                            .chartOverlay { proxy in
                                GeometryReader { _ in
                                    Rectangle().fill(.clear).contentShape(Rectangle())
                                        .onContinuousHover { phase in
                                            switch phase {
                                            case .active(let loc):
                                                hoverDate = proxy.value(atX: loc.x)
                                            case .ended:
                                                hoverDate = nil
                                            }
                                        }
                                }
                            }
                            .frame(height: 220)
                        }
                    }
                }

                // Per-Core Grid
                PulseCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Per-Core Utilization")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                            ForEach(monitor.cpu.cores) { core in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text("Core \(core.id)")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(PulseTheme.primaryText)
                                        Spacer()
                                        Text(PulseFormat.percent(core.totalUsage, decimals: 0))
                                            .font(.system(size: 11, weight: .semibold))
                                            .monospacedDigit()
                                            .foregroundStyle(PulseTheme.color(for: core.status))
                                    }
                                    ProgressView(value: core.totalUsage, total: 100)
                                        .tint(PulseTheme.color(for: core.status))
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

                // Diagnostics & Top CPU Processes
                HStack(alignment: .top, spacing: 14) {
                    PulseCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Top CPU Processes")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PulseTheme.primaryText)
                            ForEach(monitor.topCPUProcesses.prefix(8)) { proc in
                                HStack {
                                    Text(proc.name)
                                        .font(.system(size: 12))
                                        .foregroundStyle(PulseTheme.primaryText)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("PID \(proc.pid)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                    Text(proc.user)
                                        .font(.system(size: 10))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .frame(width: 70, alignment: .trailing)
                                    Text(PulseFormat.bytes(proc.memoryBytes))
                                        .font(.system(size: 11))
                                        .monospacedDigit()
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .frame(width: 68, alignment: .trailing)
                                    Text(PulseFormat.percent(proc.cpuPercent, decimals: 1))
                                        .font(.system(size: 11, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(PulseTheme.accent)
                                        .frame(width: 54, alignment: .trailing)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    PulseCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CPU Diagnostics")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PulseTheme.primaryText)
                            let peak = filteredSamples.map(\.total).max() ?? monitor.cpu.totalUsage
                            let avg = filteredSamples.isEmpty ? monitor.cpu.totalUsage : filteredSamples.map(\.total).reduce(0, +) / Double(filteredSamples.count)
                            KeyValueRow(key: "Window Peak", value: PulseFormat.percent(peak, decimals: 1))
                            KeyValueRow(key: "Window Average", value: PulseFormat.percent(avg, decimals: 1))
                            KeyValueRow(key: "Spikes (≥ 85%)", value: "\(filteredSamples.filter { $0.total >= 85 }.count)")
                        }
                    }
                    .frame(width: 280)
                }
            }
            .padding(22)
        }
        .background(PulseTheme.background)
    }

    private func legendDot(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).font(.system(size: 11)).foregroundStyle(PulseTheme.secondaryText)
        }
    }
}
