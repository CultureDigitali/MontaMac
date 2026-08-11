import Combine
import Foundation

@MainActor
public final class MountCoordinator: ObservableObject {
    public typealias Sleeper = @Sendable (TimeInterval) async -> Void

    @Published public private(set) var statuses: [UUID: MountStatus] = [:]
    @Published public private(set) var logs: [UUID: [String]] = [:]
    @Published public private(set) var transferTotals: [UUID: Int64] = [:]
    @Published public private(set) var transferSnapshots: [UUID: TransferSnapshot] = [:]

    private var processes: [UUID: any MountProcessHandling] = [:]
    private var processTokens: [UUID: UUID] = [:]
    private var configurationURLs: [UUID: URL] = [:]
    private var transferTrackers: [UUID: TransferProgressTracker] = [:]
    private var jsonParsers: [UUID: RcloneJSONLogParser] = [:]
    private var intendedMounted: Set<UUID> = []
    private var retryCounts: [UUID: Int] = [:]
    private var retryTasks: [UUID: Task<Void, Never>] = [:]
    private var healthTasks: [UUID: Task<Void, Never>] = [:]
    private var connectionsByID: [UUID: RemoteConnection] = [:]

    private let credentials: CredentialStoring
    private let rclone: any RcloneServicing
    private let monitor: any MountMonitoring
    private let configurationDirectory: URL
    private let cacheRoot: URL
    private let recoveryPolicy: MountRecoveryPolicy
    private let sleeper: Sleeper
    private let healthCheckInterval: TimeInterval?
    private let cachePolicyResolver: CachePolicyResolver
    private let automaticReconnectEnabled: () -> Bool

    public init(
        credentials: CredentialStoring = CredentialStore(),
        rclone: any RcloneServicing = RcloneService(),
        monitor: any MountMonitoring = MountMonitor(),
        configurationDirectory: URL = ConnectionStore.defaultURL.deletingLastPathComponent().appendingPathComponent("rclone"),
        cacheRoot: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MontaMac", isDirectory: true),
        recoveryPolicy: MountRecoveryPolicy = MountRecoveryPolicy(),
        sleeper: @escaping Sleeper = { seconds in try? await Task.sleep(for: .seconds(seconds)) },
        healthCheckInterval: TimeInterval? = 5,
        cachePolicyResolver: CachePolicyResolver = CachePolicyResolver(),
        automaticReconnectEnabled: @escaping () -> Bool = { true }
    ) {
        self.credentials = credentials
        self.rclone = rclone
        self.monitor = monitor
        self.configurationDirectory = configurationDirectory
        self.cacheRoot = cacheRoot
        self.recoveryPolicy = recoveryPolicy
        self.sleeper = sleeper
        self.healthCheckInterval = healthCheckInterval
        self.cachePolicyResolver = cachePolicyResolver
        self.automaticReconnectEnabled = automaticReconnectEnabled
    }

    deinit {
        retryTasks.values.forEach { $0.cancel() }
        healthTasks.values.forEach { $0.cancel() }
    }

    public func status(for connection: RemoteConnection) -> MountStatus { statuses[connection.id] ?? .disconnected }
    public func retryAttempt(for connection: RemoteConnection) -> Int { retryCounts[connection.id, default: 0] }
    public var cacheRootURL: URL { cacheRoot }

    public func mount(_ connection: RemoteConnection) async {
        connectionsByID[connection.id] = connection
        intendedMounted.insert(connection.id)
        retryCounts[connection.id] = 0
        retryTasks.removeValue(forKey: connection.id)?.cancel()
        await mountAttempt(connection, isRecovery: false)
    }

