import Foundation

// MARK: - Navigation

enum NavigationSection: String, CaseIterable, Identifiable, Codable, Sendable {
    case overview
    case cpu
    case memory
    case gpu
    case battery
    case thermal
    case processes
    case storage
    case network
    case history
    case insights
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .gpu: return "GPU"
        case .battery: return "Battery"
        case .thermal: return "Thermal"
        case .processes: return "Processes"
        case .storage: return "Storage"
        case .network: return "Network"
        case .history: return "Performance History"
        case .insights: return "Insights"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .gpu: return "display"
        case .battery: return "battery.75percent"
        case .thermal: return "thermometer.medium"
        case .processes: return "list.bullet.rectangle"
        case .storage: return "internaldrive"
        case .network: return "network"
        case .history: return "chart.xyaxis.line"
        case .insights: return "lightbulb"
        case .settings: return "gearshape"
        }
    }

    var group: NavigationGroup {
        switch self {
        case .overview:
            return .main
        case .cpu, .memory, .gpu, .battery, .thermal, .processes, .storage, .network:
            return .monitors
        case .history, .insights, .settings:
            return .diagnostics
        }
    }
}

enum NavigationGroup: String, CaseIterable {
    case main = "Dashboard"
    case monitors = "System"
    case diagnostics = "Analytics"
}

// MARK: - Semantic Health Status

enum HealthStatus: String, Codable, Sendable {
    case healthy
    case warning
    case critical
    case neutral

    var label: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Elevated"
        case .critical: return "Critical"
        case .neutral: return "Unavailable"
        }
    }

    var symbolName: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        case .neutral: return "minus.circle.fill"
        }
    }
}

// MARK: - System Identity

struct SystemIdentity: Sendable, Equatable {
    let deviceModel: String
    let chipName: String
    let osVersion: String
    let hostName: String
    let physicalMemoryBytes: UInt64
    let logicalCoreCount: Int
    let physicalCoreCount: Int
    let uptimeSeconds: TimeInterval

    static let empty = SystemIdentity(
        deviceModel: "Mac",
        chipName: "Apple Silicon",
        osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
        hostName: ProcessInfo.processInfo.hostName,
        physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
        logicalCoreCount: ProcessInfo.processInfo.processorCount,
        physicalCoreCount: ProcessInfo.processInfo.activeProcessorCount,
        uptimeSeconds: ProcessInfo.processInfo.systemUptime
    )
}

// MARK: - CPU

struct CPUCoreMetric: Identifiable, Sendable, Equatable {
    let id: Int
    let totalUsage: Double
    let userUsage: Double
    let systemUsage: Double
    let idleUsage: Double

    var status: HealthStatus {
        if totalUsage >= 85 { return .critical }
        if totalUsage >= 65 { return .warning }
        return .healthy
    }
}

struct CPUMetrics: Sendable, Equatable {
    let timestamp: Date
    let totalUsage: Double
    let userUsage: Double
    let systemUsage: Double
    let idleUsage: Double
    let niceUsage: Double
    let logicalCoreCount: Int
    let cores: [CPUCoreMetric]
    let isAvailable: Bool

    var status: HealthStatus {
        guard isAvailable else { return .neutral }
        if totalUsage >= 85 { return .critical }
        if totalUsage >= 65 { return .warning }
        return .healthy
    }

    static let unavailable = CPUMetrics(
        timestamp: Date(),
        totalUsage: 0,
        userUsage: 0,
        systemUsage: 0,
        idleUsage: 0,
        niceUsage: 0,
        logicalCoreCount: ProcessInfo.processInfo.processorCount,
        cores: [],
        isAvailable: false
    )
}

struct CPUSample: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let total: Double
    let user: Double
    let system: Double
    let idle: Double
}

// MARK: - Memory

enum MemoryPressureLevel: String, Codable, Sendable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"

    var status: HealthStatus {
        switch self {
        case .normal: return .healthy
        case .warning: return .warning
        case .critical: return .critical
        case .unknown: return .neutral
        }
    }
}

struct MemoryMetrics: Sendable, Equatable {
    let timestamp: Date
    let physicalBytes: UInt64
    let usedBytes: UInt64
    let availableBytes: UInt64
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let cachedFilesBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64
    let pressureLevel: MemoryPressureLevel
    let isAvailable: Bool

    var usedPercentage: Double {
        guard physicalBytes > 0 else { return 0 }
        return min(100, max(0, (Double(usedBytes) / Double(physicalBytes)) * 100.0))
    }

    var otherSystemBytes: UInt64 {
        let accounted = appBytes + wiredBytes + compressedBytes
        return usedBytes > accounted ? usedBytes - accounted : 0
    }

    static let unavailable = MemoryMetrics(
        timestamp: Date(),
        physicalBytes: ProcessInfo.processInfo.physicalMemory,
        usedBytes: 0,
        availableBytes: 0,
        appBytes: 0,
        wiredBytes: 0,
        compressedBytes: 0,
        cachedFilesBytes: 0,
        swapUsedBytes: 0,
        swapTotalBytes: 0,
        pressureLevel: .unknown,
        isAvailable: false
    )
}

