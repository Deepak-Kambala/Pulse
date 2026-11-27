import SwiftUI
import Charts

struct PerformanceHistoryView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @State private var range: HistoryTimeRange = .oneHour
    @State private var snapshots: [MetricSnapshot] = []
    @State private var isLoading = false

    private let repo = HistoryRepository()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Performance History",
                    subtitle: "\(monitor.snapshotCount) recorded snapshots"
                ) {
                    PulseSegmentedControl(
                        options: HistoryTimeRange.allCases.map { ($0, $0.rawValue) },
                        selection: $range
                    )
                }

                if snapshots.count < 2 {
                    PulseCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Building Historical Dataset")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PulseTheme.primaryText)
                            Text("Pulse records system snapshots to SQLite every 10 seconds. Keep Pulse running to inspect trends across 5 minutes to 7 days.")
                                .font(.system(size: 12))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                } else {
                    // CPU History + Summary
                    historyChartCard(
                        title: "CPU Utilization (%)",
                        values: snapshots.map { ($0.timestamp, $0.cpuTotal) },
                        color: PulseTheme.accent,
                        unitSuffix: "%",
                        yDomain: 0...100
                    )

                    // Memory History + Summary
                    historyChartCard(
                        title: "Memory Usage (GB)",
                        values: snapshots.map { ($0.timestamp, Double($0.memoryUsedBytes) / 1_073_741_824.0) },
                        color: PulseTheme.secondaryAccent,
                        unitSuffix: " GB",
                        yDomain: nil
                    )

                    // Battery History (if available)
                    let batValues = snapshots.compactMap { s in s.batteryPercent.map { (s.timestamp, $0) } }
                    if batValues.count >= 2 {
                        historyChartCard(
                            title: "Battery Charge (%)",
                            values: batValues,
                            color: PulseTheme.healthy,
                            unitSuffix: "%",
                            yDomain: 0...100
                        )
                    }

                    // Network History
                    historyChartCard(
                        title: "Network Download (KB/s)",
                        values: snapshots.map { ($0.timestamp, $0.networkDownBps / 1024.0) },
                        color: PulseTheme.accent,
                        unitSuffix: " KB/s",
                        yDomain: nil
                    )

                    // Thermal State History
                    historyChartCard(
                        title: "Thermal Pressure Level (0=Nominal, 3=Critical)",
                        values: snapshots.map { ($0.timestamp, Double($0.thermalLevel)) },
                        color: PulseTheme.warning,
                        unitSuffix: "",
                        yDomain: 0...3
                    )
                }
            }
            .padding(22)
        }
        .background(PulseTheme.background)
        .task(id: range) {
            await load()
        }
        .onChange(of: monitor.snapshotCount) { _, _ in
            Task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        snapshots = await repo.loadSnapshots(for: range)
        isLoading = false
    }

    @ViewBuilder
    private func historyChartCard(
        title: String,
        values: [(Date, Double)],
        color: Color,
        unitSuffix: String,
        yDomain: ClosedRange<Double>?
    ) -> some View {
        let stats = HistoryRepository.summarize(values)
        PulseCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PulseTheme.primaryText)
                    Spacer()
                    if let stats {
                        HStack(spacing: 14) {
                            Text(String(format: "Min %.1f%@", stats.minimum, unitSuffix))
                            Text(String(format: "Avg %.1f%@", stats.average, unitSuffix))
                            Text(String(format: "Peak %.1f%@", stats.peak, unitSuffix))
                                .foregroundStyle(color)
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(PulseTheme.secondaryText)
                    }
                }

                Chart {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, pt in
                        LineMark(x: .value("Time", pt.0), y: .value("Value", pt.1))
                            .foregroundStyle(color)
                            .lineStyle(StrokeStyle(lineWidth: 1.75))
                    }
                }
                .chartYScale(domain: yDomain ?? 0...max(1, (values.map(\.1).max() ?? 1) * 1.15))
                .frame(height: 150)

                if let peakTime = stats?.peakTime {
                    Text("Peak recorded at \(PulseFormat.timestampFormatter.string(from: peakTime))")
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }
}
