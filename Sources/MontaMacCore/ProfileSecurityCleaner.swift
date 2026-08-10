import Foundation

public final class ProfileSecurityCleaner {
    private let credentials: CredentialStoring
    private let configurationDirectory: URL
    private let cacheRoot: URL

    public init(
        credentials: CredentialStoring = CredentialStore(),
        configurationDirectory: URL = ConnectionStore.defaultURL.deletingLastPathComponent().appendingPathComponent("rclone"),
        cacheRoot: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MontaMac", isDirectory: true)
    ) {
        self.credentials = credentials
        self.configurationDirectory = configurationDirectory
        self.cacheRoot = cacheRoot
    }

    public func clean(_ connection: RemoteConnection) throws {
        try credentials.deletePassword(for: connection.id)
        try removeIfPresent(configurationDirectory.appendingPathComponent("\(connection.id.uuidString).conf"))
        try removeIfPresent(cacheRoot.appendingPathComponent(connection.id.uuidString, isDirectory: true))
    }

    private func removeIfPresent(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
