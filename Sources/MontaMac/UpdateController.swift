import Combine
import Foundation
import Sparkle
import MontaMacCore

@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var isConfigured: Bool
    private let controller: SPUStandardUpdaterController
    private let failureHandler: (Error) -> Void

    init(bundle: Bundle = .main, failureHandler: @escaping (Error) -> Void = { _ in }) {
        let configuration = UpdateConfiguration(infoDictionary: bundle.infoDictionary)
        isConfigured = configuration.isConfigured
        self.failureHandler = failureHandler
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        if configuration.isConfigured {
            do { try controller.updater.start() }
            catch {
                isConfigured = false
                failureHandler(error)
            }
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
