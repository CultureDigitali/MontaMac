import Foundation

public enum SensitiveLogRedactor {
    public static func redact(_ message: String, for connection: RemoteConnection) -> String {
        [connection.mountPath, connection.host, connection.username]
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
            .reduce(message) { partial, secret in
                partial.replacingOccurrences(of: secret, with: "[dato protetto]", options: .caseInsensitive)
            }
    }
}
