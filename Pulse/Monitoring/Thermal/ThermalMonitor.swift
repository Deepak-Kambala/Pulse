import Foundation

final class ThermalMonitor: Sendable {
    func sample() -> ThermalMetrics {
        let state = SystemThermalState(processInfoState: ProcessInfo.processInfo.thermalState)
        return ThermalMetrics(
            timestamp: Date(),
            state: state,
            cpuTemperatureCelsius: nil,
            gpuTemperatureCelsius: nil,
            fanSpeedRPM: nil,
            sensorAvailabilityNote: "macOS public APIs provide ProcessInfo.thermalState. Direct CPU/GPU die temperature and fan RPM sensors are not exposed via public non-privileged APIs on Apple Silicon."
        )
    }
}
