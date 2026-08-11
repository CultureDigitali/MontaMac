import XCTest
@testable import MontaMacCore

final class AppCommandAvailabilityTests: XCTestCase {
    func testNoSelectionDisablesDriveCommands() {
        let state = AppCommandAvailability(hasSelection: false, status: .disconnected)

        XCTAssertFalse(state.canEdit)
        XCTAssertFalse(state.canDelete)
        XCTAssertFalse(state.canMount)
        XCTAssertFalse(state.canUnmount)
        XCTAssertFalse(state.canOpenFinder)
    }

    func testMountedSelectionEnablesUnmountAndFinder() {
        let state = AppCommandAvailability(hasSelection: true, status: .mounted)

        XCTAssertFalse(state.canMount)
        XCTAssertTrue(state.canUnmount)
        XCTAssertTrue(state.canOpenFinder)
        XCTAssertTrue(state.canRefreshStatistics)
        XCTAssertFalse(state.canDelete)
    }

    func testReconnectingSelectionCanBeCancelledButNotEdited() {
        let availability = AppCommandAvailability(
            hasSelection: true,
            status: .reconnecting(attempt: 1, delay: 2)
        )

        XCTAssertFalse(availability.canMount)
        XCTAssertTrue(availability.canUnmount)
        XCTAssertFalse(availability.canEdit)
        XCTAssertFalse(availability.canDelete)
        XCTAssertFalse(availability.canOpenFinder)
    }

    func testDisconnectedSelectionEnablesMountOnly() {
        let state = AppCommandAvailability(hasSelection: true, status: .disconnected)

        XCTAssertTrue(state.canMount)
        XCTAssertFalse(state.canUnmount)
        XCTAssertFalse(state.canOpenFinder)
        XCTAssertTrue(state.canEdit)
    }
}
