import XCTest
@testable import MontaMacCore

final class SensitiveLogRedactorTests: XCTestCase {
    func testRedactsConnectionSecretsFromRcloneOutput() {
        let connection = RemoteConnection(name: "Archivio", protocolType: .sftp, host: "secret.example.com", port: 22, username: "anna", remotePath: "/privato", mountPath: "/Users/anna/MontaMac/Archivio")
        let message = "anna@secret.example.com failed at /Users/anna/MontaMac/Archivio/privato"

        let redacted = SensitiveLogRedactor.redact(message, for: connection)

        XCTAssertFalse(redacted.contains("anna"))
        XCTAssertFalse(redacted.contains("secret.example.com"))
        XCTAssertFalse(redacted.contains(connection.mountPath))
        XCTAssertTrue(redacted.contains("[dato protetto]"))
    }
}
