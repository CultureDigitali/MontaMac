import SwiftUI
import MontaMacCore

struct MainWindowView: View {
    @StateObject private var viewModel = AppViewModel()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var isHelpPresented = false
    @State private var isRequirementsPresented = false
    @State private var isDeleteConfirmationPresented = false
    private var onboardingBinding: Binding<Bool> { Binding(get: { !hasSeenOnboarding }, set: { if !$0 { hasSeenOnboarding = true } }) }

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
            if viewModel.showDashboard || viewModel.selectedConnection == nil {
                DashboardView(
                    summary: viewModel.activitySummary,
                    events: viewModel.recentActivity,
                    connections: viewModel.connections,
                    cacheBytes: viewModel.cacheBytes,
                    onAdd: viewModel.addConnection,
                    onToggleProfile: viewModel.selectAndToggleMount,
                    onRefresh: viewModel.refreshDashboardMetrics
                )
            } else if let connection = viewModel.selectedConnection {
                ConnectionDetailView(connection: connection, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.isEditorPresented) {
            if let connection = viewModel.editingConnection { ConnectionEditorView(connection: connection, onSave: viewModel.save) }
        }
        .frame(minWidth: 860, minHeight: 540)
        .onChange(of: viewModel.selection) { _, newValue in if newValue != nil { viewModel.showDashboard = false } }
        .onAppear { presentRequirementsIfNeeded() }
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
    }

    private func presentRequirementsIfNeeded() {
        guard hasSeenOnboarding else { return }
        isRequirementsPresented = !RequirementChecker().check().allSatisfy(\.isInstalled)
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
            showDashboard: { viewModel.showDashboard = true; viewModel.selection = nil },
            showProfiles: { viewModel.profileScope = .all; viewModel.showDashboard = false },
            showFavorites: { viewModel.profileScope = .favorites; viewModel.showDashboard = false },
            showMounted: { viewModel.profileScope = .mounted; viewModel.showDashboard = false },
            showRequirements: { isRequirementsPresented = true },
            showHelp: { isHelpPresented = true },
            showOnboarding: { hasSeenOnboarding = false },
            showDiagnostics: { viewModel.showDashboard = false }
        )
    }
}
