import Foundation

enum DiagnosticExporter {
    static func generateMarkdownReport(
        identity: SystemIdentity,
        cpu: CPUMetrics,
        memory: MemoryMetrics,
        gpu: GPUMetrics,
        battery: BatteryMetrics,
        thermal: ThermalMetrics,
        storage: StorageMetrics,
        network: NetworkMetrics,
        topProcesses: [ProcessInfoModel],
        insights: [InsightItem],
        includeNetworkIPs: Bool
    ) -> String {
        var lines: [String] = []
        lines.append("# Pulse Diagnostic Report")
        lines.append("Generated: \(PulseFormat.timestampFormatter.string(from: Date()))")
        lines.append("")
        lines.append("## System")
        lines.append("- Model: \(identity.deviceModel)")
        lines.append("- Chip: \(identity.chipName)")
        lines.append("- OS: \(identity.osVersion)")
        lines.append("- Logical Cores: \(identity.logicalCoreCount)")
        lines.append("- Uptime: \(PulseFormat.uptime(identity.uptimeSeconds))")
        lines.append("")
        lines.append("## CPU")
        lines.append("- Total: \(PulseFormat.percent(cpu.totalUsage, decimals: 1))")
        lines.append("- User: \(PulseFormat.percent(cpu.userUsage, decimals: 1))")
        lines.append("- System: \(PulseFormat.percent(cpu.systemUsage, decimals: 1))")
        lines.append("- Idle: \(PulseFormat.percent(cpu.idleUsage, decimals: 1))")
        lines.append("")
        lines.append("## Memory")
        lines.append("- Physical: \(PulseFormat.bytes(memory.physicalBytes))")
        lines.append("- Used: \(PulseFormat.bytes(memory.usedBytes)) (\(PulseFormat.percent(memory.usedPercentage, decimals: 1)))")
        lines.append("- App: \(PulseFormat.bytes(memory.appBytes))")
        lines.append("- Wired: \(PulseFormat.bytes(memory.wiredBytes))")
        lines.append("- Compressed: \(PulseFormat.bytes(memory.compressedBytes))")
        lines.append("- Cached Files: \(PulseFormat.bytes(memory.cachedFilesBytes))")
        lines.append("- Swap Used: \(PulseFormat.bytes(memory.swapUsedBytes))")
        lines.append("- Memory Pressure: \(memory.pressureLevel.rawValue)")
        lines.append("")
        lines.append("## GPU")
        if let primary = gpu.primaryDevice {
            lines.append("- Device: \(primary.name) (\(primary.familyDescription))")
            lines.append("- Unified Memory: \(primary.hasUnifiedMemory ? "Yes" : "No")")
            if let util = primary.utilizationPercent {
                lines.append("- Utilization: \(PulseFormat.percent(util, decimals: 1))")
            } else {
                lines.append("- Utilization: Unavailable via public API")
            }
        } else {
            lines.append("- No Metal GPU detected")
        }
        lines.append("")
        lines.append("## Battery")
        if battery.hasBattery {
            lines.append("- Charge: \(PulseFormat.percent(battery.percentage)) (\(battery.stateDescription))")
            lines.append("- Power Source: \(battery.powerSource.rawValue)")
            lines.append("- Condition: \(battery.condition)")
            if let maxCap = battery.maxCapacityPercent {
                lines.append("- Max Capacity: \(PulseFormat.percent(maxCap, decimals: 1))")
            }
            if let cycles = battery.cycleCount {
                lines.append("- Cycle Count: \(cycles)")
            }
        } else {
            lines.append("- No internal battery detected")
        }
        lines.append("")
        lines.append("## Thermal")
        lines.append("- Thermal State: \(thermal.state.rawValue)")
        lines.append("")
        lines.append("## Storage")
        for vol in storage.volumes {
            lines.append("- \(vol.name) (\(vol.mountPoint)): \(PulseFormat.decimalBytes(vol.usedBytes)) used / \(PulseFormat.decimalBytes(vol.totalBytes)) total (\(PulseFormat.decimalBytes(vol.availableBytes)) available)")
        }
        lines.append("")
        lines.append("## Network")
        lines.append("- Download: \(PulseFormat.speed(network.downloadBytesPerSec))")
        lines.append("- Upload: \(PulseFormat.speed(network.uploadBytesPerSec))")
        lines.append("- Total Received: \(PulseFormat.bytes(network.totalBytesReceived))")
        lines.append("- Total Sent: \(PulseFormat.bytes(network.totalBytesSent))")
        if includeNetworkIPs {
            for iface in network.interfaces where iface.isUp && iface.isRunning {
                lines.append("- Interface \(iface.name) (\(iface.kind)): IPv4=\(iface.ipv4Address ?? "n/a")")
            }
        } else {
            lines.append("- Interface IP addresses omitted for privacy.")
        }
        lines.append("")
        lines.append("## Top Processes (by CPU)")
        for p in topProcesses.prefix(10) {
            lines.append("- \(p.name) (PID \(p.pid)): CPU \(PulseFormat.percent(p.cpuPercent, decimals: 1)), Mem \(PulseFormat.bytes(p.memoryBytes))")
        }
        if !insights.isEmpty {
            lines.append("")
            lines.append("## Active Insights")
            for item in insights where !item.isDismissed {
                lines.append("- [\(item.severity.rawValue)] \(item.title): \(item.description)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
