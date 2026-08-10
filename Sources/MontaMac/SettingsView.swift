import SwiftUI
import MontaMacCore

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var requirements = RequirementChecker().check()
    @State private var isCreditsPresented = false

    var body: some View {
        Form {
            Section("Lingua") {
                Picker("Lingua dell’app", selection: Binding(
                    get: { settings.language },
                    set: { language in settings.setLanguage(language) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language)
                    }
                }
            }

            Section("Requisiti di sistema") {
                ForEach(requirements) { requirement in
                    LabeledContent(requirement.title, value: requirement.isInstalled ? "Installato" : "Da installare")
                }
                Button("Riesegui controllo") { requirements = RequirementChecker().check() }
            }

            Section("Informazioni") {
                LabeledContent(
                    "Versione",
                    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.1.0"
                )
                Button("Crediti") { isCreditsPresented = true }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520)
        .sheet(isPresented: $isCreditsPresented) { CreditsView() }
    }
}
