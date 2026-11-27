import Foundation
import Metal
import IOKit

final class GPUMonitor: Sendable {
    func sample() -> GPUMetrics {
        let metalDevices = MTLCopyAllDevices()
        guard !metalDevices.isEmpty else {
            return .unavailable
        }

        let acceleratorStats = readIOAcceleratorStats()

        let summaries: [GPUDeviceSummary] = metalDevices.enumerated().map { index, device in
            let family = detectGPUFamily(device)
            let stats = index < acceleratorStats.count ? acceleratorStats[index] : acceleratorStats.first

            let util = stats?.utilizationPercent
            let inUseMem = stats?.inUseMemoryBytes
            let note: String
            if util != nil {
                note = "Metal device capabilities & IOKit PerformanceStatistics active."
            } else {
                note = "Metal device capabilities available. Live GPU utilization % is not exposed by this driver via public APIs."
            }

            return GPUDeviceSummary(
                id: device.registryID,
                name: device.name,
                familyDescription: family,
                hasUnifiedMemory: device.hasUnifiedMemory,
                isLowPower: device.isLowPower,
                isHeadless: device.isHeadless,
                recommendedMaxWorkingSetBytes: device.recommendedMaxWorkingSetSize,
                currentAllocatedBytes: UInt64(max(0, device.currentAllocatedSize)),
                maxBufferLengthBytes: UInt64(max(0, device.maxBufferLength)),
                utilizationPercent: util,
                inUseSystemMemoryBytes: inUseMem,
                driverStatusNote: note
            )
        }

        return GPUMetrics(timestamp: Date(), devices: summaries, isAvailable: true)
    }

    private func detectGPUFamily(_ device: MTLDevice) -> String {
        if device.supportsFamily(.apple9) { return "Apple GPU Family 9" }
        if device.supportsFamily(.apple8) { return "Apple GPU Family 8" }
        if device.supportsFamily(.apple7) { return "Apple GPU Family 7" }
        if device.supportsFamily(.apple6) { return "Apple GPU Family 6" }
        if device.supportsFamily(.mac2) { return "Mac GPU Family 2" }
        if device.supportsFamily(.common3) { return "Common GPU Family 3" }
        return "Metal GPU"
    }

    private struct AcceleratorStats {
        let utilizationPercent: Double?
        let inUseMemoryBytes: UInt64?
    }

    private func readIOAcceleratorStats() -> [AcceleratorStats] {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOAccelerator") else { return [] }
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var results: [AcceleratorStats] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var propsRef: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = propsRef?.takeRetainedValue() as? [String: Any],
               let perf = props["PerformanceStatistics"] as? [String: Any] {
                let utilNum = (perf["Device Utilization %"] as? NSNumber)?.doubleValue
                    ?? (perf["GPU Activity(%)"] as? NSNumber)?.doubleValue
                let memNum = (perf["In use system memory"] as? NSNumber)?.uint64Value
                    ?? (perf["Alloc system memory"] as? NSNumber)?.uint64Value
                results.append(AcceleratorStats(utilizationPercent: utilNum, inUseMemoryBytes: memNum))
            }
        }
        return results
    }
}
