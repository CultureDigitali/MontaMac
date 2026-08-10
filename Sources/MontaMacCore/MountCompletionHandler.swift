import Foundation

public enum MountCompletionOutcome: Equatable {
    case skipped
    case opened(URL)
    case openFailed(URL)
}

@MainActor
public struct MountCompletionHandler {
    private let openFolder: (URL) -> Bool

    public init(openFolder: @escaping (URL) -> Bool) {
        self.openFolder = openFolder
    }

    public func handle(status: MountStatus, connection: RemoteConnection) -> MountCompletionOutcome {
        guard case .mounted = status else { return .skipped }
        let url = URL(fileURLWithPath: connection.mountPath)
        return openFolder(url) ? .opened(url) : .openFailed(url)
    }
}
