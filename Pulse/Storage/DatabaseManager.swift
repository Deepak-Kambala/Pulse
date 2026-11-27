import Foundation
import SQLite3

actor DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    let databaseURL: URL

    init(customURL: URL? = nil) {
        if let customURL {
            self.databaseURL = customURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let folder = appSupport.appendingPathComponent("Pulse", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.databaseURL = folder.appendingPathComponent("pulse.sqlite")
        }
    }

    func openIfNeeded() throws {
        if db != nil { return }
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(databaseURL.path, &handle, flags, nil)
        guard rc == SQLITE_OK, let handle else {
            let msg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            if let handle { sqlite3_close(handle) }
            throw DatabaseError.openFailed(msg)
        }
        self.db = handle
        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA synchronous=NORMAL;")
        try createTables()
    }

    private func createTables() throws {
        let snapshotsSQL = """
        CREATE TABLE IF NOT EXISTS metric_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            cpu_total REAL NOT NULL,
            cpu_user REAL NOT NULL,
            cpu_system REAL NOT NULL,
            memory_used_bytes INTEGER NOT NULL,
            memory_physical_bytes INTEGER NOT NULL,
            memory_pressure_level INTEGER NOT NULL,
            swap_used_bytes INTEGER NOT NULL,
            battery_percent REAL,
            is_charging INTEGER,
            thermal_level INTEGER NOT NULL,
            network_down_bps REAL NOT NULL,
            network_up_bps REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_metric_snapshots_timestamp ON metric_snapshots(timestamp);
        """
        try execute(snapshotsSQL)

        let batterySQL = """
        CREATE TABLE IF NOT EXISTS battery_capacity_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            max_capacity_percent REAL NOT NULL,
            cycle_count INTEGER
        );
        CREATE INDEX IF NOT EXISTS idx_battery_capacity_timestamp ON battery_capacity_log(timestamp);
        """
        try execute(batterySQL)
    }

    private func execute(_ sql: String) throws {
        guard let db else { throw DatabaseError.notOpen }
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "SQL error"
            sqlite3_free(errMsg)
            throw DatabaseError.queryFailed(msg)
        }
    }

    func insertSnapshot(_ snapshot: MetricSnapshot) throws {
        try openIfNeeded()
        guard let db else { throw DatabaseError.notOpen }

        let sql = """
        INSERT INTO metric_snapshots (
            timestamp, cpu_total, cpu_user, cpu_system,
            memory_used_bytes, memory_physical_bytes, memory_pressure_level,
            swap_used_bytes, battery_percent, is_charging,
            thermal_level, network_down_bps, network_up_bps
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, snapshot.timestamp.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 2, snapshot.cpuTotal)
        sqlite3_bind_double(stmt, 3, snapshot.cpuUser)
        sqlite3_bind_double(stmt, 4, snapshot.cpuSystem)
        sqlite3_bind_int64(stmt, 5, Int64(snapshot.memoryUsedBytes))
        sqlite3_bind_int64(stmt, 6, Int64(snapshot.memoryPhysicalBytes))
        sqlite3_bind_int(stmt, 7, Int32(snapshot.memoryPressureLevel))
        sqlite3_bind_int64(stmt, 8, Int64(snapshot.swapUsedBytes))
        if let bp = snapshot.batteryPercent {
            sqlite3_bind_double(stmt, 9, bp)
        } else {
            sqlite3_bind_null(stmt, 9)
        }
        if let ic = snapshot.isCharging {
            sqlite3_bind_int(stmt, 10, ic ? 1 : 0)
        } else {
            sqlite3_bind_null(stmt, 10)
        }
        sqlite3_bind_int(stmt, 11, Int32(snapshot.thermalLevel))
        sqlite3_bind_double(stmt, 12, snapshot.networkDownBps)
        sqlite3_bind_double(stmt, 13, snapshot.networkUpBps)

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func fetchSnapshots(since date: Date, maxPoints: Int = 360) throws -> [MetricSnapshot] {
        try openIfNeeded()
        guard let db else { throw DatabaseError.notOpen }

        let sql = """
        SELECT id, timestamp, cpu_total, cpu_user, cpu_system,
               memory_used_bytes, memory_physical_bytes, memory_pressure_level,
               swap_used_bytes, battery_percent, is_charging,
               thermal_level, network_down_bps, network_up_bps
        FROM metric_snapshots
        WHERE timestamp >= ?
        ORDER BY timestamp ASC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)
        var results: [MetricSnapshot] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let ts = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let cpuTotal = sqlite3_column_double(stmt, 2)
            let cpuUser = sqlite3_column_double(stmt, 3)
            let cpuSystem = sqlite3_column_double(stmt, 4)
            let memUsed = UInt64(max(0, sqlite3_column_int64(stmt, 5)))
            let memPhys = UInt64(max(0, sqlite3_column_int64(stmt, 6)))
            let pressure = Int(sqlite3_column_int(stmt, 7))
            let swapUsed = UInt64(max(0, sqlite3_column_int64(stmt, 8)))
            let batteryPercent: Double? = sqlite3_column_type(stmt, 9) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 9)
            let isCharging: Bool? = sqlite3_column_type(stmt, 10) == SQLITE_NULL ? nil : (sqlite3_column_int(stmt, 10) != 0)
            let thermal = Int(sqlite3_column_int(stmt, 11))
            let netDown = sqlite3_column_double(stmt, 12)
            let netUp = sqlite3_column_double(stmt, 13)

            results.append(MetricSnapshot(
                id: id,
                timestamp: ts,
                cpuTotal: cpuTotal,
                cpuUser: cpuUser,
                cpuSystem: cpuSystem,
                memoryUsedBytes: memUsed,
                memoryPhysicalBytes: memPhys,
                memoryPressureLevel: pressure,
                swapUsedBytes: swapUsed,
                batteryPercent: batteryPercent,
                isCharging: isCharging,
                thermalLevel: thermal,
                networkDownBps: netDown,
                networkUpBps: netUp
            ))
        }

        guard results.count > maxPoints, maxPoints > 0 else { return results }
        let stride = Double(results.count) / Double(maxPoints)
        var sampled: [MetricSnapshot] = []
        sampled.reserveCapacity(maxPoints)
        var idx = 0.0
        while Int(idx) < results.count {
            sampled.append(results[Int(idx)])
            idx += stride
        }
        return sampled
    }

    func logBatteryCapacity(maxCapacityPercent: Double, cycleCount: Int?) throws {
        try openIfNeeded()
        guard let db else { throw DatabaseError.notOpen }

        let sql = "INSERT INTO battery_capacity_log (timestamp, max_capacity_percent, cycle_count) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
        sqlite3_bind_double(stmt, 2, maxCapacityPercent)
        if let cycleCount {
            sqlite3_bind_int(stmt, 3, Int32(cycleCount))
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func fetchBatteryCapacityHistory(limit: Int = 60) throws -> [(Date, Double, Int?)] {
        try openIfNeeded()
        guard let db else { throw DatabaseError.notOpen }
        let sql = "SELECT timestamp, max_capacity_percent, cycle_count FROM battery_capacity_log ORDER BY timestamp DESC LIMIT ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))
        var rows: [(Date, Double, Int?)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let date = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0))
            let pct = sqlite3_column_double(stmt, 1)
            let cycles: Int? = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 2))
            rows.append((date, pct, cycles))
        }
        return rows.reversed()
    }

    func pruneOlderThan(days: Int) throws {
        try openIfNeeded()
        guard let db else { throw DatabaseError.notOpen }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400.0).timeIntervalSince1970
        let sql = "DELETE FROM metric_snapshots WHERE timestamp < ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, cutoff)
        sqlite3_step(stmt)
    }

    func clearAllHistory() throws {
        try openIfNeeded()
        try execute("DELETE FROM metric_snapshots;")
        try execute("DELETE FROM battery_capacity_log;")
        try execute("VACUUM;")
    }

    func snapshotCount() throws -> Int {
        try openIfNeeded()
        guard let db else { throw DatabaseError.notOpen }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM metric_snapshots;", -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        return 0
    }
}

enum DatabaseError: LocalizedError {
    case openFailed(String)
    case notOpen
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "Failed to open Pulse database: \(msg)"
        case .notOpen: return "Pulse database is not open."
        case .queryFailed(let msg): return "Database query failed: \(msg)"
        }
    }
}
