import SwiftUI
import MontaMacCore

struct CacheManagementView: View {
    let snapshot: CacheUsageSnapshot
    let connections: [RemoteConnection]
    let statuses: [UUID: MountStatus]
    let isMeasuring: Bool
    let onRefresh: () -> Void
    let onClear: (RemoteConnection) -> Void
    @State private var pendingClear: RemoteConnection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gestione cache").font(.largeTitle.bold())
                        Text("Controlla lo spazio temporaneo usato da ogni drive.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Aggiorna", systemImage: "arrow.clockwise", action: onRefresh)
                        .disabled(isMeasuring)
                }

                HStack(spacing: 12) {
                    CacheSummaryCard(title: "Cache utilizzata", bytes: snapshot.totalBytes, icon: "internaldrive.fill", color: .orange)
                    CacheSummaryCard(title: "Spazio disponibile", bytes: snapshot.availableDiskBytes, icon: "externaldrive.fill.badge.checkmark", color: .green)
                }

                GroupBox("Profili") {
                    if connections.isEmpty {
                        ContentUnavailableView("Nessun profilo", systemImage: "externaldrive.badge.questionmark")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(connections) { connection in
                                HStack(spacing: 12) {
                                    Image(systemName: "externaldrive.fill").foregroundStyle(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(connection.name).fontWeight(.medium)
                                        Text(ByteCountFormatter.string(fromByteCount: snapshot.bytesByProfile[connection.id] ?? 0, countStyle: .file))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Pulisci") { pendingClear = connection }
                                        .disabled(isActive(statuses[connection.id] ?? .disconnected))
                                }
                                .padding(.vertical, 10)
                                if connection.id != connections.last?.id { Divider() }
                            }
                        }
                    }
                }

                Label("La cache dei drive attivi non può essere eliminata, per proteggere i trasferimenti in corso.", systemImage: "shield.checkered")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(32)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .confirmationDialog("Pulire la cache del profilo?", isPresented: Binding(
            get: { pendingClear != nil },
            set: { if !$0 { pendingClear = nil } }
        )) {
            Button("Elimina cache", role: .destructive) {
                if let connection = pendingClear { onClear(connection) }
                pendingClear = nil
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            if let connection = pendingClear {
                Text("Verranno eliminati solo i file temporanei di \(connection.name).")
            }
        }
    }

    private func isActive(_ status: MountStatus) -> Bool {
        switch status {
        case .disconnected, .failed: return false
        default: return true
        }
    }
}

private struct CacheSummaryCard: View {
    let title: LocalizedStringKey
    let bytes: Int64
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)).font(.title2.bold())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}
