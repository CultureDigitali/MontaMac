import XCTest
@testable import MontaMacCore

final class DiagnosticsServiceTests: XCTestCase {
    func testExportReportRedactsConnectionIdentifiers() {
        let connection = RemoteConnection(
            name: "Archivio", protocolType: .sftp, host: "private.example.com",
            port: 22, username: "secret-user", remotePath: "/", mountPath: "/Users/test/MontaMac/private"
        )

        let report = DiagnosticsService().makeReport(
            connection: connection,
            status: .failed("private.example.com unavailable"),
            logs: ["secret-user at /Users/test/MontaMac/private"],
            appVersion: "2.2.0"
        )

        XCTAssertFalse(report.contains("private.example.com"))
        XCTAssertFalse(report.contains("secret-user"))
        XCTAssertFalse(report.contains("/Users/test/MontaMac/private"))
        XCTAssertTrue(report.contains("[dato protetto]"))
    }
}
