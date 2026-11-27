import SwiftUI

struct GPUDetailView: View {
    @EnvironmentObject var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "GPU",
                    subtitle: "Metal device discovery & IOKit accelerator capabilities"
                ) {
                    StatusPill(
                        status: monitor.gpu.isAvailable ? .healthy : .neutral,
                        customLabel: "\(monitor.gpu.devices.count) Device(s)"
                    )
                }

                if monitor.gpu.devices.isEmpty {
                    PulseCard {
                        Text("No Metal-capable GPU devices were reported by MTLCopyAllDevices().")
                            .font(.system(size: 13))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                } else {
                    ForEach(monitor.gpu.devices) { device in
                        PulseCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.name)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(PulseTheme.primaryText)
                                        Text(device.familyDescription)
                                            .font(.system(size: 12))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                    Spacer()
                                    StatusPill(status: .healthy, customLabel: device.hasUnifiedMemory ? "Unified Memory" : "Discrete")
                                }

                                MetricStrip(items: [
                                    MetricStripItem(label: "Utilization", value: device.utilizationPercent.map { PulseFormat.percent($0, decimals: 1) } ?? "Unavailable", detail: device.utilizationPercent == nil ? "Not in public API" : "IOAccelerator", status: device.utilizationPercent == nil ? .neutral : .healthy),
                                    MetricStripItem(label: "In-Use Memory", value: device.inUseSystemMemoryBytes.map { PulseFormat.bytes($0) } ?? "Unavailable", detail: device.inUseSystemMemoryBytes == nil ? "Driver restricted" : "System memory", status: device.inUseSystemMemoryBytes == nil ? .neutral : .healthy),
                                    MetricStripItem(label: "Max Working Set", value: PulseFormat.bytes(device.recommendedMaxWorkingSetBytes), detail: "Metal recommended"),
                                    MetricStripItem(label: "Max Buffer", value: PulseFormat.bytes(device.maxBufferLengthBytes), detail: "Metal limit")
                                ])

                                Divider().overlay(PulseTheme.border)
                                KeyValueRow(key: "Registry ID", value: String(format: "0x%llX", device.id))
                                KeyValueRow(key: "Low Power", value: device.isLowPower ? "Yes" : "No")
                                KeyValueRow(key: "Headless", value: device.isHeadless ? "Yes" : "No")
                                KeyValueRow(key: "Pulse Metal Allocated", value: PulseFormat.bytes(device.currentAllocatedBytes))

                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(PulseTheme.secondaryAccent)
                                    Text(device.driverStatusNote)
                                        .font(.system(size: 11))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(PulseTheme.secondaryCard))
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
