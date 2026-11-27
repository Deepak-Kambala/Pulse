import Foundation
import Darwin

final class CPUMonitor: @unchecked Sendable {
    private struct CoreTicks {
        let user: UInt32
        let system: UInt32
        let idle: UInt32
        let nice: UInt32
    }

    private var previousTicks: [CoreTicks] = []
    private let lock = NSLock()

    func sample() -> CPUMetrics {
        lock.lock()
        defer { lock.unlock() }

        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            return .unavailable
        }

        defer {
            let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }

        let coreCount = Int(numCPUs)
        var currentTicks: [CoreTicks] = []
        currentTicks.reserveCapacity(coreCount)

        for i in 0..<coreCount {
            let base = i * Int(CPU_STATE_MAX)
            let user = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_USER)])
            let system = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_NICE)])
            currentTicks.append(CoreTicks(user: user, system: system, idle: idle, nice: nice))
        }

        defer { previousTicks = currentTicks }

        guard previousTicks.count == currentTicks.count else {
            // First sample establishes baseline; return 0% until next delta.
            let zeroCores = (0..<coreCount).map {
                CPUCoreMetric(id: $0, totalUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 100)
            }
            return CPUMetrics(
                timestamp: Date(),
                totalUsage: 0,
                userUsage: 0,
                systemUsage: 0,
                idleUsage: 100,
                niceUsage: 0,
                logicalCoreCount: coreCount,
                cores: zeroCores,
                isAvailable: true
            )
        }

        var sumUser: UInt64 = 0
        var sumSystem: UInt64 = 0
        var sumIdle: UInt64 = 0
        var sumNice: UInt64 = 0
        var coreMetrics: [CPUCoreMetric] = []
        coreMetrics.reserveCapacity(coreCount)

        for i in 0..<coreCount {
            let cur = currentTicks[i]
            let prev = previousTicks[i]
            let dUser = UInt64(cur.user &- prev.user)
            let dSys = UInt64(cur.system &- prev.system)
            let dIdle = UInt64(cur.idle &- prev.idle)
            let dNice = UInt64(cur.nice &- prev.nice)

            sumUser += dUser
            sumSystem += dSys
            sumIdle += dIdle
            sumNice += dNice

            let total = Double(dUser + dSys + dIdle + dNice)
            if total > 0 {
                let userPct = (Double(dUser + dNice) / total) * 100.0
                let sysPct = (Double(dSys) / total) * 100.0
                let idlePct = (Double(dIdle) / total) * 100.0
                coreMetrics.append(CPUCoreMetric(
                    id: i,
                    totalUsage: min(100, userPct + sysPct),
                    userUsage: userPct,
                    systemUsage: sysPct,
                    idleUsage: idlePct
                ))
            } else {
                coreMetrics.append(CPUCoreMetric(id: i, totalUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 100))
            }
        }

        let grandTotal = Double(sumUser + sumSystem + sumIdle + sumNice)
        guard grandTotal > 0 else {
            return CPUMetrics(
                timestamp: Date(),
                totalUsage: 0,
                userUsage: 0,
                systemUsage: 0,
                idleUsage: 100,
                niceUsage: 0,
                logicalCoreCount: coreCount,
                cores: coreMetrics,
                isAvailable: true
            )
        }

        let userPct = (Double(sumUser) / grandTotal) * 100.0
        let nicePct = (Double(sumNice) / grandTotal) * 100.0
        let sysPct = (Double(sumSystem) / grandTotal) * 100.0
        let idlePct = (Double(sumIdle) / grandTotal) * 100.0
        let totalPct = min(100.0, max(0.0, userPct + nicePct + sysPct))

        return CPUMetrics(
            timestamp: Date(),
            totalUsage: totalPct,
            userUsage: userPct + nicePct,
            systemUsage: sysPct,
            idleUsage: idlePct,
            niceUsage: nicePct,
            logicalCoreCount: coreCount,
            cores: coreMetrics,
            isAvailable: true
        )
    }
}
