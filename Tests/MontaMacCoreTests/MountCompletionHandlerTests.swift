import Foundation
import XCTest
@testable import MontaMacCore

final class MountCompletionHandlerTests: XCTestCase {
    @MainActor
    func testMountedConnectionOpensExactConfiguredPathOnce() {
        var openedURLs: [URL] = []
        let handler = MountCompletionHandler { url in
            openedURLs.append(url)
            return true
        }
        let connection = makeConnection()

        let outcome = handler.handle(status: .mounted, connection: connection)

        XCTAssertEqual(openedURLs, [URL(fileURLWithPath: "/tmp/MontaMac Drive")])
        XCTAssertEqual(outcome, .opened(URL(fileURLWithPath: "/tmp/MontaMac Drive")))
    }

    @MainActor
    func testFailedMountDoesNotOpenFinder() {
        var openCount = 0
        let handler = MountCompletionHandler { _ in
            openCount += 1
            return true
        }

        let outcome = handler.handle(status: .failed("errore"), connection: makeConnection())

        XCTAssertEqual(openCount, 0)
        XCTAssertEqual(outcome, .skipped)
    }

    @MainActor
    func testFinderFailureIsReportedSeparately() {
        let handler = MountCompletionHandler { _ in false }
        let expectedURL = URL(fileURLWithPath: "/tmp/MontaMac Drive")

        XCTAssertEqual(
            handler.handle(status: .mounted, connection: makeConnection()),
            .openFailed(expectedURL)
        )
    }

    private func makeConnection() -> RemoteConnection {
        RemoteConnection(
            name: "Test",
            protocolType: .ftp,
            host: "example.test",
            port: 21,
            username: "user",
            remotePath: "/",
            mountPath: "/tmp/MontaMac Drive"
        )
    }
}
