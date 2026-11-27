import Foundation
import Combine

@MainActor
final class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()

    // Identity & Status
    @Published private(set) var identity: SystemIdentity = .empty
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var lastUpdate: Date?
    @Published private(set) var snapshotCount: Int = 0

    // Current Metrics
    @Published private(set) var cpu: CPUMetrics = .unavailable
    @Published private(set) var memory: MemoryMetrics = .unavailable
    @Published private(set) var gpu: GPUMetrics = .unavailable
    @Published private(set) var battery: BatteryMetrics = .noBattery
    @Published private(set) var thermal: ThermalMetrics = .initial
    @Published private(set) var storage: StorageMetrics = .empty
    @Published private(set) var storageBreakdown: [StorageCategoryUsage] = []
    @Published private(set) var isScanningStorage: Bool = false
    @Published private(set) var network: NetworkMetrics = .empty
    @Published private(set) var processes: [ProcessInfoModel] = []
    @Published private(set) var memoryGrowthCandidates: [MemoryGrowthCandidate] = []

    // Rolling In-Memory Histories (up to 6 hours at ~2s/5s)
    @Published private(set) var cpuHistory: [CPUSample] = []
    @Published private(set) var memoryHistory: [MemorySample] = []
    @Published private(set) var gpuHistory: [GPUSample] = []
    @Published private(set) var batteryHistory: [BatterySample] = []
    @Published private(set) var thermalHistory: [ThermalSample] = []
    @Published private(set) var networkHistory: [NetworkSample] = []
    @Published private(set) var diskIOHistory: [DiskIOSample] = []

    // Insights
    @Published var insights: [InsightItem] = []

    private let identityMonitor = SystemIdentityMonitor()
    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let gpuMonitor = GPUMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let thermalMonitor = ThermalMonitor()
    private let storageMonitor = StorageMonitor()
    private let networkMonitor = NetworkMonitor()
    private let processMonitor = ProcessMonitor()
    private let anomalyDetector = AnomalyDetector()
    private let historyRepo = HistoryRepository()

    private var timerTask: Task<Void, Never>?
    private var tickCount: Int = 0
    private var lastSnapshotSave: Date = .distantPast
    private var lastBatteryCapacityLog: Date = .distantPast
    private var didAlertLowBattery: Bool = false
    private var didAlertMaxBattery: Bool = false
    private var thermalObserver: NSObjectProtocol?

    private init() {
        self.identity = identityMonitor.detect()
        observeThermalChanges()
    }

    func start() {
        guard timerTask == nil else { return }
        isMonitoring = true

        timerTask = Task { [weak self] in
            guard let self else { return }
            // Initial sample
            await self.performSampleCycle(forceAll: true)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { break }
                await self.performSampleCycle(forceAll: false)
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        isMonitoring = false
    }

    func refreshNow() {
        Task {
            await performSampleCycle(forceAll: true)
        }
    }

    func scanStorageBreakdown() {
        guard !isScanningStorage else { return }
        isScanningStorage = true
        Task.detached(priority: .utility) {
            let breakdown = StorageMonitor.scanDirectoryBreakdown()
            await MainActor.run {
                self.storageBreakdown = breakdown
                self.isScanningStorage = false
            }
        }
    }

    func terminateProcess(_ process: ProcessInfoModel, force: Bool) -> Result<Void, ProcessControlError> {
        let res = processMonitor.terminate(pid: process.pid, force: force)
        if case .success = res {
            refreshNow()
        }
        return res
    }

    func acknowledgeInsight(_ id: String) {
        if let idx = insights.firstIndex(where: { $0.id == id }) {
            insights[idx].isAcknowledged = true
        }
    }

    func dismissInsight(_ id: String) {
        if let idx = insights.firstIndex(where: { $0.id == id }) {
            insights[idx].isDismissed = true
        }
    }

    func clearHistory() async {
        await historyRepo.clearAll()
        snapshotCount = (try? await DatabaseManager.shared.snapshotCount()) ?? 0
    }

    private func observeThermalChanges() {
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.thermal = self.thermalMonitor.sample()
            }
        }
    }

    private func performSampleCycle(forceAll: Bool) async {
        tickCount += 1
        let settings = PulseSettings.shared
        let now = Date()

        let doCPU = settings.monitorCPU && (forceAll || tickCount % max(1, Int(settings.cpuInterval / 2.0)) == 0)
        let doMem = settings.monitorMemory && (forceAll || tickCount % max(1, Int(settings.memoryInterval / 2.0)) == 0)
        let doNet = settings.monitorNetwork && (forceAll || tickCount % max(1, Int(settings.networkInterval / 2.0)) == 0)
        let doBat = settings.monitorBattery && (forceAll || tickCount % max(1, Int(settings.batteryInterval / 2.0)) == 0)
        let doGPU = settings.monitorGPU && (forceAll || tickCount % 2 == 0)
        let doThermal = settings.monitorThermal
        let doStorage = settings.monitorStorage
        let doProcs = settings.monitorProcesses && (forceAll || tickCount % 2 == 0)

        let physMem = identity.physicalMemoryBytes

        let cpuMon = self.cpuMonitor
        let memMon = self.memoryMonitor
        let gpuMon = self.gpuMonitor
        let batMon = self.batteryMonitor
        let thermMon = self.thermalMonitor
        let storMon = self.storageMonitor
        let netMon = self.networkMonitor
        let procMon = self.processMonitor
        let idMon = self.identityMonitor

        // Run all system calls off the main thread
        let collected = await Task.detached(priority: .utility) {
            let newIdentity = idMon.detect()
            let newCPU = doCPU ? cpuMon.sample() : nil
            let newMem = doMem ? memMon.sample() : nil
            let newGPU = doGPU ? gpuMon.sample() : nil
            let newBat = doBat ? batMon.sample() : nil
            let newThermal = doThermal ? thermMon.sample() : nil
            let newStorage = doStorage ? storMon.sample() : nil
            let newNet = doNet ? netMon.sample() : nil
            let newProcs = doProcs ? procMon.sample(totalPhysicalMemory: physMem) : nil
            return (newIdentity, newCPU, newMem, newGPU, newBat, newThermal, newStorage, newNet, newProcs)
        }.value

        self.identity = collected.0
        if let c = collected.1 {
            self.cpu = c
            if c.isAvailable {
                cpuHistory.append(CPUSample(timestamp: c.timestamp, total: c.totalUsage, user: c.userUsage, system: c.systemUsage, idle: c.idleUsage))
                trimHistory(&cpuHistory, maxAge: 6 * 3600)
            }
        }
        if let m = collected.2 {
            self.memory = m
            if m.isAvailable {
                memoryHistory.append(MemorySample(timestamp: m.timestamp, usedBytes: m.usedBytes, compressedBytes: m.compressedBytes, swapUsedBytes: m.swapUsedBytes, pressureLevel: m.pressureLevel))
                trimHistory(&memoryHistory, maxAge: 6 * 3600)
            }
        }
        if let g = collected.3 {
            self.gpu = g
            if let primary = g.primaryDevice, let util = primary.utilizationPercent {
                gpuHistory.append(GPUSample(
                    timestamp: g.timestamp,
                    utilizationPercent: util,
                    inUseMemoryBytes: primary.inUseSystemMemoryBytes ?? 0
                ))
                trimHistory(&gpuHistory, maxAge: 6 * 3600)
            }
        }
        if let b = collected.4 {
            self.battery = b
            if b.hasBattery {
                batteryHistory.append(BatterySample(timestamp: b.timestamp, percentage: b.percentage, isCharging: b.isCharging, externalConnected: b.externalConnected))
                trimHistory(&batteryHistory, maxAge: 6 * 3600)

                if let maxCap = b.maxCapacityPercent, now.timeIntervalSince(lastBatteryCapacityLog) >= 3600 {
                    lastBatteryCapacityLog = now
                    try? await DatabaseManager.shared.logBatteryCapacity(maxCapacityPercent: maxCap, cycleCount: b.cycleCount)
                }
            }
        }
        if let t = collected.5 {
            self.thermal = t
            thermalHistory.append(ThermalSample(timestamp: t.timestamp, state: t.state, cpuUsageAtTime: self.cpu.totalUsage))
            trimHistory(&thermalHistory, maxAge: 6 * 3600)
        }
        if let s = collected.6 {
            self.storage = s
            diskIOHistory.append(DiskIOSample(timestamp: s.timestamp, readBytesPerSec: s.diskReadBytesPerSec, writeBytesPerSec: s.diskWriteBytesPerSec))
            trimHistory(&diskIOHistory, maxAge: 6 * 3600)
        }
        if let n = collected.7 {
            self.network = n
            networkHistory.append(NetworkSample(timestamp: n.timestamp, downloadBytesPerSec: n.downloadBytesPerSec, uploadBytesPerSec: n.uploadBytesPerSec))
            trimHistory(&networkHistory, maxAge: 6 * 3600)
        }
        if let p = collected.8 {
            self.processes = p.processes
            self.memoryGrowthCandidates = p.growthCandidates
        }

        self.lastUpdate = now

        // Evaluate Insights
        let ctx = AnomalyDetector.Context(
            cpu: self.cpu,
            memory: self.memory,
            battery: self.battery,
            thermal: self.thermal,
            storage: self.storage,
            network: self.network,
            processes: self.processes,
            growthCandidates: self.memoryGrowthCandidates,
            cpuHistory: self.cpuHistory,
            batteryHistory: self.batteryHistory,
            now: now
        )
        let generated = anomalyDetector.evaluate(ctx, existingInsights: self.insights)
        if !generated.isEmpty {
            self.insights.insert(contentsOf: generated, at: 0)
            if self.insights.count > 100 {
                self.insights.removeLast(self.insights.count - 100)
            }
        }

        // Dispatch macOS notifications if configured
        evaluateNotifications(settings: settings)

        // Persist historical snapshot every 10 seconds
        if settings.historyCollectionEnabled && now.timeIntervalSince(lastSnapshotSave) >= 10 {
            lastSnapshotSave = now
            let snapshot = MetricSnapshot(
                id: 0,
                timestamp: now,
                cpuTotal: self.cpu.totalUsage,
                cpuUser: self.cpu.userUsage,
                cpuSystem: self.cpu.systemUsage,
                memoryUsedBytes: self.memory.usedBytes,
                memoryPhysicalBytes: self.memory.physicalBytes,
                memoryPressureLevel: pressureToInt(self.memory.pressureLevel),
                swapUsedBytes: self.memory.swapUsedBytes,
                batteryPercent: self.battery.hasBattery ? self.battery.percentage : nil,
                isCharging: self.battery.hasBattery ? self.battery.isCharging : nil,
                thermalLevel: self.thermal.state.numericLevel,
                networkDownBps: self.network.downloadBytesPerSec,
                networkUpBps: self.network.uploadBytesPerSec
            )
            await historyRepo.recordSnapshot(snapshot)
            if tickCount % 30 == 0 {
                await historyRepo.prune(retentionDays: settings.retentionDays)
            }
            snapshotCount = (try? await DatabaseManager.shared.snapshotCount()) ?? snapshotCount
        }
    }

    private func evaluateNotifications(settings: PulseSettings) {
        if settings.notifyHighCPU && cpu.isAvailable && cpu.totalUsage >= settings.highCPUThreshold {
            NotificationsManager.shared.sendIfAllowed(
                key: "high_cpu",
                title: "High CPU Usage",
                body: "CPU utilization is at \(PulseFormat.percent(cpu.totalUsage, decimals: 0))."
            )
        }
        if settings.notifyHighMemoryPressure && (memory.pressureLevel == .warning || memory.pressureLevel == .critical) {
            NotificationsManager.shared.sendIfAllowed(
                key: "memory_pressure",
                title: "Memory Pressure \(memory.pressureLevel.rawValue)",
                body: "Used memory: \(PulseFormat.bytes(memory.usedBytes)) / \(PulseFormat.bytes(memory.physicalBytes))."
            )
        }
        if settings.notifyThermalWarning && (thermal.state == .serious || thermal.state == .critical) {
            NotificationsManager.shared.sendIfAllowed(
                key: "thermal_warning",
                title: "Thermal State: \(thermal.state.rawValue)",
                body: thermal.state.summaryDescription
            )
        }
        if settings.notifyLowStorage, let primary = storage.primaryVolume, primary.availablePercentage < settings.lowStorageThresholdPercent {
            NotificationsManager.shared.sendIfAllowed(
                key: "low_storage",
                title: "Low Disk Space on \(primary.name)",
                body: "Only \(PulseFormat.decimalBytes(primary.availableBytes)) remaining."
            )
        }
        if battery.hasBattery {
            if !battery.externalConnected && battery.percentage <= settings.lowBatteryThreshold {
                if settings.notifyLowBattery && !didAlertLowBattery {
                    didAlertLowBattery = true
                    NotificationsManager.shared.sendIfAllowed(
                        key: "low_battery",
                        title: "Low Battery (\(PulseFormat.percent(battery.percentage)))",
                        body: "Battery reached \(Int(settings.lowBatteryThreshold))% minimum threshold. Connect your Mac to power.",
                        soundName: "low",
                        bypassCooldown: true
                    )
                }
            } else if battery.externalConnected || battery.percentage >= settings.lowBatteryThreshold + 3 {
                didAlertLowBattery = false
            }

            if battery.externalConnected && (battery.isCharging || battery.isCharged) && battery.percentage >= settings.maxBatteryThreshold {
                if settings.notifyMaxBattery && !didAlertMaxBattery {
                    didAlertMaxBattery = true
                    NotificationsManager.shared.sendIfAllowed(
                        key: "max_battery",
                        title: "Max Battery Reached (\(PulseFormat.percent(battery.percentage)))",
                        body: "Battery reached \(Int(settings.maxBatteryThreshold))% target. You can unplug your charger.",
                        soundName: "max",
                        bypassCooldown: true
                    )
                }
            } else if !battery.externalConnected || battery.percentage <= settings.maxBatteryThreshold - 3 {
                didAlertMaxBattery = false
            }
        }
    }

    private func pressureToInt(_ level: MemoryPressureLevel) -> Int {
        switch level {
        case .normal: return 0
        case .warning: return 1
        case .critical: return 2
        case .unknown: return -1
        }
    }

    private func trimHistory<T>(_ array: inout [T], maxAge: TimeInterval) {
        // Keep at most 10,800 samples (6h at 2s)
        if array.count > 10800 {
            array.removeFirst(array.count - 10800)
        }
    }

    var topCPUProcesses: [ProcessInfoModel] {
        processes.sorted { $0.cpuPercent > $1.cpuPercent }
    }

    var topMemoryProcesses: [ProcessInfoModel] {
        processes.sorted { $0.memoryBytes > $1.memoryBytes }
    }

    var activeInsightsCount: Int {
        insights.filter { !$0.isDismissed && !$0.isAcknowledged }.count
    }
}
