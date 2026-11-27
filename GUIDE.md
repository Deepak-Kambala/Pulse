# Pulse User Guide — How to Read Your Mac's Telemetry

This guide explains every section, card, and metric in **Pulse** so you know what each number means and when to act.

---

## 1. Overview

The **Overview** page gives a single-glance summary of your Mac's health. Clicking any card opens its dedicated detail page.

- **System Header**: Shows your Mac model, chip, macOS version, current uptime since last reboot, and live monitoring status (`Live` / `Paused`).
- **CPU Card**: Shows current total CPU % and peak % in the recent window, a live sparkline, and the split between **User** (apps you run) and **System** (macOS kernel/drivers).
- **Memory Card**: Shows `Used / Physical RAM`, **Available** RAM, **Wired**, **Compressed**, **Swap**, and macOS **Memory Pressure** (`Normal`, `Elevated`, `Critical`).
- **GPU Card**: Shows current GPU utilization %, active GPU memory, live sparkline, and recommended Metal working set limit.
- **Battery Card**: Shows charge %, charging/discharging state, estimated time remaining (when reported), condition, max capacity %, and cycle count.
- **Thermal Card**: Shows macOS thermal pressure (`Nominal`, `Fair`, `Serious`, `Critical`) and whether CPU/GPU temperature or fan sensors are exposed via public APIs.
- **Storage Card**: Shows available vs. total capacity on your primary volume, usage bar, and filesystem format.
- **Network Card**: Shows live **Download** and **Upload** speeds, a throughput sparkline, and cumulative bytes received (`Rx`) / sent (`Tx`) since boot.
- **Top Processes Card**: Lists the 5 highest-CPU processes with their PID, memory footprint, and CPU %.
- **Pulse Insights Card**: Highlights up to 3 active warnings or anomalies detected from live data.

---

## 2. CPU

- **Top Metric Strip**:
  - **Current CPU**: Combined User + System load across all logical cores (`0–100%`).
  - **User**: CPU time spent running applications and user-space tools.
  - **System**: CPU time spent inside the macOS kernel, drivers, and system calls.
  - **Idle**: Unused CPU capacity.
  - **Logical Cores**: Total hardware/logical execution threads available to macOS.
- **CPU Utilization History Chart**:
  - Switch between `1m`, `5m`, `15m`, `30m`, `1h`, and `6h` windows.
  - Hover over the chart to inspect exact **User**, **System**, and **Idle** percentages at any timestamp.
- **Per-Core Utilization Grid**:
  - Shows load per logical core (`Core 0`, `Core 1`, ...). On Apple Silicon, efficiency cores often run background tasks while performance cores spike during heavy work.
- **Top CPU Processes & CPU Diagnostics**:
  - Lists the top 8 CPU consumers alongside **Window Peak**, **Window Average**, and count of **Spikes (≥ 85%)**.

---

## 3. Memory

- **Top Metric Strip**:
  - **Physical**: Total installed RAM.
  - **Used**: Active app memory + wired kernel memory + compressed memory.
  - **Available**: Free + reclaimable memory immediately available to apps.
  - **Pressure**: Official macOS memory pressure (`Normal`, `Warning`, `Critical`). **Memory Pressure is more important than Used %**—high Used % with `Normal` pressure means macOS is using RAM efficiently.
  - **Compressed**: Inactive memory compressed in RAM to avoid writing to SSD swap.
  - **Swap Used**: Memory overflowed to your SSD. Sustained multi-GB swap with `Warning`/`Critical` pressure indicates you need more free RAM.
- **Memory Composition Bar**:
  - Visualizes **App** (teal), **Wired** (amber, locked by kernel), **Compressed** (blue), and **Cached** (gray, file cache that macOS frees instantly when apps need RAM).
- **Memory & Swap Trend**:
  - Tracks Used GB vs. Swap GB over time.
- **Memory-Heavy Processes**:
  - Top 8 processes by resident memory footprint (`MB`/`GB`) and % of total RAM.
- **Memory Leak Watch**:
  - Flags processes whose memory footprint has grown steadily (≥ 25 MB and ≥ 10% net increase over ≥ 20 seconds). These are *possible growth anomalies* to keep an eye on—not automatically confirmed bugs.

---

## 4. GPU

