import Combine
import Foundation
import Sparkle
import MontaMacCore

@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var isConfigured: Bool
    private let controller: SPUStandardUpdaterController

    init(bundle: Bundle = .main) {
        let configuration = UpdateConfiguration(infoDictionary: bundle.infoDictionary)
        isConfigured = configuration.isConfigured
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        if configuration.isConfigured {
            do { try controller.updater.start() }
            catch { isConfigured = false }
        }
    }

    func setAutomaticChecks(_ enabled: Bool) {
        guard isConfigured else { return }
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        guard isConfigured else { return }
        controller.checkForUpdates(nil)
    }
}
