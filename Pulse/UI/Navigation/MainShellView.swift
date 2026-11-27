import SwiftUI

struct MainShellView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var settings: PulseSettings
    @Binding var selection: NavigationSection

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 205, ideal: 215, max: 230)
        } detail: {
            ZStack {
                PulseTheme.background.ignoresSafeArea()
                detailView(for: selection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    monitor.refreshNow()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .help("Sample all system monitors now")
            }
        }
        .preferredColorScheme(settings.appearance.colorScheme)
        .frame(minWidth: 1000, minHeight: 680)
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Minimalist Brand Header
            HStack(spacing: 10) {
                PulseBrandIcon(size: 28, cornerRadius: 7)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Pulse")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(PulseTheme.primaryText)
                    Text("Understand your Mac.")
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.tertiaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)

            // Custom Sleek Sidebar Navigation (no loud default blue bar)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(NavigationGroup.allCases, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.rawValue.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(PulseTheme.tertiaryText)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 3)

                            ForEach(NavigationSection.allCases.filter { $0.group == group }) { item in
                                sidebarRow(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
            }

            Rectangle()
                .fill(PulseTheme.hairline)
                .frame(height: 1)

            // Compact Footer
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(monitor.isMonitoring ? PulseTheme.healthy : PulseTheme.neutral)
                        .frame(width: 6, height: 6)
                    Text(monitor.isMonitoring ? "Monitoring Active" : "Paused")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.primaryText)
                    Spacer()
                }
                HStack {
                    Text(monitor.lastUpdate.map { PulseFormat.shortTimeFormatter.string(from: $0) } ?? "Initializing…")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PulseTheme.tertiaryText)
                    Spacer()
                    Text("v1.0.0")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PulseTheme.tertiaryText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(PulseTheme.sidebar)
    }

    private func sidebarRow(_ item: NavigationSection) -> some View {
        let isSelected = selection == item
        return Button {
            selection = item
        } label: {
            HStack(spacing: 9) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? PulseTheme.accent : PulseTheme.secondaryText)
                    .frame(width: 18)

                Text(item.title)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? PulseTheme.primaryText : PulseTheme.secondaryText)

                Spacer()

                if item == .insights && monitor.activeInsightsCount > 0 {
                    Text("\(monitor.activeInsightsCount)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PulseTheme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(PulseTheme.warning.opacity(0.15)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? PulseTheme.secondaryCard : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isSelected ? PulseTheme.hairline : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func detailView(for section: NavigationSection) -> some View {
        switch section {
        case .overview:
            OverviewView(selection: $selection)
        case .cpu:
            CPUDetailView()
        case .memory:
            MemoryDetailView()
        case .gpu:
            GPUDetailView()
        case .battery:
            BatteryDetailView()
        case .thermal:
            ThermalDetailView()
        case .processes:
            ProcessesView()
        case .storage:
            StorageDetailView()
        case .network:
            NetworkDetailView()
        case .history:
            PerformanceHistoryView()
        case .insights:
            InsightsView()
        case .settings:
            SettingsView()
        }
    }
}
