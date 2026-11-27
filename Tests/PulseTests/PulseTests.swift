import Foundation
import Testing
@testable import Pulse

@Suite("Pulse Core & Monitoring Tests")
struct PulseTests {
    @Test("CPUMonitor delta sampling produces valid percentages and core counts")
    func cpuMonitorDeltaSampling() {
        let monitor = CPUMonitor()
        let first = monitor.sample()
        #expect(first.isAvailable)
        #expect(first.logicalCoreCount > 0)

        Thread.sleep(forTimeInterval: 0.15)
        let second = monitor.sample()
        #expect(second.isAvailable)
        #expect(second.totalUsage >= 0.0)
        #expect(second.totalUsage <= 100.0)
        #expect(second.cores.count == second.logicalCoreCount)
    }

    @Test("MemoryMonitor avoids double-counting and preserves physical capacity invariant")
    func memoryMonitorNonDoubleCounting() {
        let monitor = MemoryMonitor()
        let mem = monitor.sample()
        #expect(mem.isAvailable)
        #expect(mem.physicalBytes > 0)
        #expect(mem.usedBytes <= mem.physicalBytes)
        #expect(mem.usedBytes + mem.availableBytes == mem.physicalBytes)
        #expect(mem.appBytes + mem.wiredBytes + mem.compressedBytes <= mem.physicalBytes)
    }

    @Test("StorageMonitor detects primary volume")
    func storageMonitorPrimaryVolume() {
        let monitor = StorageMonitor()
        let storage = monitor.sample()
        #expect(!storage.volumes.isEmpty)
        #expect(storage.primaryVolume != nil)
        if let root = storage.primaryVolume {
            #expect(root.totalBytes > 0)
            #expect(root.availableBytes <= root.totalBytes)
        }
    }

    @Test("NetworkMonitor enumerates interfaces")
    func networkMonitorInterfaces() {
        let monitor = NetworkMonitor()
        let net = monitor.sample()
        #expect(!net.interfaces.isEmpty)
    }

    @Test("DatabaseManager inserts, fetches, summarizes, and clears snapshots")
    func databaseManagerRoundTrip() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-test-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let db = DatabaseManager(customURL: tempURL)
        let now = Date()
        let s1 = MetricSnapshot(
            id: 0, timestamp: now.addingTimeInterval(-20),
            cpuTotal: 20, cpuUser: 15, cpuSystem: 5,
            memoryUsedBytes: 8_000_000_000, memoryPhysicalBytes: 16_000_000_000,
            memoryPressureLevel: 0, swapUsedBytes: 0,
            batteryPercent: 80, isCharging: false, thermalLevel: 0,
            networkDownBps: 1000, networkUpBps: 500
        )
        let s2 = MetricSnapshot(
            id: 0, timestamp: now,
            cpuTotal: 60, cpuUser: 45, cpuSystem: 15,
            memoryUsedBytes: 10_000_000_000, memoryPhysicalBytes: 16_000_000_000,
            memoryPressureLevel: 1, swapUsedBytes: 100_000,
            batteryPercent: 79, isCharging: false, thermalLevel: 1,
            networkDownBps: 2000, networkUpBps: 1000
        )

        try await db.insertSnapshot(s1)
        try await db.insertSnapshot(s2)

        let fetched = try await db.fetchSnapshots(since: now.addingTimeInterval(-60))
        #expect(fetched.count == 2)

        let summary = HistoryRepository.summarize(fetched.map { ($0.timestamp, $0.cpuTotal) })
        #expect(summary?.minimum == 20)
        #expect(summary?.peak == 60)
        #expect(summary?.average == 40)

        try await db.clearAllHistory()
        let countAfterClear = try await db.snapshotCount()
        #expect(countAfterClear == 0)
    }

    @Test("AnomalyDetector emits memory pressure insight and deduplicates within cooldown")
    func anomalyDetectorMemoryPressureAndDeduplication() {
        let detector = AnomalyDetector()
        let now = Date()
        let mem = MemoryMetrics(
            timestamp: now,
            physicalBytes: 16_000_000_000,
            usedBytes: 14_500_000_000,
            availableBytes: 1_500_000_000,
            appBytes: 10_000_000_000,
            wiredBytes: 2_500_000_000,
            compressedBytes: 2_000_000_000,
            cachedFilesBytes: 500_000_000,
            swapUsedBytes: 1_000_000_000,
            swapTotalBytes: 2_000_000_000,
            pressureLevel: .warning,
            isAvailable: true
        )
        let ctx = AnomalyDetector.Context(
            cpu: .unavailable,
            memory: mem,
            battery: .noBattery,
            thermal: .initial,
            storage: .empty,
            network: .empty,
            processes: [],
            growthCandidates: [],
            cpuHistory: [],
            batteryHistory: [],
            now: now
        )
        let first = detector.evaluate(ctx, existingInsights: [])
        #expect(first.contains(where: { $0.category == .memory }))

        let second = detector.evaluate(ctx, existingInsights: first)
        #expect(!second.contains(where: { $0.category == .memory }))
    }

    @Test("PulseFormat formats bytes, speeds, and uptime accurately")
    func formatters() {
        #expect(PulseFormat.bytes(1_073_741_824, decimals: 1) == "1.0 GB")
        #expect(PulseFormat.speed(1_048_576) == "1.0 MB/s")
        #expect(PulseFormat.uptime(3660) == "1h 1m")
    }
}
