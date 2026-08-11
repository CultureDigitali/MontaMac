import XCTest
@testable import MontaMacCore

final class RcloneServiceTests: XCTestCase {
    func testMountArgumentsKeepMountPathAsOneArgument() {
        let connection = RemoteConnection(name: "Archivio", protocolType: .sftp, host: "files.example.com", port: 22, username: "anna", remotePath: "/", mountPath: "/Users/anna/Remote Files")
        let arguments = RcloneService(rcloneURL: URL(fileURLWithPath: "/usr/local/bin/rclone")).mountArguments(
            for: connection,
            configURL: URL(fileURLWithPath: "/tmp/rclone.conf"),
            cacheDirectory: URL(fileURLWithPath: "/tmp/cache"),
            cachePolicy: CachePolicy(limit: .tenGB, reservedFreeSpaceGB: 7)
        )

        XCTAssertTrue(arguments.contains("/Users/anna/Remote Files"))
        XCTAssertEqual(arguments[0], "nfsmount")
        XCTAssertTrue(arguments.contains("--umask"))
        XCTAssertTrue(arguments.contains("077"))
        XCTAssertTrue(arguments.contains("--vfs-cache-max-age"))
        XCTAssertTrue(arguments.contains("1h"))
        XCTAssertTrue(arguments.contains("/tmp/cache"))
        XCTAssertTrue(arguments.contains("--stats"))
        XCTAssertTrue(arguments.contains("1s"))
        XCTAssertTrue(arguments.contains("--use-json-log"))
        XCTAssertFalse(arguments.contains("--stats-one-line"))
        XCTAssertTrue(arguments.contains("--stats-log-level"))
        XCTAssertTrue(arguments.contains("NOTICE"))
        XCTAssertEqual(arguments[arguments.firstIndex(of: "--vfs-cache-max-size")! + 1], "10G")
        XCTAssertEqual(arguments[arguments.firstIndex(of: "--min-free-space")! + 1], "7G")
    }
}