    private func mountAttempt(_ connection: RemoteConnection, isRecovery: Bool) async {
        guard intendedMounted.contains(connection.id) else { return }
        if let error = connection.validationError {
            stopRecoveryAndFail(connection, error)
            return
        }
        let mountURL = URL(fileURLWithPath: connection.mountPath)
        if monitor.isMounted(at: mountURL) {
            statuses[connection.id] = .mounted
            retryCounts[connection.id] = 0
            append("Drive già montato: nessun secondo processo avviato.", for: connection)
            startHealthMonitor(for: connection)
            return
        }
        guard let password = try? credentials.password(for: connection.id), !password.isEmpty else {
            stopRecoveryAndFail(connection, "Aggiungi la password nel Portachiavi prima di montare.")
            return
        }
        statuses[connection.id] = isRecovery ? statuses[connection.id] : .connecting
        append(isRecovery ? "Nuovo tentativo di connessione…" : "Avvio connessione…", for: connection)
        do {
            try FileManager.default.createDirectory(at: mountURL, withIntermediateDirectories: true)
            let config = configurationURL(for: connection)
            let cache = cacheURL(for: connection)
            try SecureFileStore.secureDirectory(cacheRoot)
            try SecureFileStore.secureDirectory(cache)
            _ = try RcloneConfigurationWriter(rclone: rclone).write(connection: connection, password: password, to: config)
            configurationURLs[connection.id] = config
            transferTotals[connection.id] = 0
            transferTrackers[connection.id] = TransferProgressTracker()
            jsonParsers[connection.id] = RcloneJSONLogParser()
            transferSnapshots[connection.id] = .idle
            let process = try rclone.startMount(arguments: rclone.mountArguments(for: connection, configURL: config, cacheDirectory: cache, cachePolicy: cachePolicyResolver.policy(for: connection))) { [weak self] output in
                Task { @MainActor [weak self] in self?.consumeMountOutput(output, for: connection) }
            }
            let token = UUID()
            processes[connection.id] = process
            processTokens[connection.id] = token
            process.observeTermination { [weak self] status in
                Task { @MainActor [weak self] in
                    self?.processTerminated(connection, token: token, status: status)
                }
            }
            if await monitor.waitUntilMounted(at: mountURL, timeout: 12) {
                guard processTokens[connection.id] == token, intendedMounted.contains(connection.id) else { return }
                statuses[connection.id] = .mounted
                retryCounts[connection.id] = 0
                append("Drive montato correttamente.", for: connection)
                startHealthMonitor(for: connection)
            } else {
                discardProcess(for: connection, terminate: true)
                removeConfiguration(for: connection)
                if isRecovery { scheduleRecovery(for: connection, reason: "Il drive non risponde.") }
                else { stopRecoveryAndFail(connection, "Il drive non è stato montato. Controlla il log e la connessione.") }
            }
        } catch {
            discardProcess(for: connection, terminate: true)
            removeConfiguration(for: connection)
            if isRecovery { scheduleRecovery(for: connection, reason: error.localizedDescription) }
            else { stopRecoveryAndFail(connection, error.localizedDescription) }
        }
    }

    public func unmount(_ connection: RemoteConnection) async {
        intendedMounted.remove(connection.id)
        cancelRecovery(for: connection)
        healthTasks.removeValue(forKey: connection.id)?.cancel()
        statuses[connection.id] = .disconnecting
        append("Smontaggio in corso…", for: connection)
        do {
            try rclone.unmount(at: URL(fileURLWithPath: connection.mountPath))
            discardProcess(for: connection, terminate: true)
            statuses[connection.id] = monitor.isMounted(at: URL(fileURLWithPath: connection.mountPath)) ? .failed("Il drive risulta ancora montato.") : .disconnected
            if case .disconnected = statuses[connection.id] { removeConfiguration(for: connection) }
            append("Drive smontato.", for: connection)
        } catch {
            statuses[connection.id] = .failed(error.localizedDescription)
            append(error.localizedDescription, for: connection)
        }
    }

    public func cancelRecovery(for connection: RemoteConnection) {
        retryTasks.removeValue(forKey: connection.id)?.cancel()
        retryCounts[connection.id] = 0
    }

    public func reconcile(_ connections: [RemoteConnection]) {
        for connection in connections {
            connectionsByID[connection.id] = connection
            if monitor.isMounted(at: URL(fileURLWithPath: connection.mountPath)) {
                intendedMounted.insert(connection.id)
                statuses[connection.id] = .mounted
                startHealthMonitor(for: connection)
            } else {
                intendedMounted.remove(connection.id)
                statuses[connection.id] = .disconnected
                removeConfiguration(for: connection)
            }
        }
    }

    private func processTerminated(_ connection: RemoteConnection, token: UUID, status: Int32) {
        guard processTokens[connection.id] == token else { return }
        processes.removeValue(forKey: connection.id)
        processTokens.removeValue(forKey: connection.id)
        healthTasks.removeValue(forKey: connection.id)?.cancel()
        removeConfiguration(for: connection)
        guard intendedMounted.contains(connection.id) else { return }
        scheduleRecovery(for: connection, reason: "rclone terminato con codice \(status).")
    }

