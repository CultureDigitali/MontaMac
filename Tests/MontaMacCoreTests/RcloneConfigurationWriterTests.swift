import XCTest
@testable import MontaMacCore

final class RcloneConfigurationWriterTests: XCTestCase {
    func testWebDAVUsesURLInsteadOfHost() {
        let connection = RemoteConnection(name: "WebDAV", protocolType: .webdav, host: "files.example.com", port: 443, username: "anna", remotePath: "/", mountPath: "/Users/anna/WebDAV")
        let content = RcloneConfigurationWriter.render(connection: connection, obscuredPassword: "abc")

        XCTAssertTrue(content.contains("url = https://files.example.com:443"))
        XCTAssertFalse(content.contains("host ="))
    }

    func testConfigurationSectionUsesInternalUUIDInsteadOfDisplayName() {
        let id = UUID(uuidString: "13ADFB99-EE60-4FA3-8AA7-3E47A402EEB6")!
        let connection = RemoteConnection(id: id, name: "Nome ] malevolo", protocolType: .sftp, host: "files.example.com", port: 22, username: "anna", remotePath: "/", mountPath: "/Users/anna/Archivio")
        let content = RcloneConfigurationWriter.render(connection: connection, obscuredPassword: "abc")

        XCTAssertTrue(content.contains("[montamac_13adfb99ee604fa38aa73e47a402eeb6]"))
        XCTAssertFalse(content.contains("[Nome ] malevolo]"))
    }
}
