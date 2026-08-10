import AppKit
import SwiftUI
import MontaMacCore

struct DashboardView: View {
    let summary: ActivitySummary
    let events: [ActivityEvent]
    let connections: [RemoteConnection]
    let cacheBytes: Int64
    let onAdd: () -> Void
    let onToggleProfile: (RemoteConnection) -> Void
    let onRefresh: () -> Void
    private let metricColumns = [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 12)]

    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 14) {
                LogoMark().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) { Text("Dashboard").font(.largeTitle.bold()); Text("Il controllo completo dei tuoi drive remoti.").foregroundStyle(.secondary) }
            }
            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                MetricCard(title: "Drive configurati", value: "\(connections.count)", icon: "externaldrive.fill", color: .blue)
                MetricCard(title: "Trasferiti", value: formattedBytes(summary.transferredBytes), icon: "arrow.left.arrow.right", color: .cyan)
                MetricCard(title: "Cache temporanea", value: formattedBytes(cacheBytes), icon: "internaldrive.fill", color: .orange, subtitle: "Aggiornamento automatico")
                MetricCard(title: "Errori", value: "\(summary.failureCount)", icon: "exclamationmark.triangle.fill", color: summary.failureCount == 0 ? .green : .orange)
                MetricCard(title: "Sessioni", value: "\(summary.mountCount)", icon: "clock.fill", color: .indigo)
            }
            GroupBox("Attività recente") {
                if events.isEmpty { ContentUnavailableView("Nessuna attività", systemImage: "chart.line.uptrend.xyaxis", description: Text("Monta un drive per iniziare a raccogliere statistiche.")) }
                else { ForEach(events, id: \.date) { event in HStack { Image(systemName: icon(for: event)).foregroundStyle(.tint); Text(LocalizedStringKey(event.title)); Spacer(); Text(event.date, style: .relative).foregroundStyle(.secondary) }.padding(.vertical, 4) } }
            }
            if !connections.filter(\.isFavorite).isEmpty {
                GroupBox("Preferiti") {
                    ForEach(connections.filter(\.isFavorite)) { connection in
                        Button(connection.name, systemImage: "externaldrive.badge.plus") { onToggleProfile(connection) }
                            .buttonStyle(.borderless)
                            .padding(.vertical, 3)
                    }
                }
            }
            if connections.isEmpty { Button("Aggiungi il primo drive", systemImage: "plus.circle.fill", action: onAdd).buttonStyle(.borderedProminent) }
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "heart.fill").foregroundStyle(.red.gradient).font(.caption)
                Link(destination: CreditsContent.website) {
                    Text("Creato da Luigi Strazzullo per Culture Digitali Srl")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Text("MontaMac").fontWeight(.semibold).foregroundStyle(.tertiary)
            }
            .font(.caption)
            .padding(.top, 2)
        }.padding(32).frame(maxWidth: 980, alignment: .leading) }
        .task {
            onRefresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(10)) }
                catch { return }
                onRefresh()
            }
        }
    }
    private func icon(for event: ActivityEvent) -> String { switch event { case .mounted: return "checkmark.circle.fill"; case .unmounted: return "eject.fill"; case .transfer: return "arrow.left.arrow.right"; case .failure: return "exclamationmark.triangle.fill" } }
    private func formattedBytes(_ bytes: Int64) -> String {
        bytes == 0 ? "0 KB" : ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct LogoMark: View {
    var body: some View {
        Group { if let url = Bundle.main.url(forResource: "MontaMac-logo", withExtension: "png"), let image = NSImage(contentsOf: url) { Image(nsImage: image).resizable().scaledToFit() } else { Image(systemName: "externaldrive.fill").resizable().scaledToFit().foregroundStyle(.tint) } }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let color: Color
    var subtitle: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            Text(value).font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.72)
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let subtitle { Text(subtitle).font(.caption2).foregroundStyle(.tertiary) }
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}
