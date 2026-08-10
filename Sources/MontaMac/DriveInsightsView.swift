import SwiftUI
import MontaMacCore

struct DriveInsightsView: View {
    let connection: RemoteConnection
    let statistics: RemoteStatistics?
    let isRefreshing: Bool
    let onRefresh: () -> Void
    var body: some View {
        GroupBox("Statistiche del drive") {
            VStack(alignment: .leading, spacing: 10) {
                if let statistics {
                    HStack { Label("File", systemImage: "doc.fill"); Spacer(); Text("\(statistics.fileCount.formatted())") }
                    HStack { Label("Spazio analizzato", systemImage: "internaldrive.fill"); Spacer(); Text(statistics.formattedSize) }
                    HStack { Label("Aggiornato", systemImage: "arrow.clockwise"); Spacer(); Text(statistics.scannedAt, style: .relative) }
                } else {
                    Label("Le statistiche vengono lette solo quando lo richiedi.", systemImage: "chart.bar.xaxis")
                        .foregroundStyle(.secondary)
                }
                Button("Aggiorna statistiche", systemImage: "arrow.clockwise", action: onRefresh)
                    .disabled(isRefreshing)
            }.padding(.vertical, 2)
        }
    }
}
