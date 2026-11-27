import Foundation

enum PulseFormat {
    static func bytes(_ value: UInt64, decimals: Int = 1) -> String {
        let gb = Double(value) / 1_073_741_824.0
        if gb >= 1.0 {
            return String(format: "%.\(decimals)f GB", gb)
        }
        let mb = Double(value) / 1_048_576.0
        if mb >= 1.0 {
            return String(format: "%.\(decimals)f MB", mb)
        }
        let kb = Double(value) / 1024.0
        if kb >= 1.0 {
            return String(format: "%.0f KB", kb)
        }
        return "\(value) B"
    }

    static func decimalBytes(_ value: UInt64, decimals: Int = 1) -> String {
        let tb = Double(value) / 1_000_000_000_000.0
        if tb >= 1.0 {
            return String(format: "%.2f TB", tb)
        }
        let gb = Double(value) / 1_000_000_000.0
        if gb >= 1.0 {
            return String(format: "%.\(decimals)f GB", gb)
        }
        let mb = Double(value) / 1_000_000.0
        if mb >= 1.0 {
            return String(format: "%.\(decimals)f MB", mb)
        }
        let kb = Double(value) / 1000.0
        if kb >= 1.0 {
            return String(format: "%.0f KB", kb)
        }
        return "\(value) B"
    }

    static func speed(_ bytesPerSec: Double) -> String {
        let mbps = bytesPerSec / 1_048_576.0
        if mbps >= 1.0 {
            return String(format: "%.1f MB/s", mbps)
        }
        let kbps = bytesPerSec / 1024.0
        if kbps >= 1.0 {
            return String(format: "%.0f KB/s", kbps)
        }
        return String(format: "%.0f B/s", max(0, bytesPerSec))
    }

    static func percent(_ value: Double, decimals: Int = 0) -> String {
        let clamped = min(100, max(0, value))
        return String(format: "%.\(decimals)f%%", clamped)
    }

    static func uptime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let mins = totalMinutes % 60
        if days > 0 {
            return "\(days)d \(hours)h \(mins)m"
        }
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        let h = s / 3600
        let m = (s % 3600) / 60
        let rem = s % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        if m > 0 {
            return "\(m)m \(rem)s"
        }
        return "\(rem)s"
    }

    static func timeRemaining(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        f.dateStyle = .none
        return f
    }()

    static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f
    }()
}
