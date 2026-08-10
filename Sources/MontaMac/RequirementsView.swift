import AppKit
import SwiftUI
import MontaMacCore

struct RequirementsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var statuses = RequirementChecker().check()
    @State private var isConfirmationPresented = false
    @State private var errorMessage: String?

    private var isReady: Bool { statuses.allSatisfy(\.isInstalled) }
    private var command: String? { RequirementChecker.installationCommand(for: statuses) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Requisiti di sistema", systemImage: "checklist")
                    .font(.title2.bold())
                Spacer()
                Button("Chiudi") { dismiss() }
            }

            Text(LocalizedStringKey(isReady ? "Tutto pronto per montare i drive." : "Per montare i drive occorrono rclone e FUSE-T."))
                .foregroundStyle(.secondary)

            List(statuses) { status in
                HStack {
                    Image(systemName: status.isInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(status.isInstalled ? .green : .orange)
                    Text(status.title)
                    Spacer()
                    Text(LocalizedStringKey(status.isInstalled ? "Installato" : "Da installare"))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
            }
            .frame(height: 150)

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Riesegui controllo", action: refresh)
                Spacer()
                if !isReady {
                    Button("Installa requisiti") { isConfirmationPresented = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 520)
        .alert("Aprire Terminale?", isPresented: $isConfirmationPresented) {
            Button("Annulla", role: .cancel) { }
            Button("Continua") { openInstaller() }
        } message: {
            Text("Il Terminale installerà solo i componenti mancanti e potrà chiedere la password amministratore.")
        }
    }

    private func refresh() {
        statuses = RequirementChecker().check()
        errorMessage = nil
    }

    private func openInstaller() {
        guard let command else { return }
        do {
            let supportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("MontaMac", isDirectory: true)
            let scriptURL = supportURL.appendingPathComponent("install-requirements.command")
            let script = RequirementInstallScript.make(command: command)
            try SecureFileStore.write(Data(script.utf8), to: scriptURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

            let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([scriptURL], withApplicationAt: terminalURL, configuration: configuration) { _, error in
                if let error {
                    Task { @MainActor in
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