struct MemorySample: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let usedBytes: UInt64
    let compressedBytes: UInt64
    let swapUsedBytes: UInt64
    let pressureLevel: MemoryPressureLevel
}

// MARK: - GPU

struct GPUDeviceSummary: Identifiable, Sendable, Equatable {
    let id: UInt64
    let name: String
    let familyDescription: String
    let hasUnifiedMemory: Bool
    let isLowPower: Bool
    let isHeadless: Bool
    let recommendedMaxWorkingSetBytes: UInt64
    let currentAllocatedBytes: UInt64
    let maxBufferLengthBytes: UInt64
    let utilizationPercent: Double?
    let inUseSystemMemoryBytes: UInt64?
    let driverStatusNote: String
}

struct GPUMetrics: Sendable, Equatable {
    let timestamp: Date
    let devices: [GPUDeviceSummary]
    let isAvailable: Bool

    var primaryDevice: GPUDeviceSummary? { devices.first }

    static let unavailable = GPUMetrics(timestamp: Date(), devices: [], isAvailable: false)
}

// MARK: - Battery

enum PowerSource: String, Codable, Sendable {
    case ac = "Power Adapter"
    case battery = "Battery"
    case ups = "UPS"
    case unknown = "Unknown"
}

struct BatteryMetrics: Sendable, Equatable {
    let timestamp: Date
    let hasBattery: Bool
    let percentage: Double
    let isCharging: Bool
    let isCharged: Bool
    let externalConnected: Bool
    let powerSource: PowerSource
    let condition: String
    let cycleCount: Int?
    let maxCapacityPercent: Double?
    let currentCapacityMah: Int?
    let maxCapacityMah: Int?
    let designCapacityMah: Int?
    let timeRemainingMinutes: Int?
    let temperatureCelsius: Double?
    let amperageMa: Int?
    let voltageMv: Int?

    var status: HealthStatus {
        guard hasBattery else { return .neutral }
        if !externalConnected && percentage <= 15 { return .critical }
        if !externalConnected && percentage <= 25 { return .warning }
        if let maxCap = maxCapacityPercent, maxCap < 80 { return .warning }
        return .healthy
    }

    var stateDescription: String {
        guard hasBattery else { return "No Battery" }
        if isCharged && externalConnected { return "Fully Charged" }
        if isCharging { return "Charging" }
        if externalConnected { return "On AC Power (Not Charging)" }
        return "Discharging"
    }

    static let noBattery = BatteryMetrics(
        timestamp: Date(),
        hasBattery: false,
        percentage: 0,
        isCharging: false,
        isCharged: false,
        externalConnected: true,
        powerSource: .ac,
        condition: "N/A",
        cycleCount: nil,
        maxCapacityPercent: nil,
        currentCapacityMah: nil,
        maxCapacityMah: nil,
        designCapacityMah: nil,
        timeRemainingMinutes: nil,
        temperatureCelsius: nil,
        amperageMa: nil,
        voltageMv: nil
    )
}

struct BatterySample: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let percentage: Double
    let isCharging: Bool
    let externalConnected: Bool
}

// MARK: - Thermal

enum SystemThermalState: String, Codable, Sendable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"

    init(processInfoState: ProcessInfo.ThermalState) {
        switch processInfoState {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }

    var numericLevel: Int {
        switch self {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        }
    }

    var status: HealthStatus {
        switch self {
        case .nominal: return .healthy
        case .fair: return .warning
        case .serious, .critical: return .critical
        }
    }

    var summaryDescription: String {
        switch self {
        case .nominal: return "System thermals are within normal operating limits."
        case .fair: return "System is warm; fans (if present) may spin up under sustained load."
        case .serious: return "High thermal pressure; macOS may begin throttling performance."
        case .critical: return "Critical thermal state; performance is throttled to cool hardware."
        }
    }
}

struct ThermalMetrics: Sendable, Equatable {
    let timestamp: Date
    let state: SystemThermalState
    let cpuTemperatureCelsius: Double?
    let gpuTemperatureCelsius: Double?
    let fanSpeedRPM: Int?
    let sensorAvailabilityNote: String

    static let initial = ThermalMetrics(
        timestamp: Date(),
        state: SystemThermalState(processInfoState: ProcessInfo.processInfo.thermalState),
        cpuTemperatureCelsius: nil,
        gpuTemperatureCelsius: nil,
        fanSpeedRPM: nil,
        sensorAvailabilityNote: "macOS public APIs expose ProcessInfo.thermalState; direct SMC temperature and fan sensors require private interfaces not used by Pulse."
    )
}

struct ThermalSample: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let state: SystemThermalState
    let cpuUsageAtTime: Double
}

// MARK: - Storage

struct VolumeInfo: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let mountPoint: String
    let fileSystemType: String
    let totalBytes: UInt64
    let availableBytes: UInt64
    let isInternal: Bool
    let isReadOnly: Bool

    var usedBytes: UInt64 {
        totalBytes > availableBytes ? totalBytes - availableBytes : 0
    }

    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100.0
    }

    var availablePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(availableBytes) / Double(totalBytes)) * 100.0
    }

    var status: HealthStatus {
        if availablePercentage < 10 { return .critical }
        if availablePercentage < 15 { return .warning }
        return .healthy
    }
}

