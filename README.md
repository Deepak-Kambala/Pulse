# Pulse — Know what's going on.

Pulse is a native, local-first macOS system monitoring and diagnostics application built with **Swift**, **SwiftUI**, **Swift Charts**, **AppKit**, **IOKit**, **Mach APIs**, **libproc**, **Metal**, and **SQLite**.

## Features

- **System Overview**: Single-glance dashboard with Mac identity, CPU, Memory, GPU, Battery, Thermal, Storage, Network, Top Processes, and Pulse Insights.
- **CPU Analytics**: Multi-series real-time chart (User / System / Idle) with `1m`–`6h` windows, hover inspection, per-core utilization grid, and top CPU processes.
- **Memory & Leak Watch**: Non-double-counting VM statistics (App, Wired, Compressed, Cached, Swap), real macOS memory pressure (`Normal` / `Warning` / `Critical`), and sustained memory growth detection.
- **GPU Diagnostics**: Metal device discovery (`MTLCopyAllDevices`) and live `IOAccelerator` utilization % and GPU memory charts.
- **Battery & Power**: IOKit Power Sources & `AppleSmartBattery` telemetry (charge, hardware cycle count, design vs. max capacity %, voltage, amperage, historical capacity baseline) plus configurable **Min (20%) / Max (80%)** charge alerts with custom audio.
- **Thermal Monitoring**: `ProcessInfo.thermalState` monitoring with CPU load correlation.
- **Process Explorer**: Searchable, sortable, filterable process manager (`libproc` / `proc_pidinfo`) with app icons, inspector drawer, executable path, command line, and protected termination (`SIGTERM` / `SIGKILL`).
- **Storage & Network**: Measured on-disk directory breakdown (`Applications`, `Downloads`, `Documents`, `Developer`, `Caches`, etc.) with **Reveal in Finder**, live IOKit Disk I/O throughput chart, mounted volumes, and `getifaddrs` network throughput & interface explorer.
- **Performance History**: Local SQLite persistence (`~/Library/Application Support/Pulse/pulse.sqlite`, ~9–11 MB/year at default 7-day retention) with `5m`–`7d` charts and min/avg/peak summaries.
- **Pulse Insights**: Deterministic anomaly detection rules with supporting evidence, suggested actions, deduplication, Acknowledge, and Dismiss. Only critical/must-see alerts interrupt on screen.
- **Menu Bar Extra**: Configurable live indicators (`CPU %`, `Memory %`, `Pressure`, `Battery %`, `Download`, `Upload`) and lightweight dropdown.

## Documentation

- **[User Guide (GUIDE.md)](GUIDE.md)** — Detailed explanation of every section, card, chart, and metric in Pulse and how to interpret them.
- **[Architecture (ARCHITECTURE.md)](ARCHITECTURE.md)** — Internal module layout, concurrency model, and public macOS API sources.

## Building & Running

### Option 1: Download Prebuilt DMG (Apple Silicon, macOS 14+)

1. Download `Pulse-1.0.0-macOS-arm64.dmg` from [GitHub Releases](https://github.com/Deepak-Kambala/Pulse/releases/latest).
2. Open the `.dmg` and drag **Pulse.app** into **Applications**.
3. On first launch, if macOS shows *"Apple could not verify Pulse"*:
   - Click **Done**, open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**, **or**
   - Run in Terminal:
     ```bash
     xattr -cr /Applications/Pulse.app && open /Applications/Pulse.app
     ```

### Option 2: Build `.app` Bundle from Source

```bash
./scripts/bundle_app.sh
open build/Pulse.app
```

### Run Unit Tests

```bash
swift test
```

## Privacy & Permissions

- **100% Local-First**: No network calls, no telemetry, no cloud backend, no account required.
- **Public APIs Only**: No private SMC entitlements or root privileges required for monitoring.
- **Diagnostic Export**: Exports Markdown diagnostic reports from **Settings → Data & Privacy** (network IP addresses are omitted by default).
