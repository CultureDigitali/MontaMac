import AppKit
import MontaMacCore
import SwiftUI

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Crediti").font(.title2.bold())
                Spacer()
                Button("Chiudi") { dismiss() }
            }
            .padding(24)

            ScrollView {
                VStack(spacing: 20) {
                    logo

                    VStack(spacing: 7) {
                        Text("MontaMac").font(.largeTitle.bold())
                        Text("Creato da Luigi Strazzullo per Culture Digitali Srl")
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text("Fondatore e amministratore, imprenditore e consulente digitale")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    GroupBox {
                        VStack(spacing: 12) {
                            contactRow("Sito web", value: "culturedigitali.eu", destination: CreditsContent.website)
                            Divider()
                            if let emailURL = CreditsContent.emailURL {
                                contactRow("Email", value: CreditsContent.email, destination: emailURL)
                                Divider()
                            }
                            if let phoneURL = CreditsContent.phoneURL {
                                contactRow("Telefono", value: CreditsContent.phone, destination: phoneURL)
                                Divider()
                            }
                            LabeledContent("Sede", value: CreditsContent.address)
                            Divider()
                            LabeledContent("Partita IVA", value: CreditsContent.vatNumber)
                        }
                        .padding(8)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .frame(width: 620, height: 600)
    }

    @ViewBuilder
    private var logo: some View {
        if let url = Bundle.main.url(forResource: "MontaMac-logo", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .accentColor.opacity(0.22), radius: 18, y: 8)
        } else {
            Image(systemName: "externaldrive.badge.checkmark")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .frame(width: 150, height: 150)
        }
    }

    private func contactRow(_ label: LocalizedStringKey, value: String, destination: URL) -> some View {
        LabeledContent(label) {
            Link(value, destination: destination)
        }
    }
}
