import Foundation
import IOKit

final class StorageMonitor: @unchecked Sendable {
    private var previousReadBytes: UInt64?
    private var previousWriteBytes: UInt64?
    private var previousIOTime: Date?
    private let lock = NSLock()

    func sample() -> StorageMetrics {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeLocalizedFormatDescriptionKey,
            .volumeIsInternalKey,
            .volumeIsReadOnlyKey,
            .volumeIsBrowsableKey
        ]

        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        let candidateURLs = urls.isEmpty ? [URL(fileURLWithPath: "/")] : urls

        var volumes: [VolumeInfo] = []
        for url in candidateURLs {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            guard let total = values.volumeTotalCapacity, total > 0 else { continue }

            let availableImportant = values.volumeAvailableCapacityForImportantUsage
            let availableRegular = values.volumeAvailableCapacity.map { Int64($0) }
            let available = max(0, availableImportant ?? availableRegular ?? 0)

            let name = values.volumeName ?? url.lastPathComponent
            let fs = values.volumeLocalizedFormatDescription ?? "Unknown"
            let isInternal = values.volumeIsInternal ?? true
            let isReadOnly = values.volumeIsReadOnly ?? false

            volumes.append(VolumeInfo(
                id: url.path,
                name: name,
                mountPoint: url.path,
                fileSystemType: fs,
                totalBytes: UInt64(total),
                availableBytes: UInt64(available),
                isInternal: isInternal,
                isReadOnly: isReadOnly
            ))
        }

        volumes.sort { lhs, rhs in
            if lhs.mountPoint == "/" { return true }
            if rhs.mountPoint == "/" { return false }
            return lhs.totalBytes > rhs.totalBytes
        }

        let io = sampleDiskIO()

        return StorageMetrics(
            timestamp: Date(),
            volumes: volumes,
            diskReadBytesPerSec: io.readBps,
            diskWriteBytesPerSec: io.writeBps,
            totalDiskBytesRead: io.totalRead,
            totalDiskBytesWritten: io.totalWritten
        )
    }

    private func sampleDiskIO() -> (readBps: Double, writeBps: Double, totalRead: UInt64, totalWritten: UInt64) {
        lock.lock()
        defer { lock.unlock() }

        var totalRead: UInt64 = 0
        var totalWritten: UInt64 = 0

        var iterator: io_iterator_t = 0
        if let matching = IOServiceMatching("IOBlockStorageDriver"),
           IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            var service = IOIteratorNext(iterator)
            while service != 0 {
                defer {
                    IOObjectRelease(service)
                    service = IOIteratorNext(iterator)
                }
                var propsRef: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let props = propsRef?.takeRetainedValue() as? [String: Any],
                   let stats = props["Statistics"] as? [String: Any] {
                    if let r = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value {
                        totalRead &+= r
                    }
                    if let w = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value {
                        totalWritten &+= w
                    }
                }
            }
        }

        let now = Date()
        var readBps = 0.0
        var writeBps = 0.0
        if let prevR = previousReadBytes, let prevW = previousWriteBytes, let prevT = previousIOTime {
            let dt = now.timeIntervalSince(prevT)
            if dt > 0.05 {
                let dR = totalRead >= prevR ? totalRead - prevR : 0
                let dW = totalWritten >= prevW ? totalWritten - prevW : 0
                readBps = Double(dR) / dt
                writeBps = Double(dW) / dt
            }
        }
        previousReadBytes = totalRead
        previousWriteBytes = totalWritten
        previousIOTime = now

        return (readBps, writeBps, totalRead, totalWritten)
    }

    static func scanDirectoryBreakdown() -> [StorageCategoryUsage] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let targets: [(id: String, name: String, paths: [String], symbol: String)] = [
            ("apps", "Applications", ["/Applications", "\(home)/Applications"], "app.badge"),
            ("downloads", "Downloads", ["\(home)/Downloads"], "arrow.down.circle"),
            ("documents", "Documents", ["\(home)/Documents"], "doc.text"),
            ("desktop", "Desktop", ["\(home)/Desktop"], "menubar.dock.rectangle"),
            ("developer", "Developer", ["\(home)/Library/Developer"], "hammer"),
            ("caches", "User Caches", ["\(home)/Library/Caches"], "archivebox"),
            ("media", "Movies, Music & Pictures", ["\(home)/Movies", "\(home)/Music", "\(home)/Pictures"], "photo.on.rectangle"),
            ("trash", "Trash", ["\(home)/.Trash"], "trash")
        ]

        var results: [StorageCategoryUsage] = []
        for target in targets {
            var totalBytes: UInt64 = 0
            for path in target.paths {
                totalBytes &+= directoryAllocatedSize(at: path)
            }
            if totalBytes > 0 {
                results.append(StorageCategoryUsage(
                    id: target.id,
                    name: target.name,
                    path: target.paths.first ?? home,
                    bytes: totalBytes,
                    symbolName: target.symbol
                ))
            }
        }
        return results.sorted { $0.bytes > $1.bytes }
    }

    private static func directoryAllocatedSize(at path: String) -> UInt64 {
        let url = URL(fileURLWithPath: path)
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return 0 }

        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var sum: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let vals = try? fileURL.resourceValues(forKeys: Set(keys)),
                  vals.isRegularFile == true else { continue }
            if let size = vals.totalFileAllocatedSize ?? vals.fileAllocatedSize, size > 0 {
                sum &+= UInt64(size)
            }
        }
        return sum
    }
}
