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

    func testRcloneStatisticsUpdateTransferTotalsAcrossOutputChunks() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mountPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MontaMacTests/\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: mountPath)
        }
        let rclone = FakeRcloneService()
        let coordinator = MountCoordinator(
            credentials: FakeCredentials(),
            rclone: rclone,
            monitor: FakeMountMonitor(isMounted: false, waitResult: true),
            configurationDirectory: root.appendingPathComponent("configs"),
            cacheRoot: root.appendingPathComponent("cache")
        )
        let connection = makeConnection(mountPath: mountPath.path)

        await coordinator.mount(connection)
        rclone.emit("Transferred: 2 Ki")
        rclone.emit("B / 4 KiB, 50%, 0 B/s, ETA -\n")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(coordinator.transferTotals[connection.id], 2_048)
    }

    func testUnexpectedProcessExitRemountsOnceAndReturnsToMounted() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mountPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MontaMacTests/\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: mountPath)
        }
        let rclone = FakeRcloneService()
        let coordinator = MountCoordinator(
            credentials: FakeCredentials(),
            rclone: rclone,
            monitor: FakeMountMonitor(isMounted: false, waitResult: true),
            configurationDirectory: root.appendingPathComponent("configs"),
            cacheRoot: root.appendingPathComponent("cache"),
            recoveryPolicy: MountRecoveryPolicy(delays: [0]),
            sleeper: { _ in },
            healthCheckInterval: nil
        )
        let connection = makeConnection(mountPath: mountPath.path)

        await coordinator.mount(connection)
        rclone.processes[0].exit(9)
        for _ in 0..<8 { await Task.yield() }

        XCTAssertEqual(rclone.startCount, 2)
        XCTAssertEqual(coordinator.status(for: connection), .mounted)
        XCTAssertEqual(coordinator.retryAttempt(for: connection), 0)
    }

    func testManualUnmountCancelsRecoveryAndNeverStartsAnotherProcess() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mountPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MontaMacTests/\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: mountPath)
        }
        let rclone = FakeRcloneService()
        let coordinator = MountCoordinator(
            credentials: FakeCredentials(),
            rclone: rclone,
            monitor: FakeMountMonitor(isMounted: false, waitResult: true),
            configurationDirectory: root.appendingPathComponent("configs"),
            cacheRoot: root.appendingPathComponent("cache"),
            recoveryPolicy: MountRecoveryPolicy(delays: [60]),
            sleeper: { _ in try? await Task.sleep(for: .seconds(60)) },
            healthCheckInterval: nil
        )
        let connection = makeConnection(mountPath: mountPath.path)

        await coordinator.mount(connection)
        rclone.processes[0].exit(9)
        await Task.yield()
        await coordinator.unmount(connection)
        for _ in 0..<4 { await Task.yield() }

        XCTAssertEqual(rclone.startCount, 1)
        XCTAssertEqual(coordinator.status(for: connection), .disconnected)
    }

    func testExhaustedRecoveryPolicyLeavesProfileFailed() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mountPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MontaMacTests/\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: mountPath)
        }
        let rclone = FakeRcloneService()
        let coordinator = MountCoordinator(
            credentials: FakeCredentials(), rclone: rclone,
            monitor: FakeMountMonitor(isMounted: false, waitResult: true),
            configurationDirectory: root.appendingPathComponent("configs"),
            cacheRoot: root.appendingPathComponent("cache"),
            recoveryPolicy: MountRecoveryPolicy(delays: []),
            sleeper: { _ in }, healthCheckInterval: nil
        )
        let connection = makeConnection(mountPath: mountPath.path)

        await coordinator.mount(connection)
        rclone.processes[0].exit(7)
        for _ in 0..<4 { await Task.yield() }

        guard case .failed = coordinator.status(for: connection) else {
            return XCTFail("Expected a terminal failure")
        }
        XCTAssertEqual(rclone.startCount, 1)
    }

    func testHealthCheckRecoversWhenMountDisappears() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mountPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MontaMacTests/\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: mountPath)
        }
        let rclone = FakeRcloneService()
        let monitor = FakeMountMonitor(isMounted: false, waitResult: true)
        let coordinator = MountCoordinator(
            credentials: FakeCredentials(), rclone: rclone, monitor: monitor,
            configurationDirectory: root.appendingPathComponent("configs"),
            cacheRoot: root.appendingPathComponent("cache"),
            recoveryPolicy: MountRecoveryPolicy(delays: [0]),
            sleeper: { _ in }, healthCheckInterval: nil
        )
        let connection = makeConnection(mountPath: mountPath.path)

        await coordinator.mount(connection)
        coordinator.performHealthCheck(for: connection)
        for _ in 0..<8 { await Task.yield() }

        XCTAssertEqual(rclone.startCount, 2)
        XCTAssertEqual(coordinator.status(for: connection), .mounted)
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
    var processes: [FakeMountProcess] = []
    private var outputHandler: (@Sendable (String) -> Void)?

    func mountArguments(for connection: RemoteConnection, configURL: URL, cacheDirectory: URL) -> [String] { [] }
    func startMount(arguments: [String], output: @escaping @Sendable (String) -> Void) throws -> any MountProcessHandling {
        startCount += 1
        if shouldFailStart { throw TestError.startFailed }
        outputHandler = output
        let process = FakeMountProcess()
        processes.append(process)
        return process
    }
    func emit(_ output: String) { outputHandler?(output) }
    func obscure(_ password: String) throws -> String { "obscured" }
    func unmount(at url: URL) throws {}
}

private final class FakeMountProcess: MountProcessHandling {
    var isRunning = true
    private var terminationHandler: (@Sendable (Int32) -> Void)?
    func terminate() { isRunning = false }
    func observeTermination(_ handler: @escaping @Sendable (Int32) -> Void) { terminationHandler = handler }
    func exit(_ status: Int32) { isRunning = false; terminationHandler?(status) }
}

@MainActor
private final class FakeMountMonitor: MountMonitoring {
    let mounted: Bool
    let waitResult: Bool
    init(isMounted: Bool, waitResult: Bool? = nil) {
        mounted = isMounted
        self.waitResult = waitResult ?? isMounted
    }
    func isMounted(at url: URL) -> Bool { mounted }
    func waitUntilMounted(at url: URL, timeout: TimeInterval) async -> Bool { waitResult }
}

private enum TestError: Error { case startFailed }
