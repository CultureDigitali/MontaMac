import Foundation

public struct LocalDataSecurityMigration {
    private let directory: URL
    private let sensitiveFiles: [URL]

    public init(
        directory: URL = ConnectionStore.defaultURL.deletingLastPathComponent(),
        sensitiveFiles: [URL]? = nil
    ) {
        self.directory = directory
        self.sensitiveFiles = sensitiveFiles ?? [
            directory.appendingPathComponent("connections.json"),
            directory.appendingPathComponent("activity.json"),
        ]
    }

    public func run() throws {
        try SecureFileStore.secureDirectory(directory)
        for file in sensitiveFiles {
            try SecureFileStore.secureExistingFile(file)
        }
        let staleInstaller = directory.appendingPathComponent("install-requirements.command")
        if FileManager.default.fileExists(atPath: staleInstaller.path) {
            try FileManager.default.removeItem(at: staleInstaller)
        }
        let rcloneDirectory = directory.appendingPathComponent("rclone", isDirectory: true)
        if FileManager.default.fileExists(atPath: rcloneDirectory.path) {
            try SecureFileStore.secureDirectory(rcloneDirectory)
            for file in try FileManager.default.contentsOfDirectory(at: rcloneDirectory, includingPropertiesForKeys: nil) where file.pathExtension == "conf" {
                try SecureFileStore.secureExistingFile(file)
            }
        }
    }
}
