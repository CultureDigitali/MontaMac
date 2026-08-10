import Foundation

public enum ActivityEvent: Codable, Identifiable, Sendable {
    case mounted(connectionID: UUID, at: Date)
    case unmounted(connectionID: UUID, at: Date)
    case transfer(connectionID: UUID, bytes: Int64, at: Date)
    case failure(connectionID: UUID, message: String, at: Date)

    public var id: UUID { switch self { case let .mounted(id, _), let .unmounted(id, _), let .transfer(id, _, _), let .failure(id, _, _): return id } }
    public var date: Date { switch self { case let .mounted(_, at), let .unmounted(_, at), let .transfer(_, _, at), let .failure(_, _, at): return at } }
    public var title: String { switch self { case .mounted: return "Drive montato"; case .unmounted: return "Drive smontato"; case .transfer: return "Trasferimento completato"; case let .failure(_, message, _): return message } }
}

public struct ActivitySummary: Sendable {
    public var transferredBytes: Int64 = 0
    public var failureCount: Int = 0
    public var mountedSeconds: TimeInterval = 0
    public var mountCount: Int = 0
    public init(transferredBytes: Int64 = 0, failureCount: Int = 0, mountedSeconds: TimeInterval = 0, mountCount: Int = 0) { self.transferredBytes = transferredBytes; self.failureCount = failureCount; self.mountedSeconds = mountedSeconds; self.mountCount = mountCount }
}

public final class ActivityStore {
    public let fileURL: URL
    public init(fileURL: URL = ConnectionStore.defaultURL.deletingLastPathComponent().appendingPathComponent("activity.json")) { self.fileURL = fileURL }
    public func record(_ event: ActivityEvent) throws { var events = try allEvents(); events.append(event); try save(events) }
    public func recentEvents(limit: Int = 20) throws -> [ActivityEvent] { Array(try allEvents().sorted { $0.date > $1.date }.prefix(limit)) }
    public func summary(since: Date) throws -> ActivitySummary {
        let events = try allEvents().filter { $0.date >= since }; var result = ActivitySummary()
        for event in events { switch event { case .mounted: result.mountCount += 1; case let .transfer(_, bytes, _): result.transferredBytes += bytes; case .failure: result.failureCount += 1; default: break } }
        return result
    }
    private func allEvents() throws -> [ActivityEvent] { try? SecureFileStore.secureExistingFile(fileURL); guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }; return try JSONDecoder().decode([ActivityEvent].self, from: Data(contentsOf: fileURL)) }
    private func save(_ events: [ActivityEvent]) throws { try SecureFileStore.write(JSONEncoder().encode(Array(events.suffix(500))), to: fileURL) }
}