- **Top Metric Strip**:
  - **Utilization**: Live GPU activity % (via `IOAccelerator` when exposed by your Mac's driver).
  - **In-Use Memory**: System memory currently allocated to GPU workloads.
  - **Max Working Set**: Metal's recommended maximum memory budget for graphics/compute workloads.
  - **Max Buffer**: Maximum single Metal buffer size supported.
- **GPU Utilization & GPU Memory Usage Charts**:
  - Live time-series charts showing GPU compute/graphics load and memory allocation over time.
- **Device Capabilities**:
  - Displays processor name, Metal GPU family, unified vs. discrete memory model, low-power status, and display output state.

---

## 5. Battery

*(On desktop Macs without an internal battery, Pulse displays "AC-Powered Desktop Mac".)*

- **Top Metric Strip**:
  - **Charge**: Current battery percentage and state (`Charging`, `Discharging`, `Fully Charged`, `On AC Power`).
  - **Power Source**: `Power Adapter` or `Battery`, plus estimated time remaining when macOS provides a reliable estimate.
  - **Max Capacity**: Current full-charge capacity relative to original design capacity.
  - **Cycle Count**: Total full charge/discharge cycles completed.
- **Battery Level History Chart**:
  - Plots battery % over time so you can see drain slopes and charging sessions.
- **Hardware & Electrical Details**:
  - **Condition**: macOS battery health status (`Normal`, `Service Recommended`).
  - **Current / Full Charge / Design Capacity (mAh)**: Raw milliamp-hour capacity values from `AppleSmartBattery`.
  - **Battery Temperature, Voltage, Amperage**: Real-time electrical readings from the battery controller.
- **Battery Health Observations**:
  - Hourly snapshots of maximum capacity logged to SQLite so you can track long-term battery wear.

---

## 6. Thermal

- **Top Metric Strip**:
  - **Thermal State**: Reported by `ProcessInfo.thermalState`:
    - `Nominal`: Normal operating temperature.
    - `Fair`: System is warm; fans (if present) may spin up.
    - `Serious`: High thermal load; macOS may begin throttling performance.
    - `Critical`: Severe heat; performance is actively throttled to cool hardware.
  - **CPU Temp / GPU Temp / Fan Speed**: Shown only if exposed by public non-privileged APIs; otherwise marked `Unavailable`.
- **Thermal State & CPU Load Correlation Chart**:
  - Overlays CPU utilization % against thermal pressure bars so you can see whether sustained CPU load is driving thermal elevation.

---

## 7. Processes

- **Top Metric Strip**:
  - **Total**: Total running Mach/BSD processes.
  - **Active (≥0.5%)**: Processes actively consuming ≥ 0.5% CPU right now.
  - **Highest CPU / Highest Memory**: Current single top consumer for each resource.
- **Filter Pills & Search**:
  - Filter by **All**, **User** (your account), **System** (`root` / `_` daemons), **High CPU** (≥ 10%), **High Memory** (≥ 256 MB), or **Active**.
  - Search by process name, PID, or username.
- **Process Table**:
  - Sortable by **Process**, **PID**, **PPID** (parent PID), **CPU %**, **Memory**, **User**, and **State** (`Active` vs. `Idle`).
  - Lock icon indicates critical macOS system processes (`kernel_task`, `launchd`, `WindowServer`, etc.) that are protected from termination.
- **Process Inspector & Actions**:
  - Click any row to open the right-hand inspector showing executable path, start time, and command-line arguments (where permitted).
  - Right-click or use the inspector buttons to **Terminate (`SIGTERM`)** or **Force Quit (`SIGKILL`)** non-protected processes (with confirmation).

---

## 8. Storage

- **Top Metric Strip**:
  - **Total Capacity**, **Used**, **Available**, and live **Disk Activity** (`Read / Write` speed).
- **Space Breakdown**:
  - Measures actual on-disk sizes of **Applications**, **Downloads**, **Documents**, **Desktop**, **Developer**, **User Caches**, **Movies/Music/Pictures**, and **Trash**.
  - Click **Rescan** to refresh sizes or click the folder icon next to any category to **Reveal in Finder**.
- **Disk I/O Throughput Chart**:
  - Real-time Read and Write speeds (`MB/s`) plus cumulative bytes read and written since boot.
- **Mounted Volumes**:
  - Lists internal and external drives with mount point, filesystem (e.g., APFS), capacity bar, and an **Open in Finder** button.

---

## 9. Network

- **Top Metric Strip**:
  - Live **Download**, **Upload**, cumulative **Received** / **Sent** since boot, and count of **Active** non-loopback interfaces.
- **Throughput History Chart**:
  - Real-time Download vs. Upload speed (`KB/s`).
- **Interface Explorer**:
  - Lists active/used network interfaces (`Wi-Fi / Primary`, `Ethernet / Thunderbolt`, `VPN / Tunnel`, `Loopback`) with their BSD device name (`en0`, `utun4`, etc.), IPv4/IPv6 addresses, cumulative Rx/Tx bytes, and `Up & Running` status.

---

## 10. Performance History

Persisted in a local SQLite database (`~/Library/Application Support/Pulse/pulse.sqlite`) at 10-second intervals.

- **Time Range Selector**: View `5m`, `30m`, `1h`, `6h`, `24h`, or `7d`.
- **Metric Charts**: Separate historical charts for **CPU Utilization**, **Memory Usage**, **Battery Charge**, **Network Download**, and **Thermal Pressure**, each showing **Min**, **Avg**, **Peak**, and the exact **Peak timestamp**.

---

## 11. Insights

Deterministic, offline anomaly detection rules—no cloud or AI guesswork:

- **Category Filter**: Filter by `All`, `CPU`, `Memory`, `Battery`, `Thermal`, `Storage`, or `Network`.
- **Insight Card**:
  - **Severity**: `Informational`, `Warning`, or `Critical`.
  - **Supporting Evidence**: Exact measurements (process, PID, duration, usage %) that triggered the rule.
  - **Suggested Action**: Practical next step.
  - **Acknowledge / Dismiss**: Mark as reviewed or hide; identical rules are deduplicated during cooldowns.

---

## 12. Menu Bar & Settings

- **Menu Bar (`MenuBarExtra`)**: Displays configurable live stats (`CPU %`, `Memory %`, `Memory Pressure`, `Battery %`, `Download`, `Upload`) and a lightweight dropdown with current CPU, Memory, Pressure, Battery, Thermal, Top 3 Processes, and quick shortcuts.
- **Settings**:
  - **General**: Launch at login, start minimized, show in Dock, Appearance (`System` / `Dark` / `Light`), and Default Dashboard.
  - **Monitoring & Intervals**: Toggle individual monitors and configure polling intervals (`1–60s`) and SQLite persistence.
  - **Menu Bar Indicators**: Choose visible indicators and compact formatting.
  - **Notifications**: Threshold alerts for high CPU, memory pressure, low storage, thermal warnings, and low battery.
  - **Data & Privacy**: Configure history retention (`1–30 days`), export a Markdown diagnostic report (with optional IP redaction), clear SQLite history, or reset settings.
