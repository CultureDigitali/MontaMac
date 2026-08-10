import Foundation

public final class ConnectionStore {
    public let fileURL: URL

    public init(fileURL: URL = ConnectionStore.defaultURL) { self.fileURL = fileURL }

    public static var defaultURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MontaMac", isDirectory: true)
        return directory.appendingPathComponent("connections.json")
    }

    public func load() throws -> [RemoteConnection] {
        try? SecureFileStore.secureExistingFile(fileURL)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([RemoteConnection].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ connections: [RemoteConnection]) throws {
        let data = try JSONEncoder().encode(connections)
        try SecureFileStore.write(data, to: fileURL)
    }
}
