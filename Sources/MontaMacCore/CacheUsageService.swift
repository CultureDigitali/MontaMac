import Foundation

public struct CacheUsageSnapshot: Equatable, Sendable {
    public let totalBytes: Int64
    public let bytesByProfile: [UUID: Int64]
    public let availableDiskBytes: Int64
    public let measuredAt: Date

    public init(totalBytes: Int64, bytesByProfile: [UUID: Int64], availableDiskBytes: Int64, measuredAt: Date = .now) {
        self.totalBytes = totalBytes
        self.bytesByProfile = bytesByProfile
        self.availableDiskBytes = availableDiskBytes
        self.measuredAt = measuredAt
    }

    public static let empty = CacheUsageSnapshot(totalBytes: 0, bytesByProfile: [:], availableDiskBytes: 0)
}

public enum CacheUsageError: Error, Equatable {
    case profileMounted
    case unsafePath
}

public struct CacheUsageService: Sendable {
    private let sizeService = DirectorySizeService()

    public init() {}

    public func snapshot(cacheRoot: URL, profileIDs: [UUID]) throws -> CacheUsageSnapshot {
        var usage: [UUID: Int64] = [:]
        for profileID in profileIDs {
            try checkCancellation()
            usage[profileID] = try sizeService.allocatedBytes(at: cacheRoot.appendingPathComponent(profileID.uuidString, isDirectory: true))
        }
        let total = try sizeService.allocatedBytes(at: cacheRoot)
        let volumeURL = FileManager.default.fileExists(atPath: cacheRoot.path) ? cacheRoot : cacheRoot.deletingLastPathComponent()
        let available = try? volumeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
        return CacheUsageSnapshot(totalBytes: total, bytesByProfile: usage, availableDiskBytes: Int64(available ?? 0))
    }

    public func clear(profileID: UUID, cacheRoot: URL, isMounted: Bool) throws {
        guard !isMounted else { throw CacheUsageError.profileMounted }
        let safeRoot = cacheRoot.standardizedFileURL.resolvingSymlinksInPath()
        let requested = safeRoot.appendingPathComponent(profileID.uuidString, isDirectory: true).standardizedFileURL
        let resolved = requested.resolvingSymlinksInPath()
        guard requested.lastPathComponent == profileID.uuidString,
              resolved.deletingLastPathComponent() == safeRoot else {
            throw CacheUsageError.unsafePath
        }
        guard FileManager.default.fileExists(atPath: requested.path) else { return }
        try FileManager.default.removeItem(at: requested)
    }

    private func checkCancellation() throws {
        if Task.isCancelled { throw CancellationError() }
    }
}
