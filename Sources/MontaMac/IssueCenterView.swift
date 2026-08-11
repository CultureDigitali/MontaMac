import AppKit
import SwiftUI
import MontaMacCore

struct IssueCenterView: View {
    @ObservedObject var issueCenter: IssueCenter
    @EnvironmentObject private var settings: AppSettings
    let connections: [RemoteConnection]
    let statuses: [UUID: MountStatus]
    let logs: [UUID: [String]]
    let onRecovery: (AppIssue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Problemi recenti", systemImage: "exclamationmark.bubble.fill").font(.title.bold())
                Spacer()
                Button("Esporta diagnostica", systemImage: "square.and.arrow.up", action: exportDiagnostics)
                Button("Svuota", role: .destructive, action: issueCenter.clear).disabled(issueCenter.issues.isEmpty)
            }
            if issueCenter.issues.isEmpty {
                ContentUnavailableView("Nessun problema", systemImage: "checkmark.shield.fill", description: Text("MontaMac non ha registrato errori recenti."))
            } else {
                List(issueCenter.issues.reversed()) { issue in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(for: issue.severity)).foregroundStyle(color(for: issue.severity))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizedMessage(issue)).fontWeight(.medium)
                            HStack {
                                Text(issue.timestamp, style: .relative)
                                if issue.occurrenceCount > 1 { Text("×\(issue.occurrenceCount)") }
                            }.font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if issue.recovery != nil { Button("Riprova") { onRecovery(issue) } }
                    }.padding(.vertical, 4)
                }
            }
        }.padding(28).frame(minWidth: 680, minHeight: 460)
    }

    private func localizedMessage(_ issue: AppIssue) -> String {
        let format = settings.localized(issue.code.rawValue)
        return String(format: format, locale: settings.locale, arguments: issue.arguments)
    }

    private func exportDiagnostics() {
        let report = connections.map { connection in
            DiagnosticsService().makeReport(
                connection: connection,
                status: statuses[connection.id] ?? .disconnected,
                logs: logs[connection.id] ?? [],
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.2.0"
            )
        }.joined(separator: "\n\n---\n\n")
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MontaMac-diagnostics-\(Int(Date.now.timeIntervalSince1970)).txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try report.write(to: url, atomically: true, encoding: .utf8) }
        catch { issueCenter.report(AppIssue(code: .diagnosticsExportFailed, arguments: [error.localizedDescription], severity: .error)) }
    }

    private func icon(for severity: IssueSeverity) -> String {
        switch severity { case .information: "info.circle.fill"; case .warning: "exclamationmark.triangle.fill"; case .error: "xmark.octagon.fill" }
    }
    private func color(for severity: IssueSeverity) -> Color {
        switch severity { case .information: .blue; case .warning: .orange; case .error: .red }
    }
}

struct IssueBanner: View {
    let issue: AppIssue
    let message: String
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).lineLimit(2)
            Spacer()
            Button("Apri", action: onOpen).buttonStyle(.borderless)
            Button(action: onDismiss) { Image(systemName: "xmark") }.buttonStyle(.borderless).accessibilityLabel("Chiudi")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8, y: 3)
    }
}
