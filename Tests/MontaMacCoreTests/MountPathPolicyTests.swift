import Foundation
import XCTest
@testable import MontaMacCore

final class MountPathPolicyTests: XCTestCase {
    func testSystemPathsAreRejectedButUserPathIsAllowed() {
        let unsafePaths = [
            "/", "/System", "/Library/Test", "/Applications/App",
            "/usr/local", "/bin", "/sbin", "/private/tmp",
            "/tmp/MontaMac", "/Volumes/Shared", "/Users/another-user/MontaMac",
        ]

        for path in unsafePaths {
            XCTAssertNotNil(MountPathPolicy.validationError(for: path), path)
        }
        let ownPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MontaMac/Drive").path
        XCTAssertNil(MountPathPolicy.validationError(for: ownPath))
    }

    func testHomeSymlinkCannotEscapeToTemporaryDirectory() throws {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("MontaMacTests/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let link = root.appendingPathComponent("outside")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/tmp"))
        XCTAssertNotNil(MountPathPolicy.validationError(for: link.appendingPathComponent("drive").path))
    }
}
