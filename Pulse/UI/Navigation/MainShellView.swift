import SwiftUI

struct MainShellView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var settings: PulseSettings
    @Binding var selection: NavigationSection

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 205, ideal: 220, max: 240)
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
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Sample all system monitors now")
            }
        }
        .preferredColorScheme(settings.appearance.colorScheme)
        .frame(minWidth: 1000, minHeight: 680)
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Brand header
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PulseTheme.accent, PulseTheme.secondaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(PulseTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(PulseTheme.border, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("Pulse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PulseTheme.primaryText)
                    Text("Understand your Mac.")
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)

            List(selection: $selection) {
                ForEach(NavigationGroup.allCases, id: \.self) { group in
                    Section(group.rawValue) {
                        ForEach(NavigationSection.allCases.filter { $0.group == group }) { item in
                            HStack {
                                Label(item.title, systemImage: item.systemImage)
                                    .font(.system(size: 13))
                                Spacer()
                                if item == .insights && monitor.activeInsightsCount > 0 {
                                    Text("\(monitor.activeInsightsCount)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(PulseTheme.warning))
                                }
                            }
                            .tag(item)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider()
                .overlay(PulseTheme.border)

            // Sidebar footer
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(monitor.isMonitoring ? PulseTheme.healthy : PulseTheme.neutral)
                        .frame(width: 7, height: 7)
                    Text(monitor.isMonitoring ? "Monitoring Active" : "Paused")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.primaryText)
                    Spacer()
                }
                HStack {
                    Text(monitor.lastUpdate.map { "Updated \(PulseFormat.shortTimeFormatter.string(from: $0))" } ?? "Initializing…")
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Spacer()
                    Text("v1.0.0")
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(PulseTheme.sidebar)
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
