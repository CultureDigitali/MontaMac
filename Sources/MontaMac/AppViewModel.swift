import AppKit
import Foundation
import MontaMacCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published var connections: [RemoteConnection]
    @Published var selection: UUID?
    @Published var isEditorPresented = false
    @Published var editingConnection: RemoteConnection?
    @Published var showDashboard = true
    @Published var activitySummary = ActivitySummary()
    @Published var recentActivity: [ActivityEvent] = []
    @Published var statistics: [UUID: RemoteStatistics] = [:]
    @Published var refreshingStatistics: Set<UUID> = []
    @Published var profileScope: ProfileScope = .all
    @Published var profileQuery = ""
    let coordinator = MountCoordinator()
    private let store = ConnectionStore()
    private let credentials = CredentialStore()
    private lazy var profileSecurityCleaner = ProfileSecurityCleaner(credentials: credentials)
    private let activityStore = ActivityStore()
    private let mountCompletionHandler = MountCompletionHandler { url in
        NSWorkspace.shared.open(url)
    }

    init() {
        connections = (try? store.load()) ?? []
        selection = connections.first?.id
        coordinator.reconcile(connections)
        reloadDashboard()
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
        try? store.save(connections)
        if !password.isEmpty { try? credentials.save(password: password, for: connection.id) }
        isEditorPresented = false
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
        let missing = RequirementChecker().check().filter { !$0.isInstalled }.map(\.title)
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
    func unmount(_ connection: RemoteConnection) { Task { await coordinator.unmount(connection); try? activityStore.record(.unmounted(connectionID: connection.id, at: .now)); reloadDashboard() } }
    func selectProfile(_ connection: RemoteConnection) { selection = connection.id; showDashboard = false }
    func selectAndToggleMount(_ connection: RemoteConnection) {
        selectProfile(connection)
        if case .mounted = coordinator.status(for: connection) { unmount(connection) } else { mount(connection) }
    }
    func toggleFavorite(_ connection: RemoteConnection) {
        guard let index = connections.firstIndex(where: { $0.id == connection.id }) else { return }
        connections[index].isFavorite.toggle()
        try? store.save(connections)
    }
    func openInFinder() { guard let path = selectedConnection?.mountPath else { return }; NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
    func reloadDashboard() { activitySummary = (try? activityStore.summary(since: Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast)) ?? ActivitySummary(); recentActivity = (try? activityStore.recentEvents()) ?? [] }
    func recordMounted(_ connection: RemoteConnection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index].markUsed()
            try? store.save(connections)
        }
        try? activityStore.record(.mounted(connectionID: connection.id, at: .now))
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
}
