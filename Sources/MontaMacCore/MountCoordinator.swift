import Combine
import Foundation

@MainActor
public final class MountCoordinator: ObservableObject {
    @Published public private(set) var statuses: [UUID: MountStatus] = [:]
    @Published public private(set) var logs: [UUID: [String]] = [:]
    private var processes: [UUID: Process] = [:]
    private var configurationURLs: [UUID: URL] = [:]
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
            let process = try rclone.startMount(arguments: rclone.mountArguments(for: connection, configURL: config, cacheDirectory: cache)) { [weak self] output in
                Task { @MainActor [weak self] in
                    self?.append(SensitiveLogRedactor.redact(output, for: connection), for: connection)
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
    public func reportFailure(_ message: String, for connection: RemoteConnection) { fail(connection, message) }
    public func configurationURL(for connection: RemoteConnection) -> URL { configurationDirectory.appendingPathComponent("\(connection.id.uuidString).conf") }
    public func cacheURL(for connection: RemoteConnection) -> URL { cacheRoot.appendingPathComponent(connection.id.uuidString, isDirectory: true) }
    private func removeConfiguration(for connection: RemoteConnection) {
        let url = configurationURLs.removeValue(forKey: connection.id) ?? configurationURL(for: connection)
        try? FileManager.default.removeItem(at: url)
    }
    private func fail(_ connection: RemoteConnection, _ message: String) { statuses[connection.id] = .failed(message); append(message, for: connection) }
}
