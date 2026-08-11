import SwiftUI
import MontaMacCore

@main
struct MontaMacApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var updates = UpdateController()

    init() {
        try? LocalDataSecurityMigration().run()
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(settings)
                .environmentObject(updates)
                .environment(\.locale, settings.locale)
        }
        .windowStyle(.hiddenTitleBar)
        .commands { MontaMacCommands(settings: settings, updates: updates) }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(updates)
                .environment(\.locale, settings.locale)
        }
    }
}
