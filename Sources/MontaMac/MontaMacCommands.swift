import SwiftUI
import MontaMacCore

struct MontaMacCommands: Commands {
    @ObservedObject var settings: AppSettings
    @FocusedValue(\.menuActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(settings.localized("Nuovo profilo")) { actions?.newProfile() }
                .keyboardShortcut("n", modifiers: .command)
            Button(settings.localized("Modifica profilo")) { actions?.editProfile() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(actions?.availability.canEdit != true)
            Button(settings.localized("Elimina profilo")) { actions?.requestDelete() }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(actions?.availability.canDelete != true)
        }

        CommandMenu(settings.localized("Drive")) {
            Button(settings.localized("Monta")) { actions?.mount() }
                .keyboardShortcut("m", modifiers: .command)
                .disabled(actions?.availability.canMount != true)
            Button(settings.localized("Smonta")) { actions?.unmount() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(actions?.availability.canUnmount != true)
            Divider()
            Button(settings.localized("Apri nel Finder")) { actions?.openFinder() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(actions?.availability.canOpenFinder != true)
            Button(settings.localized("Aggiorna statistiche")) { actions?.refreshStatistics() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(actions?.availability.canRefreshStatistics != true)
            Divider()
            Button(settings.localized("Requisiti di sistema")) { actions?.showRequirements() }
                .disabled(actions == nil)
        }

        CommandMenu(settings.localized("Visualizza")) {
            Button(settings.localized("Dashboard")) { actions?.showDashboard() }.keyboardShortcut("1", modifiers: .command)
            Button(settings.localized("Trasferimenti")) { actions?.showTransfers() }.keyboardShortcut("2", modifiers: .command)
            Button(settings.localized("Gestione cache")) { actions?.showCache() }.keyboardShortcut("3", modifiers: .command)
            Button(settings.localized("Problemi")) { actions?.showIssues() }.keyboardShortcut("4", modifiers: .command)
            Divider()
            Button(settings.localized("Profili")) { actions?.showProfiles() }
            Button(settings.localized("Preferiti")) { actions?.showFavorites() }
            Button(settings.localized("Montati")) { actions?.showMounted() }
        }

        CommandMenu(settings.localized("Lingua")) {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    settings.setLanguage(language)
                } label: {
                    HStack {
                        Text(language.nativeName)
                        if settings.language == language { Image(systemName: "checkmark") }
                    }
                }
            }
        }

        CommandGroup(replacing: .help) {
            Button(settings.localized("Guida MontaMac")) { actions?.showHelp() }
                .keyboardShortcut("?", modifiers: .command)
            Button(settings.localized("Mostra introduzione")) { actions?.showOnboarding() }
            Button(settings.localized("Diagnostica")) { actions?.showDiagnostics() }
                .disabled(actions?.availability.canEdit != true)
        }
    }
}
