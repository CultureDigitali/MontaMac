import SwiftUI
import MontaMacCore

struct ConnectionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var connection: RemoteConnection
    @State private var password = ""
    let onSave: (RemoteConnection, String) -> Void
    init(connection: RemoteConnection, onSave: @escaping (RemoteConnection, String) -> Void) { _connection = State(initialValue: connection); self.onSave = onSave }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configurazione drive").font(.title2.bold())
            Form {
                TextField("Nome", text: $connection.name)
                Picker("Protocollo", selection: $connection.protocolType) { ForEach(RemoteProtocol.allCases) { Text($0.title).tag($0) } }
                if connection.protocolType == .ftp {
                    Label("FTP non cifra credenziali e dati. Quando possibile usa SFTP o WebDAV HTTPS.", systemImage: "exclamationmark.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                TextField("Server", text: $connection.host); TextField("Porta", value: $connection.port, format: .number)
                TextField("Utente", text: $connection.username); SecureField("Password (Portachiavi)", text: $password)
                TextField("Percorso remoto", text: $connection.remotePath); TextField("Cartella locale", text: $connection.mountPath)
                TextField("Cartella profilo", text: $connection.profileGroup)
                Picker("Limite cache", selection: $connection.cacheLimit) {
                    Text("Predefinito").tag(nil as CacheLimit?)
                    ForEach(CacheLimit.allCases) { limit in
                        Text(LocalizedStringKey(limit.titleKey)).tag(Optional(limit))
                    }
                }
                Toggle("Preferito", isOn: $connection.isFavorite)
            }.formStyle(.grouped)
            if let error = connection.validationError { Text(LocalizedStringKey(error)).foregroundStyle(.red).font(.caption) }
            HStack { Spacer(); Button("Annulla") { dismiss() }; Button("Salva") { onSave(connection, password) }.buttonStyle(.borderedProminent).disabled(connection.validationError != nil) }
        }.padding(24).frame(width: 540)
    }
}
