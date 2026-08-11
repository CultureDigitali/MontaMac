import Foundation

public struct TransferSnapshot: Equatable, Sendable {
    public let bytes: Int64
    public let totalBytes: Int64?
    public let speedBytesPerSecond: Double
    public let etaSeconds: Int?
    public let activeTransfers: Int
    public let currentFile: String?

    public init(bytes: Int64, totalBytes: Int64?, speedBytesPerSecond: Double, etaSeconds: Int?, activeTransfers: Int, currentFile: String?) {
        self.bytes = bytes
        self.totalBytes = totalBytes
        self.speedBytesPerSecond = speedBytesPerSecond
        self.etaSeconds = etaSeconds
        self.activeTransfers = activeTransfers
        self.currentFile = currentFile
    }

    public var progress: Double? {
        guard let totalBytes, totalBytes > 0 else { return nil }
        return min(1, max(0, Double(bytes) / Double(totalBytes)))
    }

    public static let idle = TransferSnapshot(bytes: 0, totalBytes: nil, speedBytesPerSecond: 0, etaSeconds: nil, activeTransfers: 0, currentFile: nil)
}

public enum RcloneJSONEvent: Equatable, Sendable {
    case statistics(TransferSnapshot)
    case log(String)
}
