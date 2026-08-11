import XCTest
@testable import MontaMacCore

final class MountRecoveryPolicyTests: XCTestCase {
    func testDefaultPolicyStopsAfterThreeAttempts() {
        let policy = MountRecoveryPolicy()

        XCTAssertEqual(policy.delay(forAttempt: 1), 2)
        XCTAssertEqual(policy.delay(forAttempt: 2), 5)
        XCTAssertEqual(policy.delay(forAttempt: 3), 15)
        XCTAssertNil(policy.delay(forAttempt: 4))
        XCTAssertNil(policy.delay(forAttempt: 0))
    }
}
