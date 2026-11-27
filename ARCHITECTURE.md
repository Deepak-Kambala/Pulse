# Pulse Architecture

## Overview

Pulse follows a clean, modular, local-first architecture separating data collection, persistence, deterministic analytics, and SwiftUI presentation:

```
Pulse/
├── App/          # @main PulseApp, AppDelegate, Window & MenuBarExtra scenes
├── Core/         # SystemMonitor coordinator, MetricsModels, PulseSettings, Formatters, Notifications, Exporter
├── Monitoring/   # Independent, Sendable system collectors (CPU, Memory, GPU, Battery, Thermal, Storage, Network, Processes)
├── Analytics/    # Deterministic AnomalyDetector & insight rules
├── Storage/      # SQLite3 DatabaseManager actor & HistoryRepository
└── UI/           # Adaptive Dark/Light PulseTheme, reusable components, 12 feature views, MenuBar
```

## Concurrency & Performance

- **Single Unified Loop**: `SystemMonitor` runs one lightweight async timer loop (2s base tick) and dispatches all Mach/IOKit/libproc calls on `Task.detached(priority: .utility)` so the main thread is never blocked.
- **Actor-Isolated SQLite**: `DatabaseManager` is a Swift `actor` using `libsqlite3` in WAL mode with `FULLMUTEX`, writing snapshots every 10 seconds and pruning old records automatically based on user retention settings.
- **Bounded Memory**: In-memory rolling chart buffers are capped at 6 hours (10,800 samples).

## Metric Sources & Methodology

| Domain | Public API Source | Notes |
| --- | --- | --- |
| **CPU** | `host_processor_info` (`PROCESSOR_CPU_LOAD_INFO`) | Delta ticks per logical core (`user`, `system`, `idle`, `nice`) |
| **Memory** | `host_statistics64` (`HOST_VM_INFO64`), `vm.swapusage`, `kern.memorystatus_vm_pressure_level` | `Used = App (internal - purgeable) + Wired + Compressed`; Cached is reclaimable and not double-counted |
| **GPU** | `MTLCopyAllDevices()`, `IOAccelerator` `PerformanceStatistics` | Explicitly marks utilization/memory as unavailable if not exposed by the driver |
| **Battery** | `IOPSCopyPowerSourcesInfo`, `AppleSmartBattery` | Reports charge, cycles, design vs. raw max capacity; handles desktop Macs gracefully |
| **Thermal** | `ProcessInfo.processInfo.thermalState` | Does not fabricate die temperatures or fan RPMs without public sensor APIs |
| **Processes** | `proc_listallpids`, `proc_pidinfo(PROC_PIDTASKALLINFO)`, `proc_pidpath`, `KERN_PROCARGS2` | CPU% computed via Mach timebase delta; critical system processes are protected |
| **Storage** | `FileManager.mountedVolumeURLs` | Volume-level capacity & availability; no fabricated file category breakdowns |
| **Network** | `getifaddrs` (`AF_LINK` `if_data`, `AF_INET`, `AF_INET6`) | Throughput computed from cumulative byte counter deltas over elapsed time |