    private func scheduleRecovery(for connection: RemoteConnection, reason: String) {
        guard intendedMounted.contains(connection.id) else { return }
        guard automaticReconnectEnabled() else {
            stopRecoveryAndFail(connection, reason)
            return
        }
        let attempt = retryCounts[connection.id, default: 0] + 1
        guard let delay = recoveryPolicy.delay(forAttempt: attempt) else {
            stopRecoveryAndFail(connection, "Riconnessione non riuscita: \(reason)")
            return
        }
        retryCounts[connection.id] = attempt
        statuses[connection.id] = .reconnecting(attempt: attempt, delay: delay)
        append("Connessione interrotta. Tentativo \(attempt) tra \(Int(delay)) secondi.", for: connection)
        retryTasks.removeValue(forKey: connection.id)?.cancel()
        retryTasks[connection.id] = Task { [weak self] in
            guard let self else { return }
            await self.sleeper(delay)
            guard !Task.isCancelled, self.intendedMounted.contains(connection.id) else { return }
            await self.mountAttempt(connection, isRecovery: true)
        }
    }

    private func startHealthMonitor(for connection: RemoteConnection) {
        healthTasks.removeValue(forKey: connection.id)?.cancel()
        guard let interval = healthCheckInterval else { return }
        healthTasks[connection.id] = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(interval)) }
                catch { return }
                guard let self, self.intendedMounted.contains(connection.id) else { return }
                if !self.performHealthCheck(for: connection) { return }
            }
        }
    }

    @discardableResult
    func performHealthCheck(for connection: RemoteConnection) -> Bool {
        guard intendedMounted.contains(connection.id) else { return false }
        let processIsHealthy = processes[connection.id]?.isRunning ?? true
        let mountIsHealthy = monitor.isMounted(at: URL(fileURLWithPath: connection.mountPath))
        guard processIsHealthy, mountIsHealthy else {
            discardProcess(for: connection, terminate: true)
            removeConfiguration(for: connection)
            scheduleRecovery(for: connection, reason: "Il mount non è più disponibile.")
            return false
        }
        return true
    }

    private func discardProcess(for connection: RemoteConnection, terminate: Bool) {
        processTokens.removeValue(forKey: connection.id)
        guard let process = processes.removeValue(forKey: connection.id) else { return }
        if terminate, process.isRunning { process.terminate() }
    }

    private func stopRecoveryAndFail(_ connection: RemoteConnection, _ message: String) {
        intendedMounted.remove(connection.id)
        retryTasks.removeValue(forKey: connection.id)?.cancel()
        healthTasks.removeValue(forKey: connection.id)?.cancel()
        statuses[connection.id] = .failed(message)
        append(message, for: connection)
    }

    public func append(_ message: String, for connection: RemoteConnection) {
        logs[connection.id, default: []].append("\(Date().formatted(date: .omitted, time: .standard)): \(message)")
        if let count = logs[connection.id]?.count, count > 200 { logs[connection.id]?.removeFirst(count - 200) }
    }

    private func consumeMountOutput(_ output: String, for connection: RemoteConnection) {
        var parser = jsonParsers[connection.id, default: RcloneJSONLogParser()]
        let events = parser.consume(output)
        jsonParsers[connection.id] = parser
        for event in events {
            switch event {
            case let .statistics(snapshot):
                transferSnapshots[connection.id] = snapshot
            var tracker = transferTrackers[connection.id, default: TransferProgressTracker()]
                let delta = tracker.consume(totalBytes: snapshot.bytes)
            transferTrackers[connection.id] = tracker
            if delta > 0 { transferTotals[connection.id, default: 0] += delta }
            case let .log(message):
                append(SensitiveLogRedactor.redact(message, for: connection), for: connection)
            }
        }
    }

    public func reportFailure(_ message: String, for connection: RemoteConnection) { stopRecoveryAndFail(connection, message) }
    public func configurationURL(for connection: RemoteConnection) -> URL { configurationDirectory.appendingPathComponent("\(connection.id.uuidString).conf") }
    public func cacheURL(for connection: RemoteConnection) -> URL { cacheRoot.appendingPathComponent(connection.id.uuidString, isDirectory: true) }
    private func removeConfiguration(for connection: RemoteConnection) {
        let url = configurationURLs.removeValue(forKey: connection.id) ?? configurationURL(for: connection)
        try? FileManager.default.removeItem(at: url)
    }
}
