import SwiftUI
import MontaMacCore

struct ProfileManagerView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.showDashboard = true
                    viewModel.selection = nil
                } label: {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .buttonStyle(.plain)
            }

            Section("Profili") {
                TextField("Cerca profili", text: $viewModel.profileQuery)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Cerca profili")

                Menu {
                    Button("Tutti") { viewModel.profileScope = .all }
                    Button("Preferiti") { viewModel.profileScope = .favorites }
                    Button("Montati") { viewModel.profileScope = .mounted }
                    if !viewModel.profileGroups.isEmpty {
                        Divider()
                        ForEach(viewModel.profileGroups, id: \.self) { group in
                            Button(group) { viewModel.profileScope = .group(group) }
                        }
                    }
                } label: {
                    Label { Text(LocalizedStringKey(scopeTitle)) } icon: { Image(systemName: "line.3.horizontal.decrease.circle") }
                }

                ForEach(viewModel.visibleProfiles) { connection in
                    ProfileRow(
                        connection: connection,
                        status: viewModel.coordinator.status(for: connection),
                        onSelect: { viewModel.selectProfile(connection) },
                        onToggleFavorite: { viewModel.toggleFavorite(connection) },
                        onToggleMount: { viewModel.selectAndToggleMount(connection) }
                    )
                }
                if viewModel.visibleProfiles.isEmpty {
                    ContentUnavailableView("Nessun profilo", systemImage: "externaldrive.badge.questionmark", description: Text("Modifica i filtri oppure aggiungi un drive."))
                }
            }
        }
        .navigationTitle("MontaMac")
    }

    private var scopeTitle: String {
        switch viewModel.profileScope {
        case .all: return "Tutti"
        case .favorites: return "Preferiti"
        case .mounted: return "Montati"
        case let .group(group): return group
        }
    }
}

private struct ProfileRow: View {
    let connection: RemoteConnection
    let status: MountStatus
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleMount: () -> Void

    private var isMounted: Bool { if case .mounted = status { return true }; return false }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                ConnectionRow(connection: connection, status: status)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture(count: 2).onEnded(onToggleMount))
            .accessibilityLabel("Apri profilo \(connection.name)")

            Button(action: onToggleFavorite) {
                Image(systemName: connection.isFavorite ? "star.fill" : "star")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(connection.isFavorite ? .yellow : .secondary)
            .accessibilityLabel(connection.isFavorite ? "Rimuovi dai preferiti" : "Aggiungi ai preferiti")

            Button(action: onToggleMount) {
                Image(systemName: isMounted ? "eject" : "externaldrive.badge.plus")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isMounted ? "Smonta \(connection.name)" : "Monta \(connection.name)")
        }
    }
}
