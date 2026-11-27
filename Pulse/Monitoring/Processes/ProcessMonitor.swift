import Foundation
import Darwin

final class ProcessMonitor: @unchecked Sendable {
    private struct PreviousCPUSample {
        let totalNano: UInt64
        let timestamp: Date
    }

    private var previousCPU: [Int32: PreviousCPUSample] = [:]
    private var previousMemory: [Int32: UInt64] = [:]
    private var memoryHistory: [Int32: [(Date, UInt64)]] = [:]
    private let lock = NSLock()
    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private static let criticalProcessNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "loginwindow",
        "mds", "mds_stores", "UserEventAgent", "distnoted", "cfprefsd", "notifyd"
    ]

    func sample(totalPhysicalMemory: UInt64) -> (processes: [ProcessInfoModel], growthCandidates: [MemoryGrowthCandidate]) {
        lock.lock()
        defer { lock.unlock() }

        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount > 0 else { return ([], []) }

        let capacity = Int(estimatedCount) + 64
        var pids = [Int32](repeating: 0, count: capacity)
        let bytesWritten = proc_listallpids(&pids, Int32(capacity * MemoryLayout<Int32>.stride))
        let count = Int(bytesWritten) / MemoryLayout<Int32>.stride
        guard count > 0 else { return ([], []) }

        let now = Date()
        let selfPid = getpid()
        var activePIDs = Set<Int32>()
        var results: [ProcessInfoModel] = []
        results.reserveCapacity(count)

        for i in 0..<count {
            let pid = pids[i]
            if pid <= 0 { continue }
            activePIDs.insert(pid)

            var taskAll = proc_taskallinfo()
            let expectedSize = Int32(MemoryLayout<proc_taskallinfo>.stride)
            let ret = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &taskAll, expectedSize)
            guard ret == expectedSize else { continue }

            let rawName = withUnsafePointer(to: taskAll.pbsd.pbi_name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) * 2) {
                    String(cString: $0)
                }
            }
            let fallbackComm = withUnsafePointer(to: taskAll.pbsd.pbi_comm) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) {
                    String(cString: $0)
                }
            }
            let path = readPath(pid: pid)
            let pathName = path.map { URL(fileURLWithPath: $0).lastPathComponent }
            let baseName = rawName.isEmpty ? (fallbackComm.isEmpty ? "pid \(pid)" : fallbackComm) : rawName
            // pbi_name is capped at 31 chars on macOS; prefer full executable basename when truncated
            let rawProcessName: String
            if let pathName, !pathName.isEmpty, (rawName.count >= 30 || rawName.isEmpty) {
                rawProcessName = pathName
            } else {
                rawProcessName = baseName
            }
            let processName = Self.readableProcessName(rawProcessName)
            let uid = taskAll.pbsd.pbi_uid
            let userName = resolveUsername(uid: uid)
            let ppid = Int32(taskAll.pbsd.pbi_ppid)

            // Memory footprint (resident size)
            let memBytes = UInt64(taskAll.ptinfo.pti_resident_size)
            let memPct = totalPhysicalMemory > 0 ? (Double(memBytes) / Double(totalPhysicalMemory)) * 100.0 : 0.0

            // CPU % via Mach time delta
            let rawTime = taskAll.ptinfo.pti_total_user &+ taskAll.ptinfo.pti_total_system
            let totalNano = (rawTime &* UInt64(timebase.numer)) / UInt64(max(1, timebase.denom))

            var cpuPct = 0.0
            if let prev = previousCPU[pid] {
                let dtNano = now.timeIntervalSince(prev.timestamp) * 1_000_000_000.0
                if dtNano > 1_000_000 && totalNano >= prev.totalNano {
                    let deltaNano = Double(totalNano - prev.totalNano)
                    cpuPct = min(Double(ProcessInfo.processInfo.processorCount) * 100.0, (deltaNano / dtNano) * 100.0)
                }
            }
            previousCPU[pid] = PreviousCPUSample(totalNano: totalNano, timestamp: now)

            let prevMem = previousMemory[pid]
            let memDelta = prevMem.map { Int64(memBytes) - Int64($0) } ?? 0
            previousMemory[pid] = memBytes

            // Track memory history for leak/growth watch (keep up to 40 samples per PID)
            var hist = memoryHistory[pid] ?? []
            hist.append((now, memBytes))
            if hist.count > 40 {
                hist.removeFirst(hist.count - 40)
            }
            memoryHistory[pid] = hist

            let rawState = mapProcessState(taskAll.pbsd.pbi_status)
            let state: ProcessRunState = (rawState == .stopped || rawState == .zombie)
                ? rawState
                : (cpuPct >= 0.5 ? .running : .idle)
            let startTime: Date? = taskAll.pbsd.pbi_start_tvsec > 0
                ? Date(timeIntervalSince1970: TimeInterval(taskAll.pbsd.pbi_start_tvsec))
                : nil

            let isCritical = pid <= 1 || pid == selfPid || Self.criticalProcessNames.contains(processName)
            let cmdLine = readCommandLine(pid: pid)

            results.append(ProcessInfoModel(
                pid: pid,
                ppid: ppid,
                name: processName,
                executablePath: path,
                user: userName,
                uid: uid,
                cpuPercent: cpuPct,
                memoryBytes: memBytes,
                memoryPercent: memPct,
                state: state,
                startTime: startTime,
                commandLine: cmdLine,
                isSystemCritical: isCritical,
                memoryDeltaBytes: memDelta
            ))
        }

        // Clean up exited PIDs
        for oldPid in previousCPU.keys where !activePIDs.contains(oldPid) {
            previousCPU.removeValue(forKey: oldPid)
            previousMemory.removeValue(forKey: oldPid)
            memoryHistory.removeValue(forKey: oldPid)
        }

        let growthCandidates = detectMemoryGrowth(processes: results)
        return (results, growthCandidates)
    }

    private func detectMemoryGrowth(processes: [ProcessInfoModel]) -> [MemoryGrowthCandidate] {
        var candidates: [MemoryGrowthCandidate] = []
        for proc in processes {
            guard let hist = memoryHistory[proc.pid], hist.count >= 6 else { continue }
            guard let first = hist.first, let last = hist.last else { continue }
            let duration = last.0.timeIntervalSince(first.0)
            guard duration >= 20 else { continue }
            guard last.1 > first.1 else { continue }
            let netIncrease = last.1 - first.1
            // Require meaningful sustained growth (>= 25 MB and >= 10% increase, mostly non-decreasing steps)
            guard netIncrease >= 25 * 1024 * 1024, Double(netIncrease) / Double(max(1, first.1)) >= 0.10 else {
                continue
            }
            var increases = 0
            for idx in 1..<hist.count where hist[idx].1 >= hist[idx - 1].1 {
                increases += 1
            }
            if Double(increases) / Double(hist.count - 1) >= 0.70 {
                candidates.append(MemoryGrowthCandidate(
                    pid: proc.pid,
                    name: proc.name,
                    startingBytes: first.1,
                    currentBytes: last.1,
                    netIncreaseBytes: netIncrease,
                    observationDuration: duration
                ))
            }
        }
        return candidates.sorted { $0.netIncreaseBytes > $1.netIncreaseBytes }
    }

    func terminate(pid: Int32, force: Bool) -> Result<Void, ProcessControlError> {
        if pid <= 1 || pid == getpid() {
            return .failure(.protectedProcess)
        }
        let sig = force ? SIGKILL : SIGTERM
        if Darwin.kill(pid, sig) == 0 {
            return .success(())
        }
        switch errno {
        case EPERM: return .failure(.permissionDenied)
        case ESRCH: return .failure(.processNotFound)
        default: return .failure(.failed(String(cString: strerror(errno))))
        }
    }

    private static func readableProcessName(_ name: String) -> String {
        if name.hasPrefix("com.apple.") {
            let trimmed = String(name.dropFirst("com.apple.".count))
            return trimmed.replacingOccurrences(of: ".", with: " ")
        }
        return name
    }

    private func readPath(pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096) // PROC_PIDPATHINFO_MAXSIZE
        let ret = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard ret > 0 else { return nil }
        return String(cString: buffer)
    }

    private func resolveUsername(uid: UInt32) -> String {
        if let pw = getpwuid(uid) {
            return String(cString: pw.pointee.pw_name)
        }
        return "\(uid)"
    }

    private func mapProcessState(_ status: UInt32) -> ProcessRunState {
        // BSD process status values from sys/proc.h: SIDL=1, SRUN=2, SSLEEP=3, SSTOP=4, SZOMB=5
        switch status {
        case 1: return .idle
        case 2: return .running
        case 3: return .sleeping
        case 4: return .stopped
        case 5: return .zombie
        default: return .unknown
        }
    }

    private func readCommandLine(pid: Int32) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: size_t = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size, size < 65536 else {
            return nil
        }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        guard argc > 0 else { return nil }

        var idx = MemoryLayout<Int32>.size
        // Skip executable path
        while idx < size && buffer[idx] != 0 { idx += 1 }
        // Skip null padding
        while idx < size && buffer[idx] == 0 { idx += 1 }

        var args: [String] = []
        while idx < size && args.count < Int(argc) {
            let start = idx
            while idx < size && buffer[idx] != 0 { idx += 1 }
            if let arg = String(bytes: buffer[start..<idx], encoding: .utf8), !arg.isEmpty {
                args.append(arg)
            }
            idx += 1
        }
        return args.isEmpty ? nil : args.joined(separator: " ")
    }
}

enum ProcessControlError: LocalizedError {
    case protectedProcess
    case permissionDenied
    case processNotFound
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .protectedProcess:
            return "This critical system process is protected and cannot be terminated from Pulse."
        case .permissionDenied:
            return "Permission denied. You do not have privileges to signal this process."
        case .processNotFound:
            return "The process has already exited."
        case .failed(let msg):
            return "Failed to signal process: \(msg)"
        }
    }
}
