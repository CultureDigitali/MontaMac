import XCTest
@testable import MontaMacCore

final class CreditsContentTests: XCTestCase {
    func testCreditsExposeVerifiedPublicCompanyContacts() {
        XCTAssertEqual(CreditsContent.creator, "Luigi Strazzullo")
        XCTAssertEqual(CreditsContent.company, "Culture Digitali Srl")
        XCTAssertEqual(CreditsContent.website.absoluteString, "https://culturedigitali.eu/")
        XCTAssertEqual(CreditsContent.email, "info@culturedigitali.eu")
        XCTAssertEqual(CreditsContent.phone, "+39 081 180 88 248")
        XCTAssertEqual(CreditsContent.address, "Via Coroglio 57D, 80124 Napoli")
        XCTAssertEqual(CreditsContent.vatNumber, "IT09465861210")
    }

    func testCreditsBuildSafeContactLinks() {
        XCTAssertEqual(CreditsContent.emailURL?.scheme, "mailto")
        XCTAssertEqual(CreditsContent.phoneURL?.scheme, "tel")
    }
}
