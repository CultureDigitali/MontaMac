import Foundation
import XCTest
@testable import MontaMacCore

final class LocalDataSecurityMigrationTests: XCTestCase {
    func testRepairsExistingApplicationDataAtStartup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let connections = root.appendingPathComponent("connections.json")
        let activity = root.appendingPathComponent("activity.json")
        let staleInstaller = root.appendingPathComponent("install-requirements.command")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: connections)
        try Data("[]".utf8).write(to: activity)
        try Data("old installer".utf8).write(to: staleInstaller)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: connections.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: activity.path)

        try LocalDataSecurityMigration(directory: root, sensitiveFiles: [connections, activity]).run()

        XCTAssertEqual(try permissions(root), 0o700)
        XCTAssertEqual(try permissions(connections), 0o600)
        XCTAssertEqual(try permissions(activity), 0o600)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleInstaller.path))
    }

    private func permissions(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }
}
