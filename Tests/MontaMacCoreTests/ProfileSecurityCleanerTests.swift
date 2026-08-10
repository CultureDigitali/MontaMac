import Foundation
import XCTest
@testable import MontaMacCore

final class ProfileSecurityCleanerTests: XCTestCase {
    func testCleanupDeletesCredentialConfigurationAndCache() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let connection = makeConnection()
        let config = root.appendingPathComponent("configs/\(connection.id.uuidString).conf")
        let cache = root.appendingPathComponent("cache/\(connection.id.uuidString)")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("secret".utf8).write(to: config, options: .atomic)
        let credentials = DeletingCredentials()
        let cleaner = ProfileSecurityCleaner(credentials: credentials, configurationDirectory: root.appendingPathComponent("configs"), cacheRoot: root.appendingPathComponent("cache"))

        try cleaner.clean(connection)

        XCTAssertEqual(credentials.deletedID, connection.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: config.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cache.path))
    }

    func testCredentialFailureKeepsConfigurationForRetry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let connection = makeConnection()
        let config = root.appendingPathComponent("configs/\(connection.id.uuidString).conf")
        try FileManager.default.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("secret".utf8).write(to: config)
        let cleaner = ProfileSecurityCleaner(credentials: FailingCredentials(), configurationDirectory: root.appendingPathComponent("configs"), cacheRoot: root.appendingPathComponent("cache"))

        XCTAssertThrowsError(try cleaner.clean(connection))
        XCTAssertTrue(FileManager.default.fileExists(atPath: config.path))
    }

    private func makeConnection() -> RemoteConnection {
        RemoteConnection(name: "Archivio", protocolType: .sftp, host: "files.example.com", port: 22, username: "anna", remotePath: "/", mountPath: "/Users/anna/MontaMac/Archivio")
    }
}

private final class DeletingCredentials: CredentialStoring {
    var deletedID: UUID?
    func password(for id: UUID) throws -> String? { nil }
    func save(password: String, for id: UUID) throws {}
    func deletePassword(for id: UUID) throws { deletedID = id }
}

private final class FailingCredentials: CredentialStoring {
    func password(for id: UUID) throws -> String? { nil }
    func save(password: String, for id: UUID) throws {}
    func deletePassword(for id: UUID) throws { throw CleanerTestError.failed }
}

private enum CleanerTestError: Error { case failed }
