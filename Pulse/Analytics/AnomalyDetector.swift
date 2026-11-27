import Foundation

final class AnomalyDetector: @unchecked Sendable {
    private var highCPUStart: Date?
    private var sustainedThermalStart: Date?
    private var lastAlertDates: [String: Date] = [:]
    private let cooldown: TimeInterval = 300 // 5 minutes between identical rules

    struct Context {
        let cpu: CPUMetrics
        let memory: MemoryMetrics
        let battery: BatteryMetrics
        let thermal: ThermalMetrics
        let storage: StorageMetrics
        let network: NetworkMetrics
        let processes: [ProcessInfoModel]
        let growthCandidates: [MemoryGrowthCandidate]
        let cpuHistory: [CPUSample]
        let batteryHistory: [BatterySample]
        let now: Date
    }

    func evaluate(_ ctx: Context, existingInsights: [InsightItem]) -> [InsightItem] {
        var newInsights: [InsightItem] = []

        // 1. Sustained High CPU (> 80% for >= 3 minutes)
        if ctx.cpu.isAvailable && ctx.cpu.totalUsage >= 80.0 {
            if highCPUStart == nil { highCPUStart = ctx.now }
            if let start = highCPUStart, ctx.now.timeIntervalSince(start) >= 180 {
                let topProc = ctx.processes.max(by: { $0.cpuPercent < $1.cpuPercent })
                let ruleKey = "cpu.sustained.high"
                if canEmit(ruleKey: ruleKey, now: ctx.now, existing: existingInsights) {
                    var evidence = [
                        "Total CPU: \(PulseFormat.percent(ctx.cpu.totalUsage, decimals: 1))",
                        "User: \(PulseFormat.percent(ctx.cpu.userUsage, decimals: 1)), System: \(PulseFormat.percent(ctx.cpu.systemUsage, decimals: 1))",
                        "Duration: \(PulseFormat.duration(ctx.now.timeIntervalSince(start)))"
                    ]
                    if let topProc {
                        evidence.append("Top process: \(topProc.name) (PID \(topProc.pid), \(PulseFormat.percent(topProc.cpuPercent, decimals: 1)))")
                    }
                    newInsights.append(InsightItem(
                        id: UUID().uuidString,
                        ruleKey: ruleKey,
                        category: .cpu,
                        severity: ctx.cpu.totalUsage >= 92 ? .critical : .warning,
                        title: "Sustained high CPU utilization",
                        description: "CPU utilization has remained above 80% for \(PulseFormat.duration(ctx.now.timeIntervalSince(start))).",
                        detectedAt: ctx.now,
                        relatedProcessName: topProc?.name,
                        relatedProcessPID: topProc?.pid,
                        evidence: evidence,
                        suggestedAction: "Inspect top CPU-consuming processes in Process Explorer."
                    ))
                }
            }
        } else {
            highCPUStart = nil
        }

        // 2. Single Process High CPU Anomaly (>= 90% on a single process)
        if let hotProc = ctx.processes.first(where: { $0.cpuPercent >= 90.0 }) {
            let ruleKey = "cpu.process.\(hotProc.pid)"
            if canEmit(ruleKey: ruleKey, now: ctx.now, existing: existingInsights) {
                newInsights.append(InsightItem(
                    id: UUID().uuidString,
                    ruleKey: ruleKey,
                    category: .cpu,
                    severity: .warning,
                    title: "High CPU process detected",
                    description: "\(hotProc.name) is currently consuming \(PulseFormat.percent(hotProc.cpuPercent, decimals: 1)) CPU.",
                    detectedAt: ctx.now,
                    relatedProcessName: hotProc.name,
                    relatedProcessPID: hotProc.pid,
                    evidence: [
                        "Process: \(hotProc.name)",
                        "PID: \(hotProc.pid)",
                        "CPU: \(PulseFormat.percent(hotProc.cpuPercent, decimals: 1))",
                        "Memory: \(PulseFormat.bytes(hotProc.memoryBytes))"
                    ],
                    suggestedAction: "Verify whether \(hotProc.name) is performing expected work or has stalled."
                ))
            }
        }

        // 3. Memory Pressure Warning / Critical
        if ctx.memory.isAvailable && (ctx.memory.pressureLevel == .warning || ctx.memory.pressureLevel == .critical) {
            let ruleKey = "memory.pressure.\(ctx.memory.pressureLevel.rawValue)"
            if canEmit(ruleKey: ruleKey, now: ctx.now, existing: existingInsights) {
                let topMem = ctx.processes.max(by: { $0.memoryBytes < $1.memoryBytes })
                newInsights.append(InsightItem(
                    id: UUID().uuidString,
                    ruleKey: ruleKey,
                    category: .memory,
                    severity: ctx.memory.pressureLevel == .critical ? .critical : .warning,
                    title: "Elevated memory pressure (\(ctx.memory.pressureLevel.rawValue))",
                    description: "macOS reports \(ctx.memory.pressureLevel.rawValue.lowercased()) memory pressure with \(PulseFormat.bytes(ctx.memory.compressedBytes)) compressed and \(PulseFormat.bytes(ctx.memory.swapUsedBytes)) swap used.",
                    detectedAt: ctx.now,
                    relatedProcessName: topMem?.name,
                    relatedProcessPID: topMem?.pid,
                    evidence: [
                        "Used: \(PulseFormat.bytes(ctx.memory.usedBytes)) / \(PulseFormat.bytes(ctx.memory.physicalBytes))",
                        "Compressed: \(PulseFormat.bytes(ctx.memory.compressedBytes))",
                        "Swap Used: \(PulseFormat.bytes(ctx.memory.swapUsedBytes))"
                    ],
                    suggestedAction: "Close unused memory-heavy applications to relieve swap and compression overhead."
                ))
            }
        }

        // 4. Possible Memory Growth Anomaly
        if let candidate = ctx.growthCandidates.first {
            let ruleKey = "memory.growth.\(candidate.pid)"
            if canEmit(ruleKey: ruleKey, now: ctx.now, existing: existingInsights) {
                newInsights.append(InsightItem(
                    id: UUID().uuidString,
                    ruleKey: ruleKey,
                    category: .memory,
                    severity: .info,
                    title: "Sustained memory growth observed",
                    description: "\(candidate.name) increased its memory footprint by \(PulseFormat.bytes(candidate.netIncreaseBytes)) over \(PulseFormat.duration(candidate.observationDuration)).",
                    detectedAt: ctx.now,
                    relatedProcessName: candidate.name,
                    relatedProcessPID: candidate.pid,
                    evidence: [
                        "Starting footprint: \(PulseFormat.bytes(candidate.startingBytes))",
                        "Current footprint: \(PulseFormat.bytes(candidate.currentBytes))",
                        "Net increase: +\(PulseFormat.bytes(candidate.netIncreaseBytes))"
                    ],
                    suggestedAction: "Monitor this process in Memory > Memory Leak Watch; restart if growth continues."
                ))
            }
        }

        // 5. Thermal Pressure
        if ctx.thermal.state == .serious || ctx.thermal.state == .critical {
            if sustainedThermalStart == nil { sustainedThermalStart = ctx.now }
            let ruleKey = "thermal.\(ctx.thermal.state.rawValue)"
            if canEmit(ruleKey: ruleKey, now: ctx.now, existing: existingInsights) {
                newInsights.append(InsightItem(
                    id: UUID().uuidString,
                    ruleKey: ruleKey,
                    category: .thermal,
                    severity: ctx.thermal.state == .critical ? .critical : .warning,
                    title: "Thermal state is \(ctx.thermal.state.rawValue)",
                    description: ctx.thermal.state.summaryDescription,
                    detectedAt: ctx.now,
                    relatedProcessName: nil,
                    relatedProcessPID: nil,
                    evidence: [
                        "ProcessInfo.thermalState: \(ctx.thermal.state.rawValue)",
                        "Current CPU Load: \(PulseFormat.percent(ctx.cpu.totalUsage, decimals: 1))"
                    ],
                    suggestedAction: "Ensure vents are unobstructed and reduce sustained CPU/GPU workloads."
                ))
            }
        } else {
            sustainedThermalStart = nil
        }

        // 6. Low Storage (< 15% available on internal volume)
        if let primary = ctx.storage.primaryVolume, primary.availablePercentage < 15.0 {
            let ruleKey = "storage.low.\(primary.mountPoint)"
            if canEmit(ruleKey: ruleKey, now: ctx.now, existing: existingInsights) {
                newInsights.append(InsightItem(
                    id: UUID().uuidString,
                    ruleKey: ruleKey,
                    category: .storage,
                    severity: primary.availablePercentage < 10.0 ? .critical : .warning,
                    title: "Low available disk space on \(primary.name)",
                    description: "Only \(PulseFormat.decimalBytes(primary.availableBytes)) (\(PulseFormat.percent(primary.availablePercentage, decimals: 1))) remains available.",
                    detectedAt: ctx.now,
                    relatedProcessName: nil,
                    relatedProcessPID: nil,
                    evidence: [
                        "Volume: \(primary.name) (\(primary.mountPoint))",
                        "Available: \(PulseFormat.decimalBytes(primary.availableBytes))",
                        "Total: \(PulseFormat.decimalBytes(primary.totalBytes))"
                    ],
                    suggestedAction: "Free up disk space or move large media/archives to external storage."
                ))
            }
        }

        // 7. Battery Health / Low Battery
        if ctx.battery.hasBattery {
            if !ctx.battery.externalConnected && ctx.battery.percentage <= 15.0 {
                let ruleKey = "battery.low"
                if canEmit(ruleKey: ruleKey, now: ctx.now, existing: existingInsights) {
                    newInsights.append(InsightItem(
                        id: UUID().uuidString,
                        ruleKey: ruleKey,
                        category: .battery,
                        severity: .warning,
                        title: "Battery charge is low",
                        description: "Battery is at \(PulseFormat.percent(ctx.battery.percentage)) on battery power.",
                        detectedAt: ctx.now,
                        relatedProcessName: nil,
                        relatedProcessPID: nil,
                        evidence: [
                            "Charge: \(PulseFormat.percent(ctx.battery.percentage))",
                            "Power Source: \(ctx.battery.powerSource.rawValue)"
                        ],
                        suggestedAction: "Connect your Mac to power to avoid unexpected sleep or shutdown."
                    ))
                }
            }
            if let maxCap = ctx.battery.maxCapacityPercent, maxCap < 80.0 {
                let ruleKey = "battery.capacity.below80"
                if canEmit(ruleKey: ruleKey, now: ctx.now, existing: existingInsights) {
                    newInsights.append(InsightItem(
                        id: UUID().uuidString,
                        ruleKey: ruleKey,
                        category: .battery,
                        severity: .info,
                        title: "Battery maximum capacity below 80%",
                        description: "Reported maximum capacity is \(PulseFormat.percent(maxCap, decimals: 1)) with \(ctx.battery.cycleCount.map { "\($0) cycles" } ?? "unknown cycles").",
                        detectedAt: ctx.now,
                        relatedProcessName: nil,
                        relatedProcessPID: nil,
                        evidence: [
                            "Max Capacity: \(PulseFormat.percent(maxCap, decimals: 1))",
                            "Condition: \(ctx.battery.condition)"
                        ],
                        suggestedAction: "Review Battery page for historical capacity readings."
                    ))
                }
            }
        }

        return newInsights
    }

    private func canEmit(ruleKey: String, now: Date, existing: [InsightItem]) -> Bool {
        if existing.contains(where: { $0.ruleKey == ruleKey && !$0.isDismissed && now.timeIntervalSince($0.detectedAt) < cooldown }) {
            return false
        }
        if let last = lastAlertDates[ruleKey], now.timeIntervalSince(last) < cooldown {
            return false
        }
        lastAlertDates[ruleKey] = now
        return true
    }
}
