import SwiftUI
import Charts

struct MemoryDetailView: View {
    @EnvironmentObject var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Memory",
                    subtitle: "\(PulseFormat.bytes(monitor.memory.physicalBytes, decimals: 0)) Physical RAM"
                ) {
                    StatusPill(status: monitor.memory.pressureLevel.status, customLabel: monitor.memory.pressureLevel.rawValue)
                }

                // Unified 6-column Metric Strip (no orphan card)
                MetricStrip(items: [
                    MetricStripItem(label: "Physical", value: PulseFormat.bytes(monitor.memory.physicalBytes, decimals: 0)),
                    MetricStripItem(label: "Used", value: PulseFormat.bytes(monitor.memory.usedBytes), detail: PulseFormat.percent(monitor.memory.usedPercentage, decimals: 1)),
                    MetricStripItem(label: "Available", value: PulseFormat.bytes(monitor.memory.availableBytes)),
                    MetricStripItem(label: "Pressure", value: monitor.memory.pressureLevel.rawValue, status: monitor.memory.pressureLevel.status),
                    MetricStripItem(label: "Compressed", value: PulseFormat.bytes(monitor.memory.compressedBytes)),
                    MetricStripItem(label: "Swap Used", value: PulseFormat.bytes(monitor.memory.swapUsedBytes), detail: "of \(PulseFormat.bytes(monitor.memory.swapTotalBytes))")
                ])

                // Memory Composition
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Memory Composition")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PulseTheme.primaryText)
                            Spacer()
                            Text("Cached: \(PulseFormat.bytes(monitor.memory.cachedFilesBytes))")
                                .font(.system(size: 11))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }

                        SegmentedBar(
                            segments: [
                                SegmentedBarSegment(label: "App (\(PulseFormat.bytes(monitor.memory.appBytes)))", value: Double(monitor.memory.appBytes), color: PulseTheme.accent),
                                SegmentedBarSegment(label: "Wired (\(PulseFormat.bytes(monitor.memory.wiredBytes)))", value: Double(monitor.memory.wiredBytes), color: PulseTheme.warning),
                                SegmentedBarSegment(label: "Compressed (\(PulseFormat.bytes(monitor.memory.compressedBytes)))", value: Double(monitor.memory.compressedBytes), color: PulseTheme.secondaryAccent),
                                SegmentedBarSegment(label: "Cached (\(PulseFormat.bytes(monitor.memory.cachedFilesBytes)))", value: Double(monitor.memory.cachedFilesBytes), color: PulseTheme.neutral.opacity(0.6))
                            ],
                            total: Double(max(1, monitor.memory.physicalBytes))
                        )
                    }
                }

                // Memory History Chart
                PulseCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Memory & Swap Trend")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        let recent = monitor.memoryHistory.suffix(120)
                        if recent.count < 2 {
                            Text("Collecting memory samples…")
                                .font(.system(size: 12))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                        } else {
                            Chart {
                                ForEach(Array(recent)) { s in
                                    let usedGB = Double(s.usedBytes) / 1_073_741_824.0
                                    let swapGB = Double(s.swapUsedBytes) / 1_073_741_824.0
                                    LineMark(x: .value("Time", s.timestamp), y: .value("Used GB", usedGB), series: .value("Metric", "Used"))
                                        .foregroundStyle(PulseTheme.secondaryAccent)
                                    LineMark(x: .value("Time", s.timestamp), y: .value("Swap GB", swapGB), series: .value("Metric", "Swap"))
                                        .foregroundStyle(PulseTheme.warning)
                                }
                            }
                            .chartYScale(domain: 0...max(1, Double(monitor.memory.physicalBytes) / 1_073_741_824.0))
                            .chartYAxisLabel("GB")
                            .frame(height: 180)
                        }
                    }
                }

                // Memory-Heavy Processes & Memory Leak Watch
                HStack(alignment: .top, spacing: 14) {
                    PulseCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Memory-Heavy Processes")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PulseTheme.primaryText)
                            ForEach(monitor.topMemoryProcesses.prefix(8)) { proc in
                                HStack {
                                    Text(proc.name)
                                        .font(.system(size: 12))
                                        .foregroundStyle(PulseTheme.primaryText)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("PID \(proc.pid)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                    Text(PulseFormat.percent(proc.memoryPercent, decimals: 1))
                                        .font(.system(size: 11))
                                        .monospacedDigit()
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .frame(width: 48, alignment: .trailing)
                                    Text(PulseFormat.bytes(proc.memoryBytes))
                                        .font(.system(size: 11, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(PulseTheme.secondaryAccent)
                                        .frame(width: 72, alignment: .trailing)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    PulseCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Memory Leak Watch")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PulseTheme.primaryText)
                                Spacer()
                                Text("Possible Growth Anomalies")
                                    .font(.system(size: 10))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            if monitor.memoryGrowthCandidates.isEmpty {
                                Text("No sustained monotonic memory growth detected yet. Processes are observed over ≥20s and ≥25 MB net increase.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(monitor.memoryGrowthCandidates.prefix(6)) { c in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("\(c.name) (PID \(c.pid))")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(PulseTheme.primaryText)
                                            Spacer()
                                            Text("+\(PulseFormat.bytes(c.netIncreaseBytes))")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(PulseTheme.warning)
                                        }
                                        Text("Start \(PulseFormat.bytes(c.startingBytes)) → Current \(PulseFormat.bytes(c.currentBytes)) over \(PulseFormat.duration(c.observationDuration))")
                                            .font(.system(size: 10))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(PulseTheme.secondaryCard))
                                }
                            }
                        }
                    }
                }
            }
            .padding(22)
        }
        .background(PulseTheme.background)
    }
}
