import SwiftUI
import AppKit

enum ProcessFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case user = "User"
    case system = "System"
    case highCPU = "High CPU"
    case highMemory = "High Memory"
    case active = "Active"

    var id: String { rawValue }
}

struct ProcessesView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @State private var searchText: String = ""
    @State private var filter: ProcessFilter = .all
    @State private var sortOrder = [KeyPathComparator(\ProcessInfoModel.cpuPercent, order: .reverse)]
    @State private var selectedPID: Int32?

    @State private var pendingTerminate: (process: ProcessInfoModel, force: Bool)?
    @State private var errorMessage: String?

    private var currentUsername: String { NSUserName() }

    private var activeCount: Int {
        monitor.processes.filter { $0.state == .running }.count
    }

    private var filteredProcesses: [ProcessInfoModel] {
        var list = monitor.processes

        switch filter {
        case .all:
            break
        case .user:
            list = list.filter { $0.user == currentUsername }
        case .system:
            list = list.filter { $0.user == "root" || $0.user.hasPrefix("_") }
        case .highCPU:
            list = list.filter { $0.cpuPercent >= 10.0 }
        case .highMemory:
            list = list.filter { $0.memoryBytes >= 256 * 1024 * 1024 }
        case .active:
            list = list.filter { $0.state == .running }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(q) ||
                String($0.pid).contains(q) ||
                $0.user.lowercased().contains(q)
            }
        }

        return list.sorted(using: sortOrder)
    }

    private var selectedProcess: ProcessInfoModel? {
        guard let selectedPID else { return nil }
        return monitor.processes.first(where: { $0.pid == selectedPID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Processes",
                subtitle: "\(filteredProcesses.count) of \(monitor.processes.count) processes"
            )

            MetricStrip(items: [
                MetricStripItem(label: "Total", value: "\(monitor.processes.count)"),
                MetricStripItem(label: "Active (≥0.5%)", value: "\(activeCount)"),
                MetricStripItem(
                    label: "Highest CPU",
                    value: monitor.topCPUProcesses.first.map { PulseFormat.percent($0.cpuPercent, decimals: 1) } ?? "—",
                    detail: monitor.topCPUProcesses.first?.name
                ),
                MetricStripItem(
                    label: "Highest Memory",
                    value: monitor.topMemoryProcesses.first.map { PulseFormat.bytes($0.memoryBytes) } ?? "—",
                    detail: monitor.topMemoryProcesses.first?.name
                )
            ])

            // Compact Filter Pills + Search Bar
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(ProcessFilter.allCases) { f in
                        let isSelected = filter == f
                        Button {
                            filter = f
                        } label: {
                            Text(f.rawValue)
                                .font(.system(size: 11.5, weight: isSelected ? .medium : .regular))
                                .foregroundStyle(isSelected ? PulseTheme.primaryText : PulseTheme.secondaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isSelected ? PulseTheme.secondaryCard : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(isSelected ? PulseTheme.hairline : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PulseTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(PulseTheme.hairline, lineWidth: 1)
                )

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.tertiaryText)
                    TextField("Search name, PID, user…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(PulseTheme.tertiaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 220)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PulseTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(PulseTheme.hairline, lineWidth: 1)
                )
            }

            // Main Table + Optional Inspector Split
            HSplitView {
                Table(filteredProcesses, selection: $selectedPID, sortOrder: $sortOrder) {
                    TableColumn("Process", value: \.name) { proc in
                        HStack(spacing: 8) {
                            ProcessIconView(pid: proc.pid, path: proc.executablePath)
                            Text(proc.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PulseTheme.primaryText)
                                .lineLimit(1)
                            if proc.isSystemCritical {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 10))
                                    .foregroundStyle(PulseTheme.tertiaryText)
                                    .help("Protected system process")
                            }
                        }
                    }
                    .width(min: 180, ideal: 260)

                    TableColumn("PID", value: \.pid) { proc in
                        Text(String(proc.pid))
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    .width(64)

                    TableColumn("PPID", value: \.ppid) { proc in
                        Text(String(proc.ppid))
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(PulseTheme.tertiaryText)
                    }
                    .width(64)

                    TableColumn("CPU %", value: \.cpuPercent) { proc in
                        Text(PulseFormat.percent(proc.cpuPercent, decimals: 1))
                            .font(.system(size: 12, weight: proc.cpuPercent >= 10 ? .semibold : .regular, design: .monospaced))
                            .foregroundStyle(cpuColor(proc.cpuPercent))
                    }
                    .width(74)

                    TableColumn("Memory", value: \.memoryBytes) { proc in
                        Text(PulseFormat.bytes(proc.memoryBytes))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(PulseTheme.primaryText)
                    }
                    .width(88)

                    TableColumn("User", value: \.user) { proc in
                        Text(proc.user)
                            .font(.system(size: 11.5))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(1)
                    }
                    .width(96)

                    TableColumn("State", value: \.state.rawValue) { proc in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(proc.state == .running ? PulseTheme.accent : PulseTheme.tertiaryText.opacity(0.6))
                                .frame(width: 5, height: 5)
                            Text(proc.state == .running ? "Active" : proc.state.rawValue)
                                .font(.system(size: 11.5))
                                .foregroundStyle(proc.state == .running ? PulseTheme.primaryText : PulseTheme.tertiaryText)
                        }
                    }
                    .width(76)
                }
                .alternatingRowBackgrounds(.disabled)
                .contextMenu(forSelectionType: Int32.self) { items in
                    if let pid = items.first, let proc = monitor.processes.first(where: { $0.pid == pid }) {
                        Button("Inspect Details") { selectedPID = pid }
                        Divider()
                        Button("Terminate (SIGTERM)") {
                            pendingTerminate = (proc, false)
                        }
                        .disabled(proc.isSystemCritical)
                        Button("Force Terminate (SIGKILL)", role: .destructive) {
                            pendingTerminate = (proc, true)
                        }
                        .disabled(proc.isSystemCritical)
                    }
                }
                .frame(minWidth: 520, maxHeight: .infinity)

                if let proc = selectedProcess {
                    processInspector(proc)
                        .frame(minWidth: 270, idealWidth: 300, maxWidth: 340)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(PulseTheme.hairline, lineWidth: 1))
        }
        .padding(22)
        .background(PulseTheme.background)
        .alert(
            pendingTerminate?.force == true ? "Force Terminate Process?" : "Terminate Process?",
            isPresented: Binding(
                get: { pendingTerminate != nil },
                set: { if !$0 { pendingTerminate = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { pendingTerminate = nil }
            Button(pendingTerminate?.force == true ? "Force Terminate" : "Terminate", role: .destructive) {
                if let target = pendingTerminate {
                    let res = monitor.terminateProcess(target.process, force: target.force)
                    if case .failure(let err) = res {
                        errorMessage = err.localizedDescription
                    }
                }
                pendingTerminate = nil
            }
        } message: {
            if let target = pendingTerminate {
                Text("Are you sure you want to \(target.force ? "force terminate (SIGKILL)" : "terminate (SIGTERM)") \(target.process.name) (PID \(String(target.process.pid)))?")
            }
        }
        .alert("Process Action Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func cpuColor(_ cpu: Double) -> Color {
        if cpu >= 50 { return PulseTheme.warning }
        if cpu >= 10 { return PulseTheme.accent }
        return PulseTheme.secondaryText
    }

    private func processInspector(_ proc: ProcessInfoModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ProcessIconView(pid: proc.pid, path: proc.executablePath)
                    Text(proc.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PulseTheme.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        selectedPID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PulseTheme.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }

                Rectangle().fill(PulseTheme.hairline).frame(height: 1)
                KeyValueRow(key: "PID", value: String(proc.pid))
                KeyValueRow(key: "Parent PID", value: String(proc.ppid))
                KeyValueRow(key: "User", value: proc.user)
                KeyValueRow(key: "State", value: proc.state == .running ? "Active" : proc.state.rawValue)
                KeyValueRow(key: "CPU Usage", value: PulseFormat.percent(proc.cpuPercent, decimals: 1))
                KeyValueRow(key: "Memory", value: PulseFormat.bytes(proc.memoryBytes))
                KeyValueRow(key: "Memory Share", value: PulseFormat.percent(proc.memoryPercent, decimals: 2))
                if let start = proc.startTime {
                    KeyValueRow(key: "Started", value: PulseFormat.timestampFormatter.string(from: start))
                }

                if let path = proc.executablePath {
                    Rectangle().fill(PulseTheme.hairline).frame(height: 1)
                    Text("EXECUTABLE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(PulseTheme.tertiaryText)
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .textSelection(.enabled)
                }

                if let cmd = proc.commandLine {
                    Rectangle().fill(PulseTheme.hairline).frame(height: 1)
                    Text("COMMAND LINE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(PulseTheme.tertiaryText)
                    Text(cmd)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .textSelection(.enabled)
                }

                Rectangle().fill(PulseTheme.hairline).frame(height: 1)
                if proc.isSystemCritical {
                    Label("Protected system process", systemImage: "lock.shield.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.tertiaryText)
                } else {
                    HStack(spacing: 8) {
                        Button("Terminate") {
                            pendingTerminate = (proc, false)
                        }
                        .buttonStyle(.bordered)
                        Button("Force Quit") {
                            pendingTerminate = (proc, true)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PulseTheme.critical)
                    }
                }
            }
            .padding(14)
        }
        .background(PulseTheme.card)
    }
}

private struct ProcessIconView: View {
    let pid: Int32
    let path: String?

    var body: some View {
        if let icon = NSRunningApplication(processIdentifier: pid)?.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: path?.contains(".app/") == true ? "app.dashed" : "terminal")
                .font(.system(size: 11))
                .foregroundStyle(PulseTheme.tertiaryText)
                .frame(width: 16, height: 16)
        }
    }
}
