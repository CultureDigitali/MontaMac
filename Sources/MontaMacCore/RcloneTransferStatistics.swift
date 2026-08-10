import Foundation

public enum RcloneTransferStatisticsParser {
    public static func totalBytes(from line: String) -> Int64? {
        guard let marker = line.range(of: "Transferred:", options: .caseInsensitive) else { return nil }
        let value = line[marker.upperBound...].split(separator: "/", maxSplits: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let components = value.split(whereSeparator: \Character.isWhitespace)
        guard components.count >= 2,
              let amount = Double(components[0].replacingOccurrences(of: ",", with: ".")),
              amount.isFinite,
              amount >= 0,
              let multiplier = multiplier(for: String(components[1])) else { return nil }
        let bytes = amount * multiplier
        guard bytes <= Double(Int64.max) else { return nil }
        return Int64(bytes.rounded())
    }

    private static func multiplier(for unit: String) -> Double? {
        switch unit.lowercased() {
        case "b", "byte", "bytes": return 1
        case "kib": return 1_024
        case "mib": return 1_048_576
        case "gib": return 1_073_741_824
        case "tib": return 1_099_511_627_776
        case "kb": return 1_000
        case "mb": return 1_000_000
        case "gb": return 1_000_000_000
        case "tb": return 1_000_000_000_000
        default: return nil
        }
    }
}

public struct TransferProgressTracker: Sendable {
    private var previousTotal: Int64?

    public init() {}

    public mutating func consume(totalBytes: Int64) -> Int64 {
        guard totalBytes >= 0 else { return 0 }
        defer { previousTotal = totalBytes }
        guard let previousTotal else { return totalBytes }
        return totalBytes >= previousTotal ? totalBytes - previousTotal : totalBytes
    }

    public mutating func reset() {
        previousTotal = nil
    }
}
