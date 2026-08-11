import XCTest
@testable import MontaMacCore

final class MountStatusTests: XCTestCase {
    func testFailureStateKeepsItsMessage() {
        XCTAssertEqual(MountStatus.failed("rclone non trovato").message, "rclone non trovato")
    }

    func testReconnectingStateKeepsAttemptAndStableLocalizationKey() {
        let status = MountStatus.reconnecting(attempt: 2, delay: 5)

        XCTAssertEqual(status, .reconnecting(attempt: 2, delay: 5))
        XCTAssertEqual(status.localizationKey, "mount.status.reconnecting")
    }

    func testCacheCleanupIsAllowedOnlyWhenDisconnected() {
        XCTAssertTrue(MountStatus.disconnected.allowsCacheCleanup)
        XCTAssertFalse(MountStatus.failed("still mounted").allowsCacheCleanup)
        XCTAssertFalse(MountStatus.mounted.allowsCacheCleanup)
        XCTAssertFalse(MountStatus.connecting.allowsCacheCleanup)
    }
}
