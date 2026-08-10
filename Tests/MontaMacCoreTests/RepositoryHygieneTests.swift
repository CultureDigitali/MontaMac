import Foundation
import XCTest

final class RepositoryHygieneTests: XCTestCase {
    func testSensitiveAndGeneratedPathsAreIgnoredByGit() throws {
        let projectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: projectRoot.appendingPathComponent(".gitignore"), to: root.appendingPathComponent(".gitignore"))
        try runGit(["init", "-q"], in: root)

        let paths = [
            ".build/file", "MontaMac.app/Contents/file", "dist/MontaMac.pkg",
            "OLD/releases/old.pkg", ".superpowers/brainstorm/token", ".env.local",
            "connections.json", "activity.json", "rclone/profile.conf",
            "certificate.p12", "certificate.pem",
        ]
        for path in paths {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("synthetic test data".utf8).write(to: url)
            try runGit(["check-ignore", "--quiet", path], in: root)
        }
    }

    private func runGit(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "git \(arguments.joined(separator: " "))")
    }
}
