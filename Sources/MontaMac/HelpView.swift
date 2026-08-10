import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private let topics = [("Installazione", "Installa rclone e FUSE-T prima di creare una connessione."), ("Nuovo drive", "Usa il pulsante Aggiungi drive, scegli il protocollo e indica una cartella locale assoluta."), ("Sicurezza", "Le password sono custodite nel Portachiavi; la configurazione rclone temporanea ha permessi stretti."), ("Problemi", "Apri Diagnostica e Log attività per vedere lo stato di rclone, cartella locale e mount.")]
    var body: some View { VStack(alignment: .leading, spacing: 16) { HStack { Text("Guida MontaMac").font(.title.bold()); Spacer(); Button("Chiudi") { dismiss() } }; TextField("Cerca nella guida", text: $query); List(topics.filter { query.isEmpty || $0.0.localizedCaseInsensitiveContains(query) || $0.1.localizedCaseInsensitiveContains(query) }, id: \.0) { topic in VStack(alignment: .leading) { Text(LocalizedStringKey(topic.0)).fontWeight(.semibold); Text(LocalizedStringKey(topic.1)).foregroundStyle(.secondary) }.padding(.vertical, 4) } }.padding(24).frame(width: 620, height: 460) }
}
