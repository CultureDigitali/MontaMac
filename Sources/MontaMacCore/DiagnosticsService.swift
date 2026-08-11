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

    public func makeReport(
        connection: RemoteConnection,
        status: MountStatus,
        logs: [String],
        appVersion: String
    ) -> String {
        let secrets = [connection.host, connection.username, connection.mountPath]
        let safeStatus = SensitiveLogRedactor.redact(status.message, secrets: secrets)
        let safeLogs = logs.map { SensitiveLogRedactor.redact($0, secrets: secrets) }
        return ([
            "MontaMac \(appVersion)",
            "Protocol: \(connection.protocolType.title)",
            "Status: \(safeStatus)",
            "rclone: \(RcloneService().isAvailable ? "available" : "missing")",
            "Recent logs:",
        ] + safeLogs.suffix(50)).joined(separator: "\n")
    }
}
