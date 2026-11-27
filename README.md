# Pulse — Know what's going on.

Pulse is a native, local-first macOS system monitoring and diagnostics application built with **Swift**, **SwiftUI**, **Swift Charts**, **AppKit**, **IOKit**, **Mach APIs**, **libproc**, **Metal**, and **SQLite**.

## Features

- **System Overview**: Live 9-card dashboard with device identity, CPU, Memory, GPU, Battery, Thermal, Storage, Network, Top Processes, and Pulse Insights.
- **CPU Analytics**: Multi-series real-time chart (User / System / Idle) with 1m–6h windows, hover inspection, per-core utilization grid, and top CPU processes.
- **Memory & Leak Watch**: Non-double-counting VM statistics (App, Wired, Compressed, Cached, Swap), real macOS memory pressure (`Normal` / `Warning` / `Critical`), and sustained memory growth detection.
- **GPU Diagnostics**: Metal device discovery (`MTLCopyAllDevices`) and IOKit `IOAccelerator` statistics where exposed by the driver, with explicit reporting of unavailable metrics.
- **Battery & Power**: IOKit Power Sources & `AppleSmartBattery` telemetry (charge, cycle count, max capacity %, design capacity, voltage, amperage, historical capacity baseline).
- **Thermal Monitoring**: `ProcessInfo.thermalState` monitoring with CPU correlation and transparent disclosure of public API boundaries.
- **Process Explorer**: Searchable, sortable, filterable process manager (`libproc` / `proc_pidinfo`) with inspector drawer, executable path, command line, and protected termination (`SIGTERM` / `SIGKILL`).
- **Storage & Network**: Mounted volume explorer with low-space warnings, plus `getifaddrs` throughput & interface explorer.
- **Performance History**: Local SQLite persistence (`~/Library/Application Support/Pulse/pulse.sqlite`) with 5m–7d history and min/avg/peak summaries.
- **Pulse Insights**: Deterministic anomaly detection rules with evidence, suggested actions, deduplication, Acknowledge, and Dismiss.
- **Menu Bar Extra**: Configurable live indicators (CPU %, Memory %, Pressure, Battery %, Download/Upload) and lightweight dropdown.

## Building & Running

### Option 1: Build `.app` Bundle with SwiftPM (Command Line)

```bash
./scripts/bundle_app.sh
open build/Pulse.app
```

### Option 2: Open in Xcode

Generate or open `Pulse.xcodeproj`:

```bash
open Pulse.xcodeproj
```

Select the **Pulse** scheme and press **Cmd + R**.

### Running Unit Tests

```bash
swift test
```

## Privacy & Permissions

- **100% Local-First**: No network calls, no telemetry, no cloud backend, no account required.
- **Public APIs Only**: No private SMC entitlements or root privileges required for monitoring.
- **Diagnostic Export**: Exports Markdown diagnostic reports from **Settings → Data & Privacy** (network IP addresses are omitted by default).
