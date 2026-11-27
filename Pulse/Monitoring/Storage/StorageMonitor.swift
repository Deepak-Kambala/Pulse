import Foundation

final class StorageMonitor: Sendable {
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

        // Put root "/" first
        volumes.sort { lhs, rhs in
            if lhs.mountPoint == "/" { return true }
            if rhs.mountPoint == "/" { return false }
            return lhs.totalBytes > rhs.totalBytes
        }

        return StorageMetrics(timestamp: Date(), volumes: volumes)
    }
}
