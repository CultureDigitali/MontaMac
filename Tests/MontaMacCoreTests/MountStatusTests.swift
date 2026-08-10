import XCTest
@testable import MontaMacCore

final class MountStatusTests: XCTestCase {
    func testFailureStateKeepsItsMessage() {
        XCTAssertEqual(MountStatus.failed("rclone non trovato").message, "rclone non trovato")
    }
}
