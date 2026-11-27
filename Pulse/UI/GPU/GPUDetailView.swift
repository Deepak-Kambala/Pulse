import SwiftUI
import Charts

struct GPUDetailView: View {
    @EnvironmentObject var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "GPU",
                    subtitle: monitor.gpu.primaryDevice.map { "\($0.name) · \($0.familyDescription)" } ?? "Metal & graphics hardware"
                ) {
                    if let primary = monitor.gpu.primaryDevice {
                        StatusPill(
                            status: .healthy,
                            customLabel: primary.hasUnifiedMemory ? "Unified Memory" : "Discrete GPU"
                        )
                    } else {
                        StatusPill(status: .neutral, customLabel: "Unavailable")
                    }
                }

                if let device = monitor.gpu.primaryDevice {
                    MetricStrip(items: [
                        MetricStripItem(
                            label: "Utilization",
                            value: device.utilizationPercent.map { PulseFormat.percent($0, decimals: 1) } ?? "Unavailable",
                            status: device.utilizationPercent == nil ? .neutral : .healthy
                        ),
                        MetricStripItem(
                            label: "In-Use Memory",
                            value: device.inUseSystemMemoryBytes.map { PulseFormat.bytes($0) } ?? "Unavailable",
                            status: device.inUseSystemMemoryBytes == nil ? .neutral : .healthy
                        ),
                        MetricStripItem(
                            label: "Max Working Set",
                            value: PulseFormat.bytes(device.recommendedMaxWorkingSetBytes)
                        ),
                        MetricStripItem(
                            label: "Max Buffer",
                            value: PulseFormat.bytes(device.maxBufferLengthBytes)
                        )
                    ])

                    // GPU Utilization Chart
                    PulseCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("GPU Utilization")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PulseTheme.primaryText)
                                Spacer()
                                if let util = device.utilizationPercent {
                                    Text(PulseFormat.percent(util, decimals: 1))
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(PulseTheme.accent)
                                }
                            }

                            let recent = monitor.gpuHistory.suffix(120)
                            if recent.count < 2 {
                                Text("Collecting GPU utilization samples…")
                                    .font(.system(size: 12))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .frame(height: 180)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Chart(Array(recent)) { pt in
                                    AreaMark(
                                        x: .value("Time", pt.timestamp),
                                        y: .value("Utilization %", pt.utilizationPercent)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [PulseTheme.accent.opacity(0.22), PulseTheme.accent.opacity(0.0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)

                                    LineMark(
                                        x: .value("Time", pt.timestamp),
                                        y: .value("Utilization %", pt.utilizationPercent)
                                    )
                                    .foregroundStyle(PulseTheme.accent)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                    .interpolationMethod(.catmullRom)
                                }
                                .chartYScale(domain: 0...100)
                                .frame(height: 180)
                            }
                        }
                    }

                    // Bottom Row: GPU Memory Chart + Device Capabilities
                    HStack(alignment: .top, spacing: 14) {
                        PulseCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("GPU Memory Usage")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(PulseTheme.primaryText)
                                    Spacer()
                                    if let mem = device.inUseSystemMemoryBytes {
                                        Text(PulseFormat.bytes(mem))
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(PulseTheme.secondaryAccent)
                                    }
                                }

                                let recent = monitor.gpuHistory.suffix(120)
                                if recent.count < 2 {
                                    Text("Collecting GPU memory samples…")
                                        .font(.system(size: 12))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .frame(height: 150)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Chart(Array(recent)) { pt in
                                        let mb = Double(pt.inUseMemoryBytes) / 1_048_576.0
                                        AreaMark(x: .value("Time", pt.timestamp), y: .value("MB", mb))
                                            .foregroundStyle(PulseTheme.secondaryAccent.opacity(0.18))
                                        LineMark(x: .value("Time", pt.timestamp), y: .value("MB", mb))
                                            .foregroundStyle(PulseTheme.secondaryAccent)
                                            .lineStyle(StrokeStyle(lineWidth: 1.75))
                                    }
                                    .chartYAxisLabel("MB")
                                    .frame(height: 150)
                                }
                            }
                        }

                        PulseCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Device Capabilities")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PulseTheme.primaryText)
                                Rectangle().fill(PulseTheme.hairline).frame(height: 1)
                                KeyValueRow(key: "Processor", value: device.name)
                                KeyValueRow(key: "Architecture", value: device.familyDescription)
                                KeyValueRow(key: "Memory Model", value: device.hasUnifiedMemory ? "Unified" : "Discrete")
                                KeyValueRow(key: "Low Power Mode", value: device.isLowPower ? "Yes" : "No")
                                KeyValueRow(key: "Display Output", value: device.isHeadless ? "Headless" : "Active")
                                KeyValueRow(key: "Recommended Limit", value: PulseFormat.bytes(device.recommendedMaxWorkingSetBytes))
                            }
                        }
                        .frame(minWidth: 270, maxWidth: 340)
                    }
                } else {
                    PulseCard {
                        Text("No Metal-capable GPU devices detected.")
                            .font(.system(size: 13))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
            .padding(22)
        }
        .background(PulseTheme.background)
    }
}
