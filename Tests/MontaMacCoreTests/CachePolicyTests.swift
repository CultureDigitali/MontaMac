import XCTest
@testable import MontaMacCore

final class CachePolicyTests: XCTestCase {
    func testDefaultPolicyUsesFiveGigabytesAndReservedFreeSpace() {
        let policy = CachePolicy.default

        XCTAssertEqual(policy.limit, .fiveGB)
        XCTAssertEqual(policy.reservedFreeSpaceGB, 5)
        XCTAssertEqual(policy.rcloneArguments, [
            "--vfs-cache-max-size", "5G",
            "--min-free-space", "5G",
        ])
    }

    func testUnlimitedPolicyOmitsMaximumSize() {
        let policy = CachePolicy(limit: .unlimited, reservedFreeSpaceGB: 8)

        XCTAssertEqual(policy.rcloneArguments, ["--min-free-space", "8G"])
    }

    func testProfileOverrideWinsOverGlobalLimit() {
        var connection = RemoteConnection.blank(protocolType: .sftp)
        connection.cacheLimit = .twentyFiveGB

        XCTAssertEqual(CachePolicyResolver(defaultLimit: .oneGB, reservedFreeSpaceGB: 4).policy(for: connection),
                       CachePolicy(limit: .twentyFiveGB, reservedFreeSpaceGB: 4))
    }
}
