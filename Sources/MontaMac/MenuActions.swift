import SwiftUI
import MontaMacCore

struct MenuActions {
    let availability: AppCommandAvailability
    let newProfile: () -> Void
    let editProfile: () -> Void
    let requestDelete: () -> Void
    let mount: () -> Void
    let unmount: () -> Void
    let openFinder: () -> Void
    let refreshStatistics: () -> Void
    let showDashboard: () -> Void
    let showTransfers: () -> Void
    let showCache: () -> Void
    let showIssues: () -> Void
    let showProfiles: () -> Void
    let showFavorites: () -> Void
    let showMounted: () -> Void
    let showRequirements: () -> Void
    let showHelp: () -> Void
    let showOnboarding: () -> Void
    let showDiagnostics: () -> Void
}

private struct MenuActionsKey: FocusedValueKey {
    typealias Value = MenuActions
}

extension FocusedValues {
    var menuActions: MenuActions? {
        get { self[MenuActionsKey.self] }
        set { self[MenuActionsKey.self] = newValue }
    }
}
