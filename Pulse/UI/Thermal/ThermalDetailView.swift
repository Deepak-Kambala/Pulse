import SwiftUI
import Charts

struct ThermalDetailView: View {
    @EnvironmentObject var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Thermal",
                    subtitle: monitor.thermal.state.summaryDescription
                ) {
                    StatusPill(status: monitor.thermal.state.status, customLabel: monitor.thermal.state.rawValue)
                }

                MetricStrip(items: [
                    MetricStripItem(label: "Thermal State", value: monitor.thermal.state.rawValue, status: monitor.thermal.state.status),
                    MetricStripItem(label: "CPU Temp", value: monitor.thermal.cpuTemperatureCelsius.map { String(format: "%.1f °C", $0) } ?? "Unavailable", status: .neutral),
                    MetricStripItem(label: "GPU Temp", value: monitor.thermal.gpuTemperatureCelsius.map { String(format: "%.1f °C", $0) } ?? "Unavailable", status: .neutral),
                    MetricStripItem(label: "Fan Speed", value: monitor.thermal.fanSpeedRPM.map { "\($0) RPM" } ?? "Unavailable", status: .neutral)
                ])

                PulseCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Thermal State & CPU Load Correlation")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        if monitor.thermalHistory.count < 2 {
                            Text("Collecting thermal & CPU samples…")
                                .font(.system(size: 12))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                        } else {
                            Chart(monitor.thermalHistory.suffix(120)) { pt in
                                BarMark(
                                    x: .value("Time", pt.timestamp),
                                    y: .value("Thermal Level", Double(pt.state.numericLevel) * 25.0)
                                )
                                .foregroundStyle(PulseTheme.color(for: pt.state.status).opacity(0.45))

                                LineMark(
                                    x: .value("Time", pt.timestamp),
                                    y: .value("CPU %", pt.cpuUsageAtTime)
                                )
                                .foregroundStyle(PulseTheme.accent)
                            }
                            .chartYScale(domain: 0...100)
                            .frame(height: 180)
                        }
                    }
                }
            }
            .padding(22)
        }
        .background(PulseTheme.background)
    }
}
