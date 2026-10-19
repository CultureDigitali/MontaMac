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

    func testRepeatedMountRequestDoesNotStartASecondManagedProcess() async {
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
            healthCheckInterval: nil
        )
        let connection = makeConnection(mountPath: mountPath.path)

        await coordinator.mount(connection)
        await coordinator.mount(connection)

        XCTAssertEqual(rclone.startCount, 1)
    }

    func testCacheCleanupBlocksMountUntilCleanupFinishes() async throws {
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
            healthCheckInterval: nil,
            cacheCleaner: { _, _ in try? await Task.sleep(for: .milliseconds(50)) }
        )
        let connection = makeConnection(mountPath: mountPath.path)

        let cleanup = Task { try await coordinator.clearCache(for: connection) }
        for _ in 0..<20 where !coordinator.isCleaningCache(for: connection) { await Task.yield() }
        await coordinator.mount(connection)

        XCTAssertEqual(rclone.startCount, 0)
        try await cleanup.value
        await coordinator.mount(connection)
        XCTAssertEqual(rclone.startCount, 1)
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
        XCTAssertEqual(coordinator.status(for: connection), .failed("mount.failure.start"))
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
        rclone.emit(#"{"level":"notice","stats":{"bytes":2048,"totalBytes":4096,"speed":512,"eta":4,"transferring":[{"name":"a.bin","bytes":2048,"size":4096,"percentage":50,"speed":512,"eta":4}]"#)
        rclone.emit("}}\n")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(coordinator.transferTotals[connection.id], 2_048)
        XCTAssertEqual(coordinator.transferSnapshots[connection.id]?.currentFile, "a.bin")
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
        XCTAssertEqual(coordinator.retryAttempt(for: connection), 1)
    }

    func testExpiredMountProbeCannotTerminateReplacementProcess() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mountPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MontaMacTests/\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: mountPath)
        }
        let rclone = FakeRcloneService()
        let monitor = FirstMountWaitMonitor()
        let coordinator = MountCoordinator(
            credentials: FakeCredentials(), rclone: rclone, monitor: monitor,
            configurationDirectory: root.appendingPathComponent("configs"),
            cacheRoot: root.appendingPathComponent("cache"),
            recoveryPolicy: MountRecoveryPolicy(delays: [0]),
            sleeper: { _ in }, healthCheckInterval: nil
        )
        let connection = makeConnection(mountPath: mountPath.path)

        let original = Task { await coordinator.mount(connection) }
        for _ in 0..<100 where monitor.waitCalls == 0 { await Task.yield() }
        XCTAssertEqual(monitor.waitCalls, 1)
        rclone.processes[0].exit(9)
        for _ in 0..<100 where rclone.startCount < 2 { await Task.yield() }
        XCTAssertEqual(rclone.startCount, 2)
        monitor.finishFirstWait(mounted: false)
        await original.value

        XCTAssertTrue(rclone.processes[1].isRunning)
        XCTAssertEqual(coordinator.status(for: connection), .mounted)
        XCTAssertEqual(rclone.startCount, 2)
    }

    func testStaleProcessStatisticsCannotOverwriteReplacementTransferState() async throws {
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
            recoveryPolicy: MountRecoveryPolicy(delays: [0]),
            sleeper: { _ in }, healthCheckInterval: nil
        )
        let connection = makeConnection(mountPath: mountPath.path)
        await coordinator.mount(connection)
        rclone.processes[0].exit(9)
        for _ in 0..<100 where rclone.startCount < 2 { await Task.yield() }
        XCTAssertEqual(rclone.startCount, 2)

        let stale = #"{"level":"notice","stats":{"bytes":9999,"totalBytes":9999}}"# + "\n"
        rclone.emitFromProcess(0, stale)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(coordinator.transferTotals[connection.id], 0)

        let current = #"{"level":"notice","stats":{"bytes":100,"totalBytes":200}}"# + "\n"
        rclone.emitFromProcess(1, current)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(coordinator.transferTotals[connection.id], 100)
    }

    func testShutdownTerminatesOwnedMountAndStopsRecovery() async throws {
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
            recoveryPolicy: MountRecoveryPolicy(delays: [0]),
            sleeper: { _ in }, healthCheckInterval: nil
        )
        let connection = makeConnection(mountPath: mountPath.path)
        await coordinator.mount(connection)
        XCTAssertTrue(rclone.processes[0].isRunning)
        XCTAssertTrue(FileManager.default.fileExists(atPath: coordinator.configurationURL(for: connection).path))

        coordinator.shutdown()
        XCTAssertFalse(rclone.processes[0].isRunning)
        XCTAssertEqual(rclone.unmountCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: coordinator.configurationURL(for: connection).path))
        rclone.processes[0].exit(9)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(rclone.startCount, 1)
        XCTAssertEqual(coordinator.status(for: connection), .disconnected)
    }

    func testRecoveryBudgetResetsAfterStableWindow() async throws {
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
            recoveryPolicy: MountRecoveryPolicy(delays: [0]),
            sleeper: { _ in }, healthCheckInterval: nil,
            stabilityResetInterval: 0,
            stabilitySleeper: { _ in }
        )
        let connection = makeConnection(mountPath: mountPath.path)

        await coordinator.mount(connection)
        rclone.processes[0].exit(9)
        for _ in 0..<12 { await Task.yield() }

        XCTAssertEqual(coordinator.status(for: connection), .mounted)
        XCTAssertEqual(coordinator.retryAttempt(for: connection), 0)
    }

    func testUnexpectedExitDoesNotRetryWhenAutomaticReconnectIsDisabled() async throws {
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
            recoveryPolicy: MountRecoveryPolicy(delays: [0]),
            sleeper: { _ in }, healthCheckInterval: nil,
            automaticReconnectEnabled: { false }
        )
        let connection = makeConnection(mountPath: mountPath.path)

        await coordinator.mount(connection)
        rclone.processes[0].exit(9)
        for _ in 0..<8 { await Task.yield() }

        XCTAssertEqual(rclone.startCount, 1)
        guard case .failed = coordinator.status(for: connection) else {
            return XCTFail("Expected a terminal failure")
        }
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

    func testFailedUnmountRemainsMountedSoUserCanRetry() async {
        let rclone = FakeRcloneService()
        rclone.shouldFailUnmount = true
        let coordinator = MountCoordinator(
            credentials: FakeCredentials(),
            rclone: rclone,
            monitor: FakeMountMonitor(isMounted: true),
            healthCheckInterval: 60
        )
        let connection = makeConnection()
        coordinator.reconcile([connection])

        await coordinator.unmount(connection)

        XCTAssertEqual(coordinator.status(for: connection), .mounted)
        XCTAssertTrue(coordinator.isHealthMonitoring(connection))
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

    func testRepeatedShortLivedRecoveriesRemainBounded() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mountPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MontaMacTests/\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: mountPath)
        }
        let rclone = FakeRcloneService()
        var reportedIssues: [AppIssue] = []
        let coordinator = MountCoordinator(
            credentials: FakeCredentials(), rclone: rclone,
            monitor: FakeMountMonitor(isMounted: false, waitResult: true),
            configurationDirectory: root.appendingPathComponent("configs"),
            cacheRoot: root.appendingPathComponent("cache"),
            recoveryPolicy: MountRecoveryPolicy(delays: [0, 0, 0]),
            sleeper: { _ in }, healthCheckInterval: nil,
            issueHandler: { reportedIssues.append($0) }
        )
        let connection = makeConnection(mountPath: mountPath.path)

        await coordinator.mount(connection)
        for index in 0..<4 {
            rclone.processes[index].exit(9)
            for _ in 0..<8 { await Task.yield() }
        }

        XCTAssertEqual(rclone.startCount, 4)
        guard case .failed = coordinator.status(for: connection) else {
            return XCTFail("Expected bounded recovery failure")
        }
        XCTAssertTrue(reportedIssues.contains { $0.code == .mountInterrupted })
        XCTAssertTrue(reportedIssues.contains { $0.code == .mountRecoveryExhausted })
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

    private func makeConnection(mountPath: String? = nil) -> RemoteConnection {
        let safePath = mountPath ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MontaMac/Archivio").path
        return RemoteConnection(name: "Archivio", protocolType: .sftp, host: "files.example.com", port: 22, username: "anna", remotePath: "/", mountPath: safePath)
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
    var shouldFailUnmount = false
    var unmountCount = 0
    var processes: [FakeMountProcess] = []
    private var outputHandler: (@Sendable (String) -> Void)?
    private var processOutputHandlers: [@Sendable (String) -> Void] = []

    func mountArguments(for connection: RemoteConnection, configURL: URL, cacheDirectory: URL, cachePolicy: CachePolicy) -> [String] { [] }
    func startMount(arguments: [String], output: @escaping @Sendable (String) -> Void) throws -> any MountProcessHandling {
        startCount += 1
        if shouldFailStart { throw TestError.startFailed }
        outputHandler = output
        processOutputHandlers.append(output)
        let process = FakeMountProcess()
        processes.append(process)
        return process
    }
    func emit(_ output: String) { outputHandler?(output) }
    func emitFromProcess(_ index: Int, _ output: String) { processOutputHandlers[index](output) }
    func obscure(_ password: String) throws -> String { "obscured" }
    func unmount(at url: URL) throws {
        unmountCount += 1
        if shouldFailUnmount { throw TestError.unmountFailed }
    }
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

@MainActor
private final class FirstMountWaitMonitor: MountMonitoring {
    private(set) var waitCalls = 0
    private var firstWait: CheckedContinuation<Bool, Never>?

    func isMounted(at url: URL) -> Bool { false }

    func waitUntilMounted(at url: URL, timeout: TimeInterval) async -> Bool {
        waitCalls += 1
        if waitCalls > 1 { return true }
        return await withCheckedContinuation { continuation in firstWait = continuation }
    }

    func finishFirstWait(mounted: Bool) {
        firstWait?.resume(returning: mounted)
        firstWait = nil
    }
}

private enum TestError: Error { case startFailed, unmountFailed }
