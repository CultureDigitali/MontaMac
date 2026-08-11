import XCTest
@testable import MontaMacCore

final class ConnectionStoreCompatibilityTests: XCTestCase {
    func testLegacyConnectionDecodesProfileDefaults() throws {
        let json = #"[{"id":"00000000-0000-0000-0000-000000000001","name":"Archivio","protocolType":"sftp","host":"host.example","port":22,"username":"anna","remotePath":"/","mountPath":"/Users/anna/MontaMac/archivio"}]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([RemoteConnection].self, from: json)

        XCTAssertEqual(decoded[0].profileGroup, "Senza cartella")
        XCTAssertFalse(decoded[0].isFavorite)
        XCTAssertNil(decoded[0].lastUsedAt)
        XCTAssertNil(decoded[0].cacheLimit)
    }

    func testMarkUsedStoresProvidedDate() {
        var profile = RemoteConnection.blank(protocolType: .ftp)
        let date = Date(timeIntervalSinceReferenceDate: 10)

        profile.markUsed(at: date)

        XCTAssertEqual(profile.lastUsedAt, date)
    }
}
