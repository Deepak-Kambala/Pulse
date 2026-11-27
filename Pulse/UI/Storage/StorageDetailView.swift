import SwiftUI
import Charts
import AppKit

struct StorageDetailView: View {
    @EnvironmentObject var monitor: SystemMonitor

    private let categoryColors: [Color] = [
        PulseTheme.accent,
        PulseTheme.secondaryAccent,
        PulseTheme.warning,
        Color(nsColor: .systemPurple),
        Color(nsColor: .systemPink),
        PulseTheme.neutral
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Storage",
                    subtitle: "Mounted volumes, disk I/O & directory usage"
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
                        MetricStripItem(
                            label: "Disk Activity",
                            value: "\(PulseFormat.speed(monitor.storage.diskReadBytesPerSec)) / \(PulseFormat.speed(monitor.storage.diskWriteBytesPerSec))",
                            detail: "Read / Write"
                        )
                    ])
                }

                // Directory Breakdown + Disk I/O Chart side by side
                HStack(alignment: .top, spacing: 14) {
                    // Measured Directory Breakdown
                    PulseCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Space Breakdown")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PulseTheme.primaryText)
                                Spacer()
                                Button {
                                    monitor.scanStorageBreakdown()
                                } label: {
                                    HStack(spacing: 4) {
                                        if monitor.isScanningStorage {
                                            ProgressView().controlSize(.mini)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 10.5))
                                        }
                                        Text(monitor.isScanningStorage ? "Scanning…" : "Rescan")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundStyle(PulseTheme.secondaryText)
                                }
                                .buttonStyle(.plain)
                                .disabled(monitor.isScanningStorage)
                            }

                            if monitor.storageBreakdown.isEmpty {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text("Measuring folder sizes…")
                                        .font(.system(size: 12))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                                .padding(.vertical, 20)
                            } else {
                                if let primary = monitor.storage.primaryVolume {
                                    let segments = monitor.storageBreakdown.prefix(5).enumerated().map { idx, cat in
                                        SegmentedBarSegment(
                                            label: cat.name,
                                            value: Double(cat.bytes),
                                            color: categoryColors[idx % categoryColors.count]
                                        )
                                    }
                                    SegmentedBar(segments: segments, total: Double(max(1, primary.usedBytes)))
                                }

                                Rectangle().fill(PulseTheme.hairline).frame(height: 1)

                                ForEach(Array(monitor.storageBreakdown.enumerated()), id: \.element.id) { idx, cat in
                                    HStack(spacing: 10) {
                                        Image(systemName: cat.symbolName)
                                            .font(.system(size: 12))
                                            .foregroundStyle(categoryColors[idx % categoryColors.count])
                                            .frame(width: 18)
                                        Text(cat.name)
                                            .font(.system(size: 12.5))
                                            .foregroundStyle(PulseTheme.primaryText)
                                        Spacer()
                                        Text(PulseFormat.decimalBytes(cat.bytes))
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundStyle(PulseTheme.primaryText)
                                        Button {
                                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: cat.path)])
                                        } label: {
                                            Image(systemName: "folder")
                                                .font(.system(size: 11))
                                                .foregroundStyle(PulseTheme.tertiaryText)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Reveal in Finder")
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }

                    // Disk I/O Throughput Chart
                    PulseCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Disk I/O Throughput")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PulseTheme.primaryText)
                                Spacer()
                                HStack(spacing: 10) {
                                    HStack(spacing: 4) {
                                        Circle().fill(PulseTheme.accent).frame(width: 6, height: 6)
                                        Text("Read").font(.system(size: 11)).foregroundStyle(PulseTheme.secondaryText)
                                    }
                                    HStack(spacing: 4) {
                                        Circle().fill(PulseTheme.secondaryAccent).frame(width: 6, height: 6)
                                        Text("Write").font(.system(size: 11)).foregroundStyle(PulseTheme.secondaryText)
                                    }
                                }
                            }

                            let recent = monitor.diskIOHistory.suffix(90)
                            if recent.count < 2 {
                                Text("Sampling disk activity…")
                                    .font(.system(size: 12))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .frame(height: 170)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Chart {
                                    ForEach(Array(recent)) { s in
                                        LineMark(x: .value("Time", s.timestamp), y: .value("Read MB/s", s.readBytesPerSec / 1_048_576.0), series: .value("Op", "Read"))
                                            .foregroundStyle(PulseTheme.accent)
                                        LineMark(x: .value("Time", s.timestamp), y: .value("Write MB/s", s.writeBytesPerSec / 1_048_576.0), series: .value("Op", "Write"))
                                            .foregroundStyle(PulseTheme.secondaryAccent)
                                    }
                                }
                                .chartYAxisLabel("MB/s")
                                .frame(height: 170)
                            }

                            Rectangle().fill(PulseTheme.hairline).frame(height: 1)
                            KeyValueRow(key: "Total Read (since boot)", value: PulseFormat.bytes(monitor.storage.totalDiskBytesRead))
                            KeyValueRow(key: "Total Written (since boot)", value: PulseFormat.bytes(monitor.storage.totalDiskBytesWritten))
                        }
                    }
                    .frame(minWidth: 300, maxWidth: 380)
                }

                // Mounted Volumes
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mounted Volumes")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)

                        ForEach(monitor.storage.volumes) { vol in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: vol.isInternal ? "internaldrive" : "externaldrive")
                                        .foregroundStyle(PulseTheme.accent)
                                    Text(vol.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(PulseTheme.primaryText)
                                    Text(vol.mountPoint)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(PulseTheme.tertiaryText)
                                    Spacer()
                                    Text("\(vol.fileSystemType)\(vol.isReadOnly ? " · Read-Only" : "")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                    StatusPill(status: vol.status, customLabel: "\(PulseFormat.percent(vol.usedPercentage, decimals: 0)) Used")
                                    Button {
                                        NSWorkspace.shared.open(URL(fileURLWithPath: vol.mountPoint))
                                    } label: {
                                        Image(systemName: "arrow.up.forward.square")
                                            .font(.system(size: 12))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open in Finder")
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
            }
            .padding(22)
        }
        .background(PulseTheme.background)
        .onAppear {
            if monitor.storageBreakdown.isEmpty {
                monitor.scanStorageBreakdown()
            }
        }
    }
}
