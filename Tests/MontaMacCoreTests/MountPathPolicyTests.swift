import XCTest
@testable import MontaMacCore

final class MountPathPolicyTests: XCTestCase {
    func testSystemPathsAreRejectedButUserPathIsAllowed() {
        let unsafePaths = [
            "/", "/System", "/Library/Test", "/Applications/App",
            "/usr/local", "/bin", "/sbin", "/private/tmp",
        ]

        for path in unsafePaths {
            XCTAssertNotNil(MountPathPolicy.validationError(for: path), path)
        }
        XCTAssertNil(MountPathPolicy.validationError(for: "/Users/test/MontaMac/Drive"))
    }
}
