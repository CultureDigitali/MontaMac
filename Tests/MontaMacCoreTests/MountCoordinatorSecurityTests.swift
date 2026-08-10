import Foundation
import XCTest
@testable import MontaMacCore

@MainActor
final class MountCoordinatorSecurityTests: XCTestCase {
    func testAlreadyMountedConnectionDoesNotStartSecondProcess() async {
        let rclone = FakeRcloneService()
        let monitor = FakeMountMonitor(isMounted: true)
        let coordinator = MountCoordinator(credentials: FakeCredentials(), rclone: rclone, monitor: monitor)
        let connection = makeConnection()

        await coordinator.mount(connection)

        XCTAssertEqual(rclone.startCount, 0)
        XCTAssertEqual(coordinator.status(for: connection), .mounted)
    }

    func testStartFailureRemovesTemporaryConfiguration() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mountPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MontaMacTests/\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: mountPath)
        }
        let rclone = FakeRcloneService(); rclone.shouldFailStart = true
        let coordinator = MountCoordinator(
            credentials: FakeCredentials(),
            rclone: rclone,
            monitor: FakeMountMonitor(isMounted: false),
            configurationDirectory: root.appendingPathComponent("configs"),
            cacheRoot: root.appendingPathComponent("cache")
        )
        let connection = makeConnection(mountPath: mountPath.path)

        await coordinator.mount(connection)

        let config = root.appendingPathComponent("configs/\(connection.id.uuidString).conf")
        let cache = root.appendingPathComponent("cache/\(connection.id.uuidString)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: config.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.path), "La cache resta disponibile per evitare perdita di scritture pendenti")
        XCTAssertEqual(try permissions(root.appendingPathComponent("cache")), 0o700)
        XCTAssertEqual(try permissions(cache), 0o700)
    }

    private func makeConnection(mountPath: String = "/Users/test/MontaMac/Archivio") -> RemoteConnection {
        RemoteConnection(name: "Archivio", protocolType: .sftp, host: "files.example.com", port: 22, username: "anna", remotePath: "/", mountPath: mountPath)
    }

    private func permissions(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }
}

private final class FakeCredentials: CredentialStoring {
    func password(for id: UUID) throws -> String? { "password" }
    func save(password: String, for id: UUID) throws {}
    func deletePassword(for id: UUID) throws {}
}

private final class FakeRcloneService: RcloneServicing {
    var isAvailable = true
    var startCount = 0
    var shouldFailStart = false

    func mountArguments(for connection: RemoteConnection, configURL: URL, cacheDirectory: URL) -> [String] { [] }
    func startMount(arguments: [String], output: @escaping @Sendable (String) -> Void) throws -> Process {
        startCount += 1
        if shouldFailStart { throw TestError.startFailed }
        return Process()
    }
    func obscure(_ password: String) throws -> String { "obscured" }
    func unmount(at url: URL) throws {}
}

@MainActor
private final class FakeMountMonitor: MountMonitoring {
    let mounted: Bool
    init(isMounted: Bool) { mounted = isMounted }
    func isMounted(at url: URL) -> Bool { mounted }
    func waitUntilMounted(at url: URL, timeout: TimeInterval) async -> Bool { mounted }
}

private enum TestError: Error { case startFailed }
