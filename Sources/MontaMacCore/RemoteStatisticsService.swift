import Foundation

public struct RemoteStatistics: Sendable, Equatable {
    public var fileCount: Int
    public var totalBytes: Int64
    public var scannedAt: Date
    public init(fileCount: Int, totalBytes: Int64, scannedAt: Date = .now) { self.fileCount = fileCount; self.totalBytes = totalBytes; self.scannedAt = scannedAt }
    public var formattedSize: String { ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file) }
}

public enum RemoteStatisticsError: LocalizedError { case invalidOutput
    public var errorDescription: String? { "Le statistiche remote non sono disponibili." }
}

public final class RemoteStatisticsService {
    public init() {}
    public static func parseSizeOutput(_ output: String) throws -> RemoteStatistics {
        let objects = output.split(separator: "\n").first { $0.lowercased().contains("total objects:") }?.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? ""
        let size = output.split(separator: "\n").first { $0.lowercased().contains("total size:") }?.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? ""
        guard let count = Int(objects) else { throw RemoteStatisticsError.invalidOutput }
        let components = size.split(separator: " "); guard components.count >= 2, let amount = Double(components[0].replacingOccurrences(of: ",", with: ".")) else { throw RemoteStatisticsError.invalidOutput }
        let unit = components[1].lowercased(); let multiplier: Double = unit.hasPrefix("gib") ? 1_073_741_824 : unit.hasPrefix("mib") ? 1_048_576 : unit.hasPrefix("kib") ? 1024 : 1
        return RemoteStatistics(fileCount: count, totalBytes: Int64(amount * multiplier))
    }

    public func scanMountedFolder(at url: URL) async throws -> RemoteStatistics {
        guard FileManager.default.fileExists(atPath: url.path) else { throw RemoteStatisticsError.invalidOutput }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        var count = 0; var bytes: Int64 = 0
        while let file = enumerator?.nextObject() as? URL {
            let values = try file.resourceValues(forKeys: keys)
            if values.isRegularFile == true { count += 1; bytes += Int64(values.fileSize ?? 0) }
        }
        return RemoteStatistics(fileCount: count, totalBytes: bytes)
    }
}
