import Foundation
import Darwin

final class NetworkMonitor: @unchecked Sendable {
    private var previousTotalIn: UInt64?
    private var previousTotalOut: UInt64?
    private var previousTimestamp: Date?
    private let lock = NSLock()

    func sample() -> NetworkMetrics {
        lock.lock()
        defer { lock.unlock() }

        var ifaddrsPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrsPtr) == 0, let firstAddr = ifaddrsPtr else {
            return .empty
        }
        defer { freeifaddrs(ifaddrsPtr) }

        struct Accumulator {
            var name: String
            var isUp: Bool = false
            var isRunning: Bool = false
            var ipv4: String?
            var ipv6: String?
            var bytesIn: UInt64 = 0
            var bytesOut: UInt64 = 0
        }

        var map: [String: Accumulator] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr

        while let addr = cursor {
            let name = String(cString: addr.pointee.ifa_name)
            let flags = Int32(addr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0

            var entry = map[name] ?? Accumulator(name: name)
            entry.isUp = entry.isUp || isUp
            entry.isRunning = entry.isRunning || isRunning

            if let sa = addr.pointee.ifa_addr {
                let family = Int32(sa.pointee.sa_family)
                if family == AF_LINK, let dataPtr = addr.pointee.ifa_data {
                    let ifData = dataPtr.assumingMemoryBound(to: if_data.self).pointee
                    entry.bytesIn &+= UInt64(ifData.ifi_ibytes)
                    entry.bytesOut &+= UInt64(ifData.ifi_obytes)
                } else if family == AF_INET {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                        entry.ipv4 = String(cString: host)
                    }
                } else if family == AF_INET6 {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: host)
                        if !ip.hasPrefix("fe80:") {
                            entry.ipv6 = ip
                        } else if entry.ipv6 == nil {
                            entry.ipv6 = ip
                        }
                    }
                }
            }

            map[name] = entry
            cursor = addr.pointee.ifa_next
        }

        let interfaces: [NetworkInterfaceInfo] = map.values
            .map { acc in
                NetworkInterfaceInfo(
                    id: acc.name,
                    name: acc.name,
                    kind: classifyInterface(acc.name),
                    isUp: acc.isUp,
                    isRunning: acc.isRunning,
                    ipv4Address: acc.ipv4,
                    ipv6Address: acc.ipv6,
                    bytesReceived: acc.bytesIn,
                    bytesSent: acc.bytesOut
                )
            }
            .sorted { lhs, rhs in
                if lhs.isUp && lhs.isRunning && !(rhs.isUp && rhs.isRunning) { return true }
                if rhs.isUp && rhs.isRunning && !(lhs.isUp && lhs.isRunning) { return false }
                return (lhs.bytesReceived + lhs.bytesSent) > (rhs.bytesReceived + rhs.bytesSent)
            }

        // Aggregate non-loopback counters for throughput
        let nonLoopback = interfaces.filter { $0.kind != "Loopback" }
        let totalIn = nonLoopback.reduce(0) { $0 &+ $1.bytesReceived }
        let totalOut = nonLoopback.reduce(0) { $0 &+ $1.bytesSent }

        let now = Date()
        var downBps = 0.0
        var upBps = 0.0

        if let prevIn = previousTotalIn, let prevOut = previousTotalOut, let prevTime = previousTimestamp {
            let dt = now.timeIntervalSince(prevTime)
            if dt > 0.05 {
                let dIn = totalIn >= prevIn ? totalIn - prevIn : 0
                let dOut = totalOut >= prevOut ? totalOut - prevOut : 0
                downBps = Double(dIn) / dt
                upBps = Double(dOut) / dt
            }
        }

        previousTotalIn = totalIn
        previousTotalOut = totalOut
        previousTimestamp = now

        return NetworkMetrics(
            timestamp: now,
            downloadBytesPerSec: downBps,
            uploadBytesPerSec: upBps,
            totalBytesReceived: totalIn,
            totalBytesSent: totalOut,
            interfaces: interfaces
        )
    }

    private func classifyInterface(_ name: String) -> String {
        if name.hasPrefix("lo") { return "Loopback" }
        if name.hasPrefix("en0") { return "Wi-Fi / Primary" }
        if name.hasPrefix("en") { return "Ethernet / Thunderbolt" }
        if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") { return "VPN / Tunnel" }
        if name.hasPrefix("awdl") || name.hasPrefix("llw") { return "Apple Wireless Direct" }
        if name.hasPrefix("bridge") { return "Bridge" }
        return "Other"
    }
}
