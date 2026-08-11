import Foundation

public enum MountStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case mounted
    case reconnecting(attempt: Int, delay: TimeInterval)
    case disconnecting
    case failed(String)

    public var localizationKey: String {
        switch self {
        case .disconnected: return "mount.status.disconnected"
        case .connecting: return "mount.status.connecting"
        case .mounted: return "mount.status.mounted"
        case .reconnecting: return "mount.status.reconnecting"
        case .disconnecting: return "mount.status.disconnecting"
        case .failed: return "mount.status.failed"
        }
    }

    public var message: String {
        switch self {
        case .disconnected: return "Non connesso"
        case .connecting: return "Connessione in corso"
        case .mounted: return "Montato"
        case let .reconnecting(attempt, _): return "Riconnessione (tentativo \(attempt))"
        case .disconnecting: return "Smontaggio in corso"
        case let .failed(message): return message
        }
    }
}
