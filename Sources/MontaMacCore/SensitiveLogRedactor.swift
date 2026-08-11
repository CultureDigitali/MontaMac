import Foundation

public enum SensitiveLogRedactor {
    public static func redact(_ message: String, for connection: RemoteConnection) -> String {
        redact(message, secrets: [connection.mountPath, connection.host, connection.username])
    }

    public static func redact(_ message: String, secrets: [String]) -> String {
        secrets
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
            .reduce(message) { partial, secret in
                partial.replacingOccurrences(of: secret, with: "[dato protetto]", options: .caseInsensitive)
            }
    }
}
