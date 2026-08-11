import SwiftUI
import MontaMacCore

struct TransferCenterView: View {
    let connections: [RemoteConnection]
    let statuses: [UUID: MountStatus]
    let snapshots: [UUID: TransferSnapshot]
    let totals: [UUID: Int64]

    private var totalSpeed: Double { snapshots.values.reduce(0) { $0 + $1.speedBytesPerSecond } }
    private var activeCount: Int { snapshots.values.reduce(0) { $0 + $1.activeTransfers } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trasferimenti").font(.largeTitle.bold())
                    Text("Velocità, avanzamento e attività in tempo reale.").foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    TransferMetric(title: "Velocità attuale", value: ByteCountFormatter.string(fromByteCount: Int64(totalSpeed), countStyle: .file) + "/s", icon: "gauge.with.dots.needle.67percent", color: .cyan)
                    TransferMetric(title: "Trasferimenti attivi", value: "\(activeCount)", icon: "arrow.triangle.2.circlepath", color: .blue)
                    TransferMetric(title: "Trasferiti nella sessione", value: ByteCountFormatter.string(fromByteCount: totals.values.reduce(0, +), countStyle: .file), icon: "checkmark.circle.fill", color: .green)
                }
                GroupBox("Profili") {
                    if connections.isEmpty {
                        ContentUnavailableView("Nessun profilo", systemImage: "externaldrive.badge.questionmark")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(connections) { connection in
                                TransferRow(
                                    connection: connection,
                                    status: statuses[connection.id] ?? .disconnected,
                                    snapshot: snapshots[connection.id] ?? .idle,
                                    sessionBytes: totals[connection.id] ?? 0
                                )
                                if connection.id != connections.last?.id { Divider() }
                            }
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 980, alignment: .leading)
        }
    }
}

private struct TransferRow: View {
    let connection: RemoteConnection
    let status: MountStatus
    let snapshot: TransferSnapshot
    let sessionBytes: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(connection.name).fontWeight(.semibold)
                Text(LocalizedStringKey(status.localizationKey)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: Int64(snapshot.speedBytesPerSecond), countStyle: .file) + "/s").monospacedDigit()
            }
            if let progress = snapshot.progress {
                ProgressView(value: progress)
            }
            HStack {
                Text(snapshot.currentFile ?? "Nessun file in trasferimento").lineLimit(1)
                Spacer()
                if let eta = snapshot.etaSeconds { Text("ETA \(eta)s") }
                Text(ByteCountFormatter.string(fromByteCount: sessionBytes, countStyle: .file))
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }

    private var statusColor: Color {
        switch status {
        case .mounted: return .green
        case .connecting, .reconnecting, .disconnecting: return .orange
        case .failed: return .red
        case .disconnected: return .secondary
        }
    }
}

private struct TransferMetric: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}
