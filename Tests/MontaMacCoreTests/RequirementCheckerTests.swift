import XCTest
@testable import MontaMacCore

final class RequirementCheckerTests: XCTestCase {
    func testMissingFUSERequiresOnlyFUSEInstallCommand() {
        let statuses = RequirementChecker(executables: ["brew", "rclone"]).check()
        XCTAssertEqual(RequirementChecker.installationCommand(for: statuses), "HOMEBREW_NO_INSTALL_CLEANUP=1 brew install --cask fuse-t")
    }

    func testInstallationScriptCompletesWithoutInteractivePrompt() throws {
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".command")
        defer { try? FileManager.default.removeItem(at: scriptURL) }
        try RequirementInstallScript.make(command: "true").write(to: scriptURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path]
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: scriptURL.path))
    }

    func testRcloneDownloadRequiresHTTPSAndFailsClosed() throws {
        let statuses = RequirementChecker(executables: ["brew", "fuse-t"]).check()
        let command = try XCTUnwrap(RequirementChecker.installationCommand(for: statuses))

        XCTAssertTrue(command.contains("--proto '=https'"))
        XCTAssertTrue(command.contains("--tlsv1.2"))
        XCTAssertTrue(command.contains("--fail"))
        XCTAssertTrue(command.contains("https://rclone.org/install.sh"))
    }

    func testFUSEDetectionAcceptsCurrentApplicationPath() {
        let statuses = RequirementChecker(existingPaths: ["/Applications/fuse-t.app"]).check()

        XCTAssertTrue(statuses.first { $0.id == "fuse" }?.isInstalled == true)
    }
}
