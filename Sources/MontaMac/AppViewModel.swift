import AppKit
import Combine
import Foundation
import MontaMacCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published var connections: [RemoteConnection]
    @Published var selection: UUID?
    @Published var isEditorPresented = false
    @Published var editingConnection: RemoteConnection?
    @Published var utilityDestination: UtilityDestination? = .dashboard
    @Published var activitySummary = ActivitySummary()
    @Published var recentActivity: [ActivityEvent] = []
    @Published var cacheBytes: Int64 = 0
    @Published var cacheSnapshot: CacheUsageSnapshot = .empty
    @Published var isMeasuringCache = false
    @Published var statistics: [UUID: RemoteStatistics] = [:]
    @Published var refreshingStatistics: Set<UUID> = []
    @Published var profileScope: ProfileScope = .all
    @Published var profileQuery = ""
    let coordinator: MountCoordinator
    let issueCenter: IssueCenter
    private let store = ConnectionStore()
    private let credentials = CredentialStore()
    private lazy var profileSecurityCleaner = ProfileSecurityCleaner(credentials: credentials)
    private let activityStore = ActivityStore()
    private var transferTrackers: [UUID: TransferProgressTracker] = [:]
    private var cancellables: Set<AnyCancellable> = []
    private var cacheRefreshTask: Task<Void, Never>?
    private let mountCompletionHandler = MountCompletionHandler { url in
        NSWorkspace.shared.open(url)
    }

    init(issueCenter: IssueCenter = IssueCenter()) {
        coordinator = MountCoordinator(automaticReconnectEnabled: { AppSettings.automaticReconnectValue() })
        self.issueCenter = issueCenter
        do { connections = try store.load() }
        catch {
            connections = []
            issueCenter.report(AppIssue(code: .profileSaveFailed, arguments: [error.localizedDescription], severity: .error))
        }
        selection = connections.first?.id
        coordinator.reconcile(connections)
        reloadDashboard()
        observeCoordinator()
        observeTransferTotals()
        refreshCacheUsage()
    }

    var selectedConnection: RemoteConnection? { connections.first { $0.id == selection } }
    var commandAvailability: AppCommandAvailability { AppCommandAvailability(hasSelection: selectedConnection != nil, status: selectedConnection.map(coordinator.status(for:)) ?? .disconnected) }
    var visibleProfiles: [RemoteConnection] { ProfileFilter.profiles(connections, scope: profileScope, query: profileQuery, statusFor: coordinator.status(for:)) }
    var profileGroups: [String] { ProfileFilter.groups(in: connections) }

    func addConnection() {
        var connection = RemoteConnection.blank(protocolType: .ftp)
        connection.mountPath = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("MontaMac/nuova-connessione").path
        editingConnection = connection; isEditorPresented = true
    }

    func editSelected() { editingConnection = selectedConnection; isEditorPresented = editingConnection != nil }

    func save(_ connection: RemoteConnection, password: String) {
        var connection = connection
        connection.profileGroup = RemoteConnection.normalizedProfileGroup(connection.profileGroup)
        if let index = connections.firstIndex(where: { $0.id == connection.id }) { connections[index] = connection } else { connections.append(connection) }
        selection = connection.id
        do {
            try store.save(connections)
            if !password.isEmpty { try credentials.save(password: password, for: connection.id) }
            isEditorPresented = false
        } catch {
            issueCenter.report(AppIssue(
                code: password.isEmpty ? .profileSaveFailed : .credentialSaveFailed,
                profileID: connection.id, arguments: [error.localizedDescription], severity: .error
            ))
        }
    }

    func removeSelected() {
        guard commandAvailability.canDelete, let connection = selectedConnection else { return }
        do {
            try profileSecurityCleaner.clean(connection)
            connections.removeAll { $0.id == connection.id }
            selection = connections.first?.id
            try store.save(connections)
        } catch {
            coordinator.reportFailure("Profilo non eliminato: \(error.localizedDescription)", for: connection)
        }
    }

    func mountSelected() { guard let connection = selectedConnection else { return }; mount(connection) }
    func mount(_ connection: RemoteConnection) {
        let missing = RequirementChecker.mountBlockingRequirements(in: RequirementChecker().check()).map(\.title)
        guard missing.isEmpty else {
            coordinator.reportFailure("Installa prima: \(missing.joined(separator: ", ")).", for: connection)
            return
        }
        Task {
            await coordinator.mount(connection)
            let status = coordinator.status(for: connection)
            if case .mounted = status {
                recordMounted(connection)
                switch mountCompletionHandler.handle(status: status, connection: connection) {
                case let .opened(url):
                    coordinator.append("Cartella aperta nel Finder: \(url.path)", for: connection)
                case let .openFailed(url):
                    coordinator.append("Drive montato, ma Finder non ha aperto: \(url.path)", for: connection)
                case .skipped:
                    break
                }
            }
        }
    }
    func unmountSelected() { guard let connection = selectedConnection else { return }; unmount(connection) }
    func unmount(_ connection: RemoteConnection) { Task {
        await coordinator.unmount(connection)
        do { try activityStore.record(.unmounted(connectionID: connection.id, at: .now)) }
        catch { reportActivityError(error, connectionID: connection.id) }
        reloadDashboard()
    } }
    func selectProfile(_ connection: RemoteConnection) { selection = connection.id; utilityDestination = nil }
    func selectUtility(_ destination: UtilityDestination) { utilityDestination = destination; selection = nil }
    func selectAndToggleMount(_ connection: RemoteConnection) {
        selectProfile(connection)
        if case .mounted = coordinator.status(for: connection) { unmount(connection) } else { mount(connection) }
    }
    func toggleFavorite(_ connection: RemoteConnection) {
        guard let index = connections.firstIndex(where: { $0.id == connection.id }) else { return }
        connections[index].isFavorite.toggle()
        do { try store.save(connections) }
        catch { issueCenter.report(AppIssue(code: .profileSaveFailed, profileID: connection.id, arguments: [error.localizedDescription], severity: .error)) }
    }
    func openInFinder() { guard let path = selectedConnection?.mountPath else { return }; NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
    func reloadDashboard() {
        do {
            activitySummary = try activityStore.summary(since: Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast)
            recentActivity = try activityStore.recentEvents()
        } catch {
            activitySummary = ActivitySummary()
            recentActivity = []
            reportActivityError(error, connectionID: nil)
        }
    }
    private func observeTransferTotals() {
        coordinator.$transferTotals
            .sink { [weak self] totals in
                Task { @MainActor [weak self] in self?.persistTransferTotals(totals) }
            }
            .store(in: &cancellables)
    }
    private func observeCoordinator() {
        coordinator.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
    private func persistTransferTotals(_ totals: [UUID: Int64]) {
        var recordedTransfer = false
        for (connectionID, total) in totals {
            var tracker = transferTrackers[connectionID, default: TransferProgressTracker()]
            let delta = tracker.consume(totalBytes: total)
            transferTrackers[connectionID] = tracker
            guard delta > 0 else { continue }
            do { try activityStore.record(.transfer(connectionID: connectionID, bytes: delta, at: .now)) }
            catch { reportActivityError(error, connectionID: connectionID) }
            recordedTransfer = true
        }
        if recordedTransfer {
            reloadDashboard()
            refreshCacheUsage()
        }
    }
    func refreshDashboardMetrics() {
        reloadDashboard()
        refreshCacheUsage()
    }
    func refreshCacheUsage() {
        cacheRefreshTask?.cancel()
        let cacheRoot = coordinator.cacheRootURL
        let profileIDs = connections.map(\.id)
        isMeasuringCache = true
        cacheRefreshTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Result { try CacheUsageService().snapshot(cacheRoot: cacheRoot, profileIDs: profileIDs) }
            }.value
            guard !Task.isCancelled else { return }
            self?.isMeasuringCache = false
            switch result {
            case let .success(snapshot):
                self?.cacheSnapshot = snapshot
                self?.cacheBytes = snapshot.totalBytes
            case let .failure(error):
                self?.issueCenter.report(AppIssue(code: .cacheCleanupFailed, arguments: [error.localizedDescription], severity: .warning))
            }
        }
    }

    func clearCache(for connection: RemoteConnection) {
        let status = coordinator.status(for: connection)
        let isActive: Bool
        switch status {
        case .disconnected, .failed: isActive = false
        default: isActive = true
        }
        let cacheRoot = coordinator.cacheRootURL
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Result { try CacheUsageService().clear(profileID: connection.id, cacheRoot: cacheRoot, isMounted: isActive) }
            }.value
            switch result {
            case .success: self?.refreshCacheUsage()
            case let .failure(error):
                self?.issueCenter.report(AppIssue(code: .cacheCleanupFailed, profileID: connection.id, arguments: [error.localizedDescription], severity: .warning))
            }
        }
    }
    func recordMounted(_ connection: RemoteConnection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index].markUsed()
            do { try store.save(connections) }
            catch { issueCenter.report(AppIssue(code: .profileSaveFailed, profileID: connection.id, arguments: [error.localizedDescription], severity: .error)) }
        }
        do { try activityStore.record(.mounted(connectionID: connection.id, at: .now)) }
        catch { reportActivityError(error, connectionID: connection.id) }
        reloadDashboard()
    }
    func refreshStatistics(for connection: RemoteConnection) {
        refreshingStatistics.insert(connection.id)
        Task {
            defer { refreshingStatistics.remove(connection.id) }
            do { statistics[connection.id] = try await RemoteStatisticsService().scanMountedFolder(at: URL(fileURLWithPath: connection.mountPath)) }
            catch { coordinator.append("Statistiche non disponibili: \(error.localizedDescription)", for: connection) }
        }
    }

    func refreshSelectedStatistics() {
        guard let connection = selectedConnection else { return }
        refreshStatistics(for: connection)
    }

    private func reportActivityError(_ error: Error, connectionID: UUID?) {
        issueCenter.report(AppIssue(code: .activityWriteFailed, profileID: connectionID, arguments: [error.localizedDescription], severity: .error))
    }
}
