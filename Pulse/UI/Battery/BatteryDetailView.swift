import SwiftUI
import Charts

struct BatteryDetailView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @State private var capacityHistory: [(Date, Double, Int?)] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Battery",
                    subtitle: monitor.battery.hasBattery ? "IOKit Power Sources & AppleSmartBattery" : "No internal battery detected"
                ) {
                    StatusPill(status: monitor.battery.status, customLabel: monitor.battery.stateDescription)
                }

                if !monitor.battery.hasBattery {
                    PulseCard {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(PulseTheme.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("AC-Powered Desktop Mac")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PulseTheme.primaryText)
                                Text("IOPSCopyPowerSourcesInfo did not report an internal battery on this system.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }
                } else {
                    MetricStrip(items: [
                        MetricStripItem(label: "Charge", value: PulseFormat.percent(monitor.battery.percentage), detail: monitor.battery.stateDescription, status: monitor.battery.status),
                        MetricStripItem(label: "Power Source", value: monitor.battery.powerSource.rawValue, detail: monitor.battery.timeRemainingMinutes.map { "\(PulseFormat.timeRemaining(minutes: $0)) left" } ?? "Time est. unavailable"),
                        MetricStripItem(label: "Max Capacity", value: monitor.battery.maxCapacityPercent.map { PulseFormat.percent($0, decimals: 1) } ?? "Unavailable", detail: monitor.battery.condition),
                        MetricStripItem(label: "Cycle Count", value: monitor.battery.cycleCount.map { "\($0)" } ?? "Unavailable")
                    ])

                    // Battery History Graph
                    PulseCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Battery Level History")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PulseTheme.primaryText)
                            if monitor.batteryHistory.count < 2 {
                                Text("Collecting battery samples…")
                                    .font(.system(size: 12))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .frame(height: 180)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Chart(monitor.batteryHistory) { pt in
                                    AreaMark(x: .value("Time", pt.timestamp), y: .value("Charge %", pt.percentage))
                                        .foregroundStyle(PulseTheme.accent.opacity(0.2))
                                    LineMark(x: .value("Time", pt.timestamp), y: .value("Charge %", pt.percentage))
                                        .foregroundStyle(PulseTheme.accent)
                                        .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                                .chartYScale(domain: 0...100)
                                .frame(height: 180)
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 14) {
                        PulseCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Hardware & Electrical Details")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PulseTheme.primaryText)
                                KeyValueRow(key: "Condition", value: monitor.battery.condition)
                                KeyValueRow(key: "Current Capacity", value: monitor.battery.currentCapacityMah.map { "\($0) mAh" } ?? "Unavailable")
                                KeyValueRow(key: "Full Charge Capacity", value: monitor.battery.maxCapacityMah.map { "\($0) mAh" } ?? "Unavailable")
                                KeyValueRow(key: "Design Capacity", value: monitor.battery.designCapacityMah.map { "\($0) mAh" } ?? "Unavailable")
                                KeyValueRow(key: "Battery Temperature", value: monitor.battery.temperatureCelsius.map { String(format: "%.1f °C", $0) } ?? "Unavailable")
                                KeyValueRow(key: "Voltage", value: monitor.battery.voltageMv.map { String(format: "%.2f V", Double($0) / 1000.0) } ?? "Unavailable")
                                KeyValueRow(key: "Amperage", value: monitor.battery.amperageMa.map { "\($0) mA" } ?? "Unavailable")
                            }
                        }

                        PulseCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Battery Health Observations")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PulseTheme.primaryText)
                                if capacityHistory.isEmpty {
                                    Text("Pulse logs maximum capacity hourly to build a longitudinal baseline. Single readings do not constitute a complete degradation analysis.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                } else {
                                    ForEach(Array(capacityHistory.suffix(6).enumerated()), id: \.offset) { _, row in
                                        KeyValueRow(
                                            key: PulseFormat.timestampFormatter.string(from: row.0),
                                            value: "\(PulseFormat.percent(row.1, decimals: 1))\(row.2.map { " (\($0) cyc)" } ?? "")"
                                        )
                                    }
                                }
                                Divider().overlay(PulseTheme.border)
                                Text("Note: Per-app energy impact is not substituted with CPU% without clear labeling; inspect CPU & Processes for workload attribution.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }
                }
            }
            .padding(22)
        }
        .background(PulseTheme.background)
        .task {
            capacityHistory = (try? await DatabaseManager.shared.fetchBatteryCapacityHistory()) ?? []
        }
    }
}