struct StorageMetrics: Sendable, Equatable {
    let timestamp: Date
    let volumes: [VolumeInfo]

    var primaryVolume: VolumeInfo? {
        volumes.first(where: { $0.mountPoint == "/" }) ?? volumes.first
    }

    static let empty = StorageMetrics(timestamp: Date(), volumes: [])
}

// MARK: - Network

struct NetworkInterfaceInfo: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let kind: String
    let isUp: Bool
    let isRunning: Bool
    let ipv4Address: String?
    let ipv6Address: String?
    let bytesReceived: UInt64
    let bytesSent: UInt64
}

struct NetworkMetrics: Sendable, Equatable {
    let timestamp: Date
    let downloadBytesPerSec: Double
    let uploadBytesPerSec: Double
    let totalBytesReceived: UInt64
    let totalBytesSent: UInt64
    let interfaces: [NetworkInterfaceInfo]

    var activeInterfacesCount: Int {
        interfaces.filter { $0.isUp && $0.isRunning && $0.kind != "Loopback" }.count
    }

    static let empty = NetworkMetrics(
        timestamp: Date(),
        downloadBytesPerSec: 0,
        uploadBytesPerSec: 0,
        totalBytesReceived: 0,
        totalBytesSent: 0,
        interfaces: []
    )
}

struct NetworkSample: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let downloadBytesPerSec: Double
    let uploadBytesPerSec: Double
}

// MARK: - Processes

enum ProcessRunState: String, Codable, Sendable {
    case running = "Running"
    case sleeping = "Sleeping"
    case stopped = "Stopped"
    case zombie = "Zombie"
    case idle = "Idle"
    case unknown = "Unknown"
}

struct ProcessInfoModel: Identifiable, Sendable, Equatable {
    var id: Int32 { pid }
    let pid: Int32
    let ppid: Int32
    let name: String
    let executablePath: String?
    let user: String
    let uid: UInt32
    let cpuPercent: Double
    let memoryBytes: UInt64
    let memoryPercent: Double
    let state: ProcessRunState
    let startTime: Date?
    let commandLine: String?
    let isSystemCritical: Bool
    let memoryDeltaBytes: Int64
}

struct MemoryGrowthCandidate: Identifiable, Sendable, Equatable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let startingBytes: UInt64
    let currentBytes: UInt64
    let netIncreaseBytes: UInt64
    let observationDuration: TimeInterval
}

// MARK: - Insights

enum InsightSeverity: String, Codable, Sendable, CaseIterable {
    case info = "Informational"
    case warning = "Warning"
    case critical = "Critical"

    var status: HealthStatus {
        switch self {
        case .info: return .healthy
        case .warning: return .warning
        case .critical: return .critical
        }
    }

    var symbolName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

enum InsightCategory: String, Codable, Sendable, CaseIterable {
    case cpu = "CPU"
    case memory = "Memory"
    case battery = "Battery"
    case thermal = "Thermal"
    case storage = "Storage"
    case network = "Network"
}

struct InsightItem: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let ruleKey: String
    let category: InsightCategory
    let severity: InsightSeverity
    let title: String
    let description: String
    let detectedAt: Date
    let relatedProcessName: String?
    let relatedProcessPID: Int32?
    let evidence: [String]
    let suggestedAction: String
    var isAcknowledged: Bool = false
    var isDismissed: Bool = false
}

// MARK: - Historical Persistence

enum HistoryTimeRange: String, CaseIterable, Identifiable, Sendable {
    case fiveMinutes = "5m"
    case thirtyMinutes = "30m"
    case oneHour = "1h"
    case sixHours = "6h"
    case twentyFourHours = "24h"
    case sevenDays = "7d"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fiveMinutes: return "5 Minutes"
        case .thirtyMinutes: return "30 Minutes"
        case .oneHour: return "1 Hour"
        case .sixHours: return "6 Hours"
        case .twentyFourHours: return "24 Hours"
        case .sevenDays: return "7 Days"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .fiveMinutes: return 5 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .sixHours: return 6 * 3600
        case .twentyFourHours: return 24 * 3600
        case .sevenDays: return 7 * 24 * 3600
        }
    }
}

struct MetricSnapshot: Identifiable, Sendable {
    let id: Int64
    let timestamp: Date
    let cpuTotal: Double
    let cpuUser: Double
    let cpuSystem: Double
    let memoryUsedBytes: UInt64
    let memoryPhysicalBytes: UInt64
    let memoryPressureLevel: Int
    let swapUsedBytes: UInt64
    let batteryPercent: Double?
    let isCharging: Bool?
    let thermalLevel: Int
    let networkDownBps: Double
    let networkUpBps: Double
}

struct MetricSummaryStats: Sendable {
    let minimum: Double
    let average: Double
    let peak: Double
    let peakTime: Date?
}
