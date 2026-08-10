import SwiftUI
import MontaMacCore

struct ConnectionDetailView: View {
    let connection: RemoteConnection; @ObservedObject var viewModel: AppViewModel
    @State private var isLogPresented = false
    private var status: MountStatus { viewModel.coordinator.status(for: connection) }
    private var isMounted: Bool { if case .mounted = status { return true }; return false }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONNESSIONE REMOTA").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Text(connection.name).font(.largeTitle.weight(.bold))
                        Label { Text(LocalizedStringKey(status.message)) } icon: { Image(systemName: isMounted ? "checkmark.circle.fill" : "circle.fill") }.foregroundStyle(isMounted ? .green : .secondary)
                    }
                    Spacer()
                    Menu { Button("Modifica", action: viewModel.editSelected); Button("Apri nel Finder", action: viewModel.openInFinder); Button("Log", action: { isLogPresented = true }) } label: { Image(systemName: "ellipsis.circle").font(.title2) }
                }
                GroupBox("Drive") {
                    LabeledContent("Protocollo", value: connection.protocolType.title)
                    LabeledContent("Server", value: "\(connection.host):\(connection.port)")
                    LabeledContent("Cartella locale", value: connection.mountPath)
                }
                DriveInsightsView(connection: connection, statistics: viewModel.statistics[connection.id], isRefreshing: viewModel.refreshingStatistics.contains(connection.id)) { viewModel.refreshStatistics(for: connection) }
                HStack {
                    if isMounted { Button("Smonta drive", systemImage: "eject", action: viewModel.unmountSelected).buttonStyle(.bordered) }
                    else { Button("Monta drive", systemImage: "externaldrive.badge.plus", action: viewModel.mountSelected).buttonStyle(.borderedProminent).controlSize(.large) }
                    Button("Apri nel Finder", systemImage: "folder", action: viewModel.openInFinder).buttonStyle(.borderless)
                }
                DiagnosticsView(connection: connection)
            }.padding(32).frame(maxWidth: 760, alignment: .leading)
        }.sheet(isPresented: $isLogPresented) { LogSheet(lines: viewModel.coordinator.logs[connection.id] ?? []) }
    }
}

struct DiagnosticsView: View {
    let connection: RemoteConnection
    var body: some View { GroupBox("Diagnostica") { ForEach(DiagnosticsService().inspect(connection)) { item in Label { Text(LocalizedStringKey(item.title)) + Text(" — ") + Text(LocalizedStringKey(item.detail)) } icon: { Image(systemName: item.isPassing ? "checkmark.circle" : "exclamationmark.triangle") }.foregroundStyle(item.isPassing ? .green : .orange).padding(.vertical, 2) } } }
}
