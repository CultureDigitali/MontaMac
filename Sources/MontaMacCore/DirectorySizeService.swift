import Foundation

public struct DirectorySizeService: Sendable {
    public init() {}

    public func allocatedBytes(at root: URL) throws -> Int64 {
        guard FileManager.default.fileExists(atPath: root.path) else { return 0 }
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        ) else { return 0 }

        var bytes: Int64 = 0
        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled { throw CancellationError() }
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isSymbolicLink != true,
                  values.isRegularFile == true else { continue }
            bytes += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
        }
        return bytes
    }
}
