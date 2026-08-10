import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var step = 0
    private let steps = [
        ("Benvenuto in MontaMac", "Collega i tuoi drive FTP, SFTP e WebDAV direttamente nel Finder.", "externaldrive.badge.plus"),
        ("Prima di iniziare", "Assicurati di avere rclone e FUSE-T installati. La guida spiega ogni passaggio.", "checklist"),
        ("Crea il primo drive", "Aggiungi server, utente e cartella locale. La password resta nel Portachiavi macOS.", "lock.shield.fill"),
    ]
    var body: some View { let item = steps[step]; VStack(spacing: 22) { Image(systemName: item.2).font(.system(size: 48)).foregroundStyle(.tint); Text(LocalizedStringKey(item.0)).font(.title.bold()); Text(LocalizedStringKey(item.1)).multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 360); HStack { if step > 0 { Button("Indietro") { step -= 1 } }; Spacer(); Button { if step == steps.indices.last { isPresented = false } else { step += 1 } } label: { Text(LocalizedStringKey(step == steps.indices.last ? "Inizia" : "Continua")) }.buttonStyle(.borderedProminent) } }.padding(32).frame(width: 460) }
}
