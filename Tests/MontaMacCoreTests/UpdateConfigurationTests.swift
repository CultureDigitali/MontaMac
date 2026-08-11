import XCTest
@testable import MontaMacCore

final class UpdateConfigurationTests: XCTestCase {
    func testRequiresHTTPSFeedAndPublicKey() {
        XCTAssertFalse(UpdateConfiguration(feedURLString: nil, publicKey: nil).isConfigured)
        XCTAssertFalse(UpdateConfiguration(feedURLString: "http://example.com/appcast.xml", publicKey: "key").isConfigured)
        XCTAssertFalse(UpdateConfiguration(feedURLString: "https://example.com/appcast.xml", publicKey: "").isConfigured)
        XCTAssertTrue(UpdateConfiguration(feedURLString: "https://example.com/appcast.xml", publicKey: "key").isConfigured)
    }

    func testAutomaticChecksRequireConfigurationAndPreference() {
        let configured = UpdateConfiguration(feedURLString: "https://example.com/appcast.xml", publicKey: "key")

        XCTAssertTrue(configured.canCheckAutomatically(userEnabled: true))
        XCTAssertFalse(configured.canCheckAutomatically(userEnabled: false))
        XCTAssertFalse(UpdateConfiguration(feedURLString: nil, publicKey: nil).canCheckAutomatically(userEnabled: true))
    }
}
