import SwiftUI
import MontaMacCore

@main
struct MontaMacApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var issueCenter: IssueCenter
    @StateObject private var updates: UpdateController

    init() {
        let center = IssueCenter()
        _settings = StateObject(wrappedValue: AppSettings())
        _issueCenter = StateObject(wrappedValue: center)
        _updates = StateObject(wrappedValue: UpdateController { [weak center] error in
            center?.report(AppIssue(code: .updateCheckFailed, arguments: [error.localizedDescription], severity: .warning))
        })
        try? LocalDataSecurityMigration().run()
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView(issueCenter: issueCenter)
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
