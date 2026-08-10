import Security
import XCTest
@testable import MontaMacCore

final class CredentialStoreTests: XCTestCase {
    func testNewPasswordIsAvailableOnlyWhileUserIsUnlocked() {
        let query = CredentialStore.makeAddQuery(password: "secret", id: UUID())
        XCTAssertEqual(query[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlocked as String)
    }
}
