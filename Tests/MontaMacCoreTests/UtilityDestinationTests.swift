import XCTest
@testable import MontaMacCore

final class UtilityDestinationTests: XCTestCase {
    func testSidebarDestinationsHaveStableIdentifiers() {
        XCTAssertEqual(UtilityDestination.allCases.map(\.rawValue), ["dashboard", "transfers", "cache", "issues"])
        XCTAssertEqual(UtilityDestination.transfers.systemImage, "arrow.left.arrow.right.circle.fill")
    }
}
