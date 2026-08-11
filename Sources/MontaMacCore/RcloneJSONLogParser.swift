import Foundation

public struct RcloneJSONLogParser: Sendable {
    private var buffer = ""
    private let maximumBufferSize = 1_048_576

    public init() {}

    public mutating func consume(_ chunk: String) -> [RcloneJSONEvent] {
        buffer.append(chunk)
        guard buffer.utf8.count <= maximumBufferSize else {
            buffer = ""
            return [.log("rclone output exceeded safe buffer")]
        }

        var events: [RcloneJSONEvent] = []
        while let newline = buffer.firstIndex(where: { $0 == "\n" || $0 == "\r" }) {
            let line = String(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard !line.isEmpty else { continue }
            events.append(parse(line))
        }
        return events
    }

    private func parse(_ line: String) -> RcloneJSONEvent {
        guard let data = line.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .log(line)
        }
        guard let stats = root["stats"] as? [String: Any] else {
            return .log(root["msg"] as? String ?? line)
        }
        let transferring = stats["transferring"] as? [[String: Any]] ?? []
        let current = transferring.first
        let etaValue = integer(stats["eta"]) ?? integer(current?["eta"])
        return .statistics(TransferSnapshot(
            bytes: integer(stats["bytes"]) ?? 0,
            totalBytes: integer(stats["totalBytes"]),
            speedBytesPerSecond: number(stats["speed"]) ?? number(current?["speed"]) ?? 0,
            etaSeconds: etaValue.flatMap { $0 >= 0 ? Int($0) : nil },
            activeTransfers: transferring.count,
            currentFile: current?["name"] as? String
        ))
    }

    private func integer(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber { return number.int64Value }
        return nil
    }

    private func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }
}
