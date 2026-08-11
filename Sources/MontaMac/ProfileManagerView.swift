import SwiftUI
import MontaMacCore

struct ProfileManagerView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        List {
            Section {
                ForEach(UtilityDestination.allCases) { destination in
                    Button {
                        viewModel.selectUtility(destination)
                    } label: {
                        HStack {
                            Label(LocalizedStringKey(destination.titleKey), systemImage: destination.systemImage)
                            Spacer()
                            if viewModel.utilityDestination == destination { Image(systemName: "checkmark").foregroundStyle(.secondary) }
                        }
                    }
                    .buttonStyle(.plain)
                }
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
                        snapshot: viewModel.coordinator.transferSnapshots[connection.id] ?? .idle,
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
    let snapshot: TransferSnapshot
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

            if snapshot.speedBytesPerSecond > 0 {
                Text(ByteCountFormatter.string(fromByteCount: Int64(snapshot.speedBytesPerSecond), countStyle: .file) + "/s")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.cyan)
            }

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
