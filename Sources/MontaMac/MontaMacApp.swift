import SwiftUI
import MontaMacCore

@main
struct MontaMacApp: App {
    @StateObject private var settings = AppSettings()

    init() {
        try? LocalDataSecurityMigration().run()
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(settings)
                .environment(\.locale, settings.locale)
        }
        .windowStyle(.hiddenTitleBar)
        .commands { MontaMacCommands(settings: settings) }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environment(\.locale, settings.locale)
        }
    }
}
