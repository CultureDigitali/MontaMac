import Combine
import Foundation

@MainActor
public final class MountCoordinator: ObservableObject {
    @Published public private(set) var statuses: [UUID: MountStatus] = [:]
    @Published public private(set) var logs: [UUID: [String]] = [:]
    @Published public private(set) var transferTotals: [UUID: Int64] = [:]
    private var processes: [UUID: Process] = [:]
    private var configurationURLs: [UUID: URL] = [:]
    private var transferTrackers: [UUID: TransferProgressTracker] = [:]
    private var statisticsBuffers: [UUID: String] = [:]
    private let credentials: CredentialStoring
    private let rclone: any RcloneServicing
    private let monitor: any MountMonitoring
    private let configurationDirectory: URL
    private let cacheRoot: URL

    public init(
        credentials: CredentialStoring = CredentialStore(),
        rclone: any RcloneServicing = RcloneService(),
        monitor: any MountMonitoring = MountMonitor(),
        configurationDirectory: URL = ConnectionStore.defaultURL.deletingLastPathComponent().appendingPathComponent("rclone"),
        cacheRoot: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MontaMac", isDirectory: true)
    ) {
        self.credentials = credentials
        self.rclone = rclone
        self.monitor = monitor
        self.configurationDirectory = configurationDirectory
        self.cacheRoot = cacheRoot
    }

    public func status(for connection: RemoteConnection) -> MountStatus { statuses[connection.id] ?? .disconnected }
    public var cacheRootURL: URL { cacheRoot }

    public func mount(_ connection: RemoteConnection) async {
        if let error = connection.validationError { fail(connection, error); return }
        let mountURL = URL(fileURLWithPath: connection.mountPath)
        if monitor.isMounted(at: mountURL) {
            statuses[connection.id] = .mounted
            append("Drive già montato: nessun secondo processo avviato.", for: connection)
            return
        }
        guard let password = try? credentials.password(for: connection.id), !password.isEmpty else { fail(connection, "Aggiungi la password nel Portachiavi prima di montare."); return }
        statuses[connection.id] = .connecting; append("Avvio connessione…", for: connection)
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
            statisticsBuffers[connection.id] = ""
            let process = try rclone.startMount(arguments: rclone.mountArguments(for: connection, configURL: config, cacheDirectory: cache)) { [weak self] output in
                Task { @MainActor [weak self] in
                    self?.consumeMountOutput(output, for: connection)
                }
            }
            processes[connection.id] = process
            if await monitor.waitUntilMounted(at: mountURL, timeout: 12) {
                statuses[connection.id] = .mounted; append("Drive montato correttamente.", for: connection)
            } else {
                if process.isRunning { process.terminate() }; processes.removeValue(forKey: connection.id)
                removeConfiguration(for: connection)
                fail(connection, "Il drive non è stato montato. Controlla il log e la connessione.")
            }
        } catch {
            removeConfiguration(for: connection)
            fail(connection, error.localizedDescription)
        }
    }

    public func unmount(_ connection: RemoteConnection) async {
        statuses[connection.id] = .disconnecting; append("Smontaggio in corso…", for: connection)
        do {
            try rclone.unmount(at: URL(fileURLWithPath: connection.mountPath))
            processes[connection.id]?.terminate(); processes.removeValue(forKey: connection.id)
            statuses[connection.id] = monitor.isMounted(at: URL(fileURLWithPath: connection.mountPath)) ? .failed("Il drive risulta ancora montato.") : .disconnected
            if case .disconnected = statuses[connection.id] {
                removeConfiguration(for: connection)
            }
            append("Drive smontato.", for: connection)
        } catch { fail(connection, error.localizedDescription) }
    }

    public func reconcile(_ connections: [RemoteConnection]) {
        for connection in connections {
            if monitor.isMounted(at: URL(fileURLWithPath: connection.mountPath)) {
                statuses[connection.id] = .mounted
            } else {
                statuses[connection.id] = .disconnected
                removeConfiguration(for: connection)
            }
        }
    }

    public func append(_ message: String, for connection: RemoteConnection) {
        logs[connection.id, default: []].append("\(Date().formatted(date: .omitted, time: .standard)): \(message)")
        if let count = logs[connection.id]?.count, count > 200 {
            logs[connection.id]?.removeFirst(count - 200)
        }
    }
    private func consumeMountOutput(_ output: String, for connection: RemoteConnection) {
        append(SensitiveLogRedactor.redact(output, for: connection), for: connection)
        var buffer = statisticsBuffers[connection.id, default: ""]
        buffer.append(output)
        let parts = buffer.split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r" }
        guard parts.count > 1 else {
            statisticsBuffers[connection.id] = buffer
            return
        }
        for line in parts.dropLast() {
            guard let total = RcloneTransferStatisticsParser.totalBytes(from: String(line)) else { continue }
            var tracker = transferTrackers[connection.id, default: TransferProgressTracker()]
            let delta = tracker.consume(totalBytes: total)
            transferTrackers[connection.id] = tracker
            if delta > 0 {
                transferTotals[connection.id, default: 0] += delta
            }
        }
        statisticsBuffers[connection.id] = String(parts.last ?? "")
    }
    public func reportFailure(_ message: String, for connection: RemoteConnection) { fail(connection, message) }
    public func configurationURL(for connection: RemoteConnection) -> URL { configurationDirectory.appendingPathComponent("\(connection.id.uuidString).conf") }
    public func cacheURL(for connection: RemoteConnection) -> URL { cacheRoot.appendingPathComponent(connection.id.uuidString, isDirectory: true) }
    private func removeConfiguration(for connection: RemoteConnection) {
        let url = configurationURLs.removeValue(forKey: connection.id) ?? configurationURL(for: connection)
        try? FileManager.default.removeItem(at: url)
    }
    private func fail(_ connection: RemoteConnection, _ message: String) { statuses[connection.id] = .failed(message); append(message, for: connection) }
}
