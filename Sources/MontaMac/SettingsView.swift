import SwiftUI
import MontaMacCore

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var updates: UpdateController
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

            Section("Affidabilità") {
                Toggle("Riconnessione automatica", isOn: Binding(
                    get: { settings.automaticReconnect },
                    set: { settings.setAutomaticReconnect($0) }
                ))
            }

            Section("Cache") {
                Picker("Limite predefinito", selection: Binding(
                    get: { settings.defaultCacheLimit },
                    set: { settings.setDefaultCacheLimit($0) }
                )) {
                    ForEach(CacheLimit.allCases) { limit in
                        Text(LocalizedStringKey(limit.titleKey)).tag(limit)
                    }
                }
                Stepper(
                    "Spazio libero riservato: \(settings.reservedFreeSpaceGB) GB",
                    value: Binding(
                        get: { settings.reservedFreeSpaceGB },
                        set: { settings.setReservedFreeSpaceGB($0) }
                    ),
                    in: 1...100
                )
                Text("Ogni profilo può usare un limite diverso.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.2.0"
                )
                Button("Crediti") { isCreditsPresented = true }
            }

            Section("Aggiornamenti") {
                Toggle("Controlla automaticamente", isOn: Binding(
                    get: { settings.automaticUpdateChecks },
                    set: {
                        settings.setAutomaticUpdateChecks($0)
                        updates.setAutomaticChecks($0)
                    }
                ))
                .disabled(!updates.isConfigured)
                Button("Controlla aggiornamenti…", action: updates.checkForUpdates)
                    .disabled(!updates.isConfigured)
                if !updates.isConfigured {
                    Text("Gli aggiornamenti automatici saranno disponibili nella release firmata.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520)
        .sheet(isPresented: $isCreditsPresented) { CreditsView() }
        .onAppear { updates.setAutomaticChecks(settings.automaticUpdateChecks) }
    }
}
