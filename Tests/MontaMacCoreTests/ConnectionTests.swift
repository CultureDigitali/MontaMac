import XCTest
@testable import MontaMacCore

final class ConnectionTests: XCTestCase {
    func testConnectionRequiresHostAndAbsoluteMountPath() {
        var connection = RemoteConnection.blank(protocolType: .sftp)
        connection.host = ""
        connection.mountPath = "Documents/Server"

        XCTAssertEqual(connection.validationError, "Inserisci un host valido e un percorso locale assoluto.")
    }

    func testRemoteSpecIncludesConfiguredRemotePath() {
        let id = UUID(uuidString: "13ADFB99-EE60-4FA3-8AA7-3E47A402EEB6")!
        let connection = RemoteConnection(id: id, name: "Archivio", protocolType: .sftp, host: "files.example.com", port: 22, username: "anna", remotePath: "/progetti", mountPath: "/Users/anna/Archivio")
        XCTAssertEqual(connection.remoteSpec, "montamac_13adfb99ee604fa38aa73e47a402eeb6:/progetti")
    }

    func testDisplayNameMayContainConfigurationCharacters() {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MontaMac/Archivio").path
        let connection = RemoteConnection(name: "Nome ] = [ libero", protocolType: .sftp, host: "files.example.com", port: 22, username: "anna", remotePath: "/", mountPath: path)
        XCTAssertNil(connection.validationError)
    }
}
