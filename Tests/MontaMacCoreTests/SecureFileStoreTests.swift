import Foundation
import XCTest
@testable import MontaMacCore

final class SecureFileStoreTests: XCTestCase {
    func testWriteCreatesPrivateDirectoryAndFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = root.appendingPathComponent("connections.json")
        defer { try? FileManager.default.removeItem(at: root) }

        try SecureFileStore.write(Data("[]".utf8), to: file)

        XCTAssertEqual(try permissions(root), 0o700)
        XCTAssertEqual(try permissions(file), 0o600)
    }

    func testSecureExistingFileRepairsLoosePermissions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = root.appendingPathComponent("activity.json")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)

        try SecureFileStore.secureExistingFile(file)

        XCTAssertEqual(try permissions(root), 0o700)
        XCTAssertEqual(try permissions(file), 0o600)
    }

    private func permissions(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }
}
