import Foundation

public enum MountStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case mounted
    case disconnecting
    case failed(String)

    public var message: String {
        switch self {
        case .disconnected: return "Non connesso"
        case .connecting: return "Connessione in corso"
        case .mounted: return "Montato"
        case .disconnecting: return "Smontaggio in corso"
        case let .failed(message): return message
        }
    }
}
