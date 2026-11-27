import Foundation
import Darwin

final class SystemIdentityMonitor: Sendable {
    func detect() -> SystemIdentity {
        let model = sysctlString("hw.model") ?? "Mac"
        let chip = sysctlString("machdep.cpu.brand_string") ?? detectAppleSiliconFallback()
        let osVer = ProcessInfo.processInfo.operatingSystemVersion
        let osString = "macOS \(osVer.majorVersion).\(osVer.minorVersion)\(osVer.patchVersion > 0 ? ".\(osVer.patchVersion)" : "")"

        var physMem: UInt64 = 0
        var memLen = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &physMem, &memLen, nil, 0) != 0 {
            physMem = ProcessInfo.processInfo.physicalMemory
        }

        let logicalCores = sysctlInt("hw.logicalcpu") ?? ProcessInfo.processInfo.processorCount
        let physicalCores = sysctlInt("hw.physicalcpu") ?? ProcessInfo.processInfo.activeProcessorCount

        return SystemIdentity(
            deviceModel: friendlyModelName(model),
            chipName: chip,
            osVersion: osString,
            hostName: ProcessInfo.processInfo.hostName,
            physicalMemoryBytes: physMem,
            logicalCoreCount: logicalCores,
            physicalCoreCount: physicalCores,
            uptimeSeconds: ProcessInfo.processInfo.systemUptime
        )
    }

    private func sysctlString(_ name: String) -> String? {
        var size: size_t = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let str = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
        return str.isEmpty ? nil : str
    }

    private func sysctlInt(_ name: String) -> Int? {
        var val: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &val, &size, nil, 0) == 0 else { return nil }
        return Int(val)
    }

    private func detectAppleSiliconFallback() -> String {
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Intel x86_64"
        #endif
    }

    private func friendlyModelName(_ identifier: String) -> String {
        if identifier.hasPrefix("MacBookPro") { return "MacBook Pro (\(identifier))" }
        if identifier.hasPrefix("MacBookAir") { return "MacBook Air (\(identifier))" }
        if identifier.hasPrefix("Macmini") { return "Mac mini (\(identifier))" }
        if identifier.hasPrefix("MacStudio") { return "Mac Studio (\(identifier))" }
        if identifier.hasPrefix("MacPro") { return "Mac Pro (\(identifier))" }
        if identifier.hasPrefix("iMac") { return "iMac (\(identifier))" }
        if identifier.hasPrefix("Mac") { return "Mac (\(identifier))" }
        return identifier
    }
}
