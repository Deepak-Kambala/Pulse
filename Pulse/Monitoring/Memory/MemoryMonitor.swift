import Foundation
import Darwin

final class MemoryMonitor: Sendable {
    func sample() -> MemoryMetrics {
        let physicalBytes = readPhysicalMemory()
        let pageSize = UInt64(vm_kernel_page_size)

        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let kr = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard kr == KERN_SUCCESS else {
            return .unavailable
        }

        // Avoid double-counting:
        // App memory = internal pages minus purgeable pages (anonymous app allocations)
        // Wired memory = kernel/non-pageable memory
        // Compressed memory = compressor pool pages
        // Cached files = external (file-backed) + purgeable pages
        let wiredBytes = UInt64(vmStats.wire_count) * pageSize
        let compressedBytes = UInt64(vmStats.compressor_page_count) * pageSize
        let internalMinusPurgeable = max(0, Int64(vmStats.internal_page_count) - Int64(vmStats.purgeable_count))
        let appBytes = UInt64(internalMinusPurgeable) * pageSize
        let cachedFilesBytes = UInt64(vmStats.external_page_count + vmStats.purgeable_count) * pageSize

        let usedBytes = min(physicalBytes, appBytes + wiredBytes + compressedBytes)
        let availableBytes = physicalBytes > usedBytes ? physicalBytes - usedBytes : 0

        let swap = readSwapUsage()
        let pressure = readMemoryPressureLevel()

        return MemoryMetrics(
            timestamp: Date(),
            physicalBytes: physicalBytes,
            usedBytes: usedBytes,
            availableBytes: availableBytes,
            appBytes: appBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes,
            cachedFilesBytes: cachedFilesBytes,
            swapUsedBytes: swap.used,
            swapTotalBytes: swap.total,
            pressureLevel: pressure,
            isAvailable: true
        )
    }

    private func readPhysicalMemory() -> UInt64 {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &size, &len, nil, 0) == 0 {
            return size
        }
        return ProcessInfo.processInfo.physicalMemory
    }

    private func readSwapUsage() -> (used: UInt64, total: UInt64) {
        var swap = xsw_usage()
        var len = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &len, nil, 0) == 0 {
            return (UInt64(swap.xsu_used), UInt64(swap.xsu_total))
        }
        return (0, 0)
    }

    private func readMemoryPressureLevel() -> MemoryPressureLevel {
        var level: Int32 = 0
        var len = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &len, nil, 0) == 0 {
            switch level {
            case 1: return .normal
            case 2: return .warning
            case 4: return .critical
            default: return .normal
            }
        }
        return .unknown
    }
}
