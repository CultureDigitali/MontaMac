import Foundation

public struct DiagnosticItem: Identifiable, Sendable {
    public let id = UUID(); public let title: String; public let isPassing: Bool; public let detail: String
}

public struct DiagnosticsService {
    public init() {}
    public func inspect(_ connection: RemoteConnection, rclone: RcloneService = RcloneService()) -> [DiagnosticItem] {
        [
            DiagnosticItem(title: "rclone", isPassing: rclone.isAvailable, detail: rclone.isAvailable ? rclone.rcloneURL.path : "Installa rclone con Homebrew."),
            DiagnosticItem(title: "Configurazione", isPassing: connection.validationError == nil, detail: connection.validationError ?? "Connessione valida."),
            DiagnosticItem(title: "Cartella locale", isPassing: FileManager.default.fileExists(atPath: connection.mountPath), detail: connection.mountPath),
        ]
    }
}
