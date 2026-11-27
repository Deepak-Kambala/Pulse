import SwiftUI
import Charts

struct NetworkDetailView: View {
    @EnvironmentObject var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Network",
                    subtitle: "Real-time interface throughput via getifaddrs & AF_LINK counters"
                ) {
                    StatusPill(status: monitor.network.activeInterfacesCount > 0 ? .healthy : .neutral, customLabel: "\(monitor.network.activeInterfacesCount) Active")
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    PulseStatTile(title: "Download Speed", value: PulseFormat.speed(monitor.network.downloadBytesPerSec))
                    PulseStatTile(title: "Upload Speed", value: PulseFormat.speed(monitor.network.uploadBytesPerSec))
                    PulseStatTile(title: "Total Received", value: PulseFormat.bytes(monitor.network.totalBytesReceived))
                    PulseStatTile(title: "Total Sent", value: PulseFormat.bytes(monitor.network.totalBytesSent))
                    PulseStatTile(title: "Active Interfaces", value: "\(monitor.network.activeInterfacesCount)")
                }

                PulseCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Throughput History (KB/s)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PulseTheme.primaryText)
                            Spacer()
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Circle().fill(PulseTheme.accent).frame(width: 7, height: 7)
                                    Text("Download").font(.system(size: 11)).foregroundStyle(PulseTheme.secondaryText)
                                }
                                HStack(spacing: 4) {
                                    Circle().fill(PulseTheme.secondaryAccent).frame(width: 7, height: 7)
                                    Text("Upload").font(.system(size: 11)).foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        }

                        let recent = monitor.networkHistory.suffix(120)
                        if recent.count < 2 {
                            Text("Collecting network throughput samples…")
                                .font(.system(size: 12))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                        } else {
                            Chart {
                                ForEach(Array(recent)) { s in
                                    LineMark(x: .value("Time", s.timestamp), y: .value("Down KB/s", s.downloadBytesPerSec / 1024.0), series: .value("Dir", "Download"))
                                        .foregroundStyle(PulseTheme.accent)
                                    LineMark(x: .value("Time", s.timestamp), y: .value("Up KB/s", s.uploadBytesPerSec / 1024.0), series: .value("Dir", "Upload"))
                                        .foregroundStyle(PulseTheme.secondaryAccent)
                                }
                            }
                            .frame(height: 180)
                        }
                    }
                }

                PulseCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Interface Explorer")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PulseTheme.primaryText)

                        ForEach(monitor.network.interfaces) { iface in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(iface.name)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(PulseTheme.primaryText)
                                        Text(iface.kind)
                                            .font(.system(size: 11))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                    Text("IPv4: \(iface.ipv4Address ?? "—") · IPv6: \(iface.ipv6Address ?? "—")")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Rx \(PulseFormat.bytes(iface.bytesReceived)) · Tx \(PulseFormat.bytes(iface.bytesSent))")
                                        .font(.system(size: 11))
                                        .monospacedDigit()
                                        .foregroundStyle(PulseTheme.primaryText)
                                    Text(iface.isUp && iface.isRunning ? "Up & Running" : (iface.isUp ? "Up" : "Down"))
                                        .font(.system(size: 10))
                                        .foregroundStyle(iface.isUp && iface.isRunning ? PulseTheme.healthy : PulseTheme.secondaryText)
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(PulseTheme.secondaryCard))
                        }
                    }
                }
            }
            .padding(22)
        }
        .background(PulseTheme.background)
    }
}
