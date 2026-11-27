import Foundation
import IOKit
import IOKit.ps

final class BatteryMonitor: Sendable {
    func sample() -> BatteryMetrics {
        guard let psInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let psList = IOPSCopyPowerSourcesList(psInfo)?.takeRetainedValue() as? [CFTypeRef],
              !psList.isEmpty else {
            return .noBattery
        }

        // Find internal battery source
        var batteryDesc: [String: Any]?
        for ps in psList {
            if let desc = IOPSGetPowerSourceDescription(psInfo, ps)?.takeUnretainedValue() as? [String: Any] {
                let type = desc[kIOPSTypeKey] as? String
                if type == kIOPSInternalBatteryType || batteryDesc == nil {
                    batteryDesc = desc
                    if type == kIOPSInternalBatteryType { break }
                }
            }
        }

        guard let desc = batteryDesc else {
            return .noBattery
        }

        let currentCap = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let percentage = maxCap > 0 ? min(100.0, max(0.0, (Double(currentCap) / Double(maxCap)) * 100.0)) : 0.0

        let isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
        let isCharged = (desc[kIOPSIsChargedKey] as? Bool) ?? false
        let sourceStr = desc[kIOPSPowerSourceStateKey] as? String ?? ""
        let externalConnected = sourceStr == kIOPSACPowerValue

        let powerSource: PowerSource
        if sourceStr == kIOPSACPowerValue {
            powerSource = .ac
        } else if sourceStr == kIOPSBatteryPowerValue {
            powerSource = .battery
        } else {
            powerSource = .unknown
        }

        let condition = (desc[kIOPSBatteryHealthKey] as? String) ?? "Normal"
        let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int
        let timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int
        let rawTimeRemaining = isCharging ? timeToFull : timeToEmpty
        let validTimeRemaining: Int? = (rawTimeRemaining ?? -1) > 0 ? rawTimeRemaining : nil

        let smart = readSmartBatteryRegistry()
        let maxCapPercent: Double?
        if let rawMax = smart.rawMaxCapacityMah, let design = smart.designCapacityMah, design > 0 {
            maxCapPercent = min(100.0, (Double(rawMax) / Double(design)) * 100.0)
        } else {
            maxCapPercent = nil
        }

        return BatteryMetrics(
            timestamp: Date(),
            hasBattery: true,
            percentage: percentage,
            isCharging: isCharging,
            isCharged: isCharged,
            externalConnected: externalConnected,
            powerSource: powerSource,
            condition: condition,
            cycleCount: smart.cycleCount,
            maxCapacityPercent: maxCapPercent,
            currentCapacityMah: smart.currentCapacityMah,
            maxCapacityMah: smart.rawMaxCapacityMah,
            designCapacityMah: smart.designCapacityMah,
            timeRemainingMinutes: validTimeRemaining,
            temperatureCelsius: smart.temperatureCelsius,
            amperageMa: smart.amperageMa,
            voltageMv: smart.voltageMv
        )
    }

    private struct SmartBatteryDetails {
        var cycleCount: Int?
        var designCapacityMah: Int?
        var rawMaxCapacityMah: Int?
        var currentCapacityMah: Int?
        var temperatureCelsius: Double?
        var amperageMa: Int?
        var voltageMv: Int?
    }

    private func readSmartBatteryRegistry() -> SmartBatteryDetails {
        var details = SmartBatteryDetails()
        guard let matching = IOServiceMatching("AppleSmartBattery") else { return details }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return details }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = propsRef?.takeRetainedValue() as? [String: Any] else {
            return details
        }

        details.cycleCount = props["CycleCount"] as? Int
        details.designCapacityMah = props["DesignCapacity"] as? Int
        details.rawMaxCapacityMah = (props["AppleRawMaxCapacity"] as? Int) ?? (props["NominalChargeCapacity"] as? Int)
        details.currentCapacityMah = (props["AppleRawCurrentCapacity"] as? Int) ?? (props["CurrentCapacity"] as? Int)
        if let rawTemp = props["Temperature"] as? Int, rawTemp > 0 {
            // AppleSmartBattery reports temperature in 0.01 Kelvin
            let celsius = (Double(rawTemp) / 100.0) - 273.15
            if celsius > -20 && celsius < 120 {
                details.temperatureCelsius = celsius
            }
        }
        details.amperageMa = props["Amperage"] as? Int
        details.voltageMv = props["Voltage"] as? Int
        return details
    }
}
