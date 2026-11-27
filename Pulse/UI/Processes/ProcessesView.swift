import SwiftUI

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
            list = list.filter { $0.state == .running || $0.cpuPercent >= 1.0 }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(q) ||
                "\($0.pid)".contains(q) ||
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
                subtitle: "Real-time process inspection via libproc & proc_pidinfo"
            ) {
                HStack(spacing: 8) {
                    TextField("Search name, PID, user…", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 210)
                    Button {
                        monitor.refreshNow()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh process list")
                }
            }

            // Unified Metric Strip
            MetricStrip(items: [
                MetricStripItem(label: "Total Processes", value: "\(monitor.processes.count)"),
                MetricStripItem(label: "Active / Running", value: "\(monitor.processes.filter { $0.state == .running || $0.cpuPercent >= 0.5 }.count)"),
                MetricStripItem(label: "Highest CPU", value: monitor.topCPUProcesses.first.map { PulseFormat.percent($0.cpuPercent, decimals: 1) } ?? "—", detail: monitor.topCPUProcesses.first?.name),
                MetricStripItem(label: "Highest Memory", value: monitor.topMemoryProcesses.first.map { PulseFormat.bytes($0.memoryBytes) } ?? "—", detail: monitor.topMemoryProcesses.first?.name)
            ])

            // Filter Bar
            Picker("Filter", selection: $filter) {
                ForEach(ProcessFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)

            // Main Table + Inspector Split
            HSplitView {
                Table(filteredProcesses, selection: $selectedPID, sortOrder: $sortOrder) {
                    TableColumn("Process", value: \.name) { proc in
                        HStack(spacing: 6) {
                            Text(proc.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            if proc.isSystemCritical {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 10))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .help("Critical system process")
                            }
                        }
                    }
                    .width(min: 140, ideal: 210)

                    TableColumn("PID", value: \.pid) { proc in
                        Text("\(proc.pid)").monospacedDigit()
                    }
                    .width(62)

                    TableColumn("PPID", value: \.ppid) { proc in
                        Text("\(proc.ppid)").monospacedDigit().foregroundStyle(PulseTheme.secondaryText)
                    }
                    .width(62)

                    TableColumn("CPU %", value: \.cpuPercent) { proc in
                        Text(PulseFormat.percent(proc.cpuPercent, decimals: 1))
                            .monospacedDigit()
                            .foregroundStyle(proc.cpuPercent >= 50 ? PulseTheme.warning : PulseTheme.primaryText)
                    }
                    .width(72)

                    TableColumn("Memory", value: \.memoryBytes) { proc in
                        Text(PulseFormat.bytes(proc.memoryBytes)).monospacedDigit()
                    }
                    .width(86)

                    TableColumn("User", value: \.user) { proc in
                        Text(proc.user).foregroundStyle(PulseTheme.secondaryText).lineLimit(1)
                    }
                    .width(84)

                    TableColumn("State", value: \.state.rawValue) { proc in
                        Text(proc.state.rawValue).foregroundStyle(PulseTheme.secondaryText)
                    }
                    .width(74)
                }
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
                .frame(minWidth: 520)

                if let proc = selectedProcess {
                    processInspector(proc)
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(PulseTheme.border, lineWidth: 1))
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
                Text("Are you sure you want to \(target.force ? "force terminate (SIGKILL)" : "terminate (SIGTERM)") \(target.process.name) (PID \(target.process.pid))?")
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

    private func processInspector(_ proc: ProcessInfoModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(proc.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PulseTheme.primaryText)
                    Spacer()
                    Button {
                        selectedPID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }

                Divider().overlay(PulseTheme.border)
                KeyValueRow(key: "PID", value: "\(proc.pid)")
                KeyValueRow(key: "Parent PID", value: "\(proc.ppid)")
                KeyValueRow(key: "User", value: proc.user)
                KeyValueRow(key: "State", value: proc.state.rawValue)
                KeyValueRow(key: "CPU Usage", value: PulseFormat.percent(proc.cpuPercent, decimals: 1))
                KeyValueRow(key: "Memory Footprint", value: PulseFormat.bytes(proc.memoryBytes))
                KeyValueRow(key: "Memory Share", value: PulseFormat.percent(proc.memoryPercent, decimals: 2))
                if let start = proc.startTime {
                    KeyValueRow(key: "Started", value: PulseFormat.timestampFormatter.string(from: start))
                }

                if let path = proc.executablePath {
                    Divider().overlay(PulseTheme.border)
                    Text("Executable Path")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(PulseTheme.primaryText)
                        .textSelection(.enabled)
                }

                if let cmd = proc.commandLine {
                    Divider().overlay(PulseTheme.border)
                    Text("Command Line")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Text(cmd)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .textSelection(.enabled)
                }

                Divider().overlay(PulseTheme.border)
                if proc.isSystemCritical {
                    Label("Protected system process", systemImage: "lock.shield.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.secondaryText)
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
