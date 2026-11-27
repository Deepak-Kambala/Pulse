import SwiftUI

struct StorageDetailView: View {
    @EnvironmentObject var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Storage",
                    subtitle: "Mounted volumes & capacity via FileManager URL resource APIs"
                ) {
                    if let primary = monitor.storage.primaryVolume {
                        StatusPill(status: primary.status, customLabel: "\(PulseFormat.percent(primary.availablePercentage, decimals: 1)) Free")
                    }
                }

                if let primary = monitor.storage.primaryVolume {
                    MetricStrip(items: [
                        MetricStripItem(label: "Total Capacity", value: PulseFormat.decimalBytes(primary.totalBytes)),
                        MetricStripItem(label: "Used", value: PulseFormat.decimalBytes(primary.usedBytes), detail: PulseFormat.percent(primary.usedPercentage, decimals: 1)),
                        MetricStripItem(label: "Available", value: PulseFormat.decimalBytes(primary.availableBytes), status: primary.status),
                        MetricStripItem(label: "Volumes", value: "\(monitor.storage.volumes.count)")
                    ])
                }

                // Volume Explorer
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Volume Explorer")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)

                        ForEach(monitor.storage.volumes) { vol in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: vol.isInternal ? "internaldrive" : "externaldrive")
                                        .foregroundStyle(PulseTheme.accent)
                                    Text(vol.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(PulseTheme.primaryText)
                                    Text(vol.mountPoint)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                    Spacer()
                                    Text("\(vol.fileSystemType)\(vol.isReadOnly ? " · Read-Only" : "")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                    StatusPill(status: vol.status, customLabel: "\(PulseFormat.percent(vol.usedPercentage, decimals: 0)) Used")
                                }

                                ProgressView(value: vol.usedPercentage, total: 100)
                                    .tint(PulseTheme.color(for: vol.status))

                                HStack {
                                    Text("Used: \(PulseFormat.decimalBytes(vol.usedBytes))")
                                    Spacer()
                                    Text("Available: \(PulseFormat.decimalBytes(vol.availableBytes)) of \(PulseFormat.decimalBytes(vol.totalBytes))")
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(PulseTheme.secondaryText)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 8).fill(PulseTheme.secondaryCard))
                        }
                    }
                }

                PulseCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category Breakdown Note")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)
                        Text("Volume-level APIs report exact total, used, and available capacity without scanning every directory on disk. Pulse does not estimate or fabricate per-category breakdowns (Applications, Documents, System Data) from volume totals.")
                            .font(.system(size: 11))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
            .padding(22)
        }
        .background(PulseTheme.background)
    }
}
