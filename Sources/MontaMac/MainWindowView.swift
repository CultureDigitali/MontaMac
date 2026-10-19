import AppKit
import SwiftUI
import MontaMacCore

struct MainWindowView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel: AppViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var isHelpPresented = false
    @State private var isRequirementsPresented = false
    @State private var isDeleteConfirmationPresented = false
    private var onboardingBinding: Binding<Bool> { Binding(get: { !hasSeenOnboarding }, set: { if !$0 { hasSeenOnboarding = true } }) }

    init(issueCenter: IssueCenter) {
        _viewModel = StateObject(wrappedValue: AppViewModel(issueCenter: issueCenter))
    }

    var body: some View {
        NavigationSplitView {
            ProfileManagerView(viewModel: viewModel)
            .toolbar {
                Button(action: viewModel.addConnection) { Label("Aggiungi drive", systemImage: "plus") }
                Button { isRequirementsPresented = true } label: { Label("Requisiti", systemImage: "checklist") }
                Button { isHelpPresented = true } label: { Label("Guida", systemImage: "questionmark.circle") }
                Button { isDeleteConfirmationPresented = true } label: { Image(systemName: "trash") }.disabled(!viewModel.commandAvailability.canDelete)
            }
        } detail: {
            if viewModel.utilityDestination == .dashboard || (viewModel.utilityDestination == nil && viewModel.selectedConnection == nil) {
                DashboardView(
                    summary: viewModel.activitySummary,
                    events: viewModel.recentActivity,
                    connections: viewModel.connections,
                    cacheBytes: viewModel.cacheBytes,
                    transferSnapshots: viewModel.coordinator.transferSnapshots,
                    onAdd: viewModel.addConnection,
                    onToggleProfile: viewModel.selectAndToggleMount,
                    onRefresh: viewModel.refreshDashboardMetrics
                )
            } else if viewModel.utilityDestination == .transfers {
                TransferCenterView(
                    connections: viewModel.connections,
                    statuses: viewModel.coordinator.statuses,
                    snapshots: viewModel.coordinator.transferSnapshots,
                    totals: viewModel.coordinator.transferTotals
                )
            } else if viewModel.utilityDestination == .cache {
                CacheManagementView(
                    snapshot: viewModel.cacheSnapshot,
                    connections: viewModel.connections,
                    statuses: viewModel.coordinator.statuses,
                    cleaningProfileIDs: viewModel.coordinator.cleaningCacheProfileIDs,
                    isMeasuring: viewModel.isMeasuringCache,
                    onRefresh: viewModel.refreshCacheUsage,
                    onClear: viewModel.clearCache
                )
            } else if viewModel.utilityDestination == .issues {
                IssueCenterView(
                    issueCenter: viewModel.issueCenter,
                    connections: viewModel.connections,
                    statuses: viewModel.coordinator.statuses,
                    logs: viewModel.coordinator.logs,
                    onRecovery: recover
                )
                .environmentObject(settings)
            } else if let connection = viewModel.selectedConnection {
                ConnectionDetailView(connection: connection, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.isEditorPresented) {
            if let connection = viewModel.editingConnection { ConnectionEditorView(connection: connection, onSave: viewModel.save) }
        }
        .frame(minWidth: 860, minHeight: 540)
        .onChange(of: viewModel.selection) { _, newValue in if newValue != nil { viewModel.utilityDestination = nil } }
        .onAppear { presentRequirementsIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            viewModel.coordinator.shutdown()
        }
        .onChange(of: hasSeenOnboarding) { _, isComplete in
            if isComplete { presentRequirementsIfNeeded() }
        }
        .sheet(isPresented: onboardingBinding) { OnboardingView(isPresented: onboardingBinding) }
        .sheet(isPresented: $isHelpPresented) { HelpView() }
        .sheet(isPresented: $isRequirementsPresented) { RequirementsView() }
        .confirmationDialog("Eliminare il profilo?", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("Elimina profilo", role: .destructive, action: viewModel.removeSelected)
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("La cartella locale e i file non verranno eliminati.")
        }
        .focusedSceneValue(\.menuActions, menuActions)
        .overlay(alignment: .top) {
            if let issue = viewModel.issueCenter.banner {
                IssueBanner(
                    issue: issue,
                    message: localizedMessage(issue),
                    onOpen: { viewModel.selectUtility(.issues) },
                    onDismiss: viewModel.issueCenter.dismissBanner
                )
                .padding(12)
            }
        }
    }

    private func presentRequirementsIfNeeded() {
        guard hasSeenOnboarding else { return }
        isRequirementsPresented = !RequirementChecker.mountBlockingRequirements(in: RequirementChecker().check()).isEmpty
    }

    private var menuActions: MenuActions {
        MenuActions(
            availability: viewModel.commandAvailability,
            newProfile: viewModel.addConnection,
            editProfile: viewModel.editSelected,
            requestDelete: { isDeleteConfirmationPresented = true },
            mount: viewModel.mountSelected,
            unmount: viewModel.unmountSelected,
            openFinder: viewModel.openInFinder,
            refreshStatistics: viewModel.refreshSelectedStatistics,
            showDashboard: { viewModel.selectUtility(.dashboard) },
            showTransfers: { viewModel.selectUtility(.transfers) },
            showCache: { viewModel.selectUtility(.cache) },
            showIssues: { viewModel.selectUtility(.issues) },
            showProfiles: { viewModel.profileScope = .all; viewModel.utilityDestination = nil },
            showFavorites: { viewModel.profileScope = .favorites; viewModel.utilityDestination = nil },
            showMounted: { viewModel.profileScope = .mounted; viewModel.utilityDestination = nil },
            showRequirements: { isRequirementsPresented = true },
            showHelp: { isHelpPresented = true },
            showOnboarding: { hasSeenOnboarding = false },
            showDiagnostics: { viewModel.selectUtility(.issues) }
        )
    }

    private func localizedMessage(_ issue: AppIssue) -> String {
        String(format: settings.localized(issue.code.rawValue), locale: settings.locale, arguments: issue.arguments)
    }

    private func recover(_ issue: AppIssue) {
        if issue.recovery == .openRequirements {
            isRequirementsPresented = true
            return
        }
        guard let profileID = issue.profileID,
              let connection = viewModel.connections.first(where: { $0.id == profileID }) else { return }
        viewModel.mount(connection)
    }
}
