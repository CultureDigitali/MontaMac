import Foundation

public struct AppCommandAvailability: Equatable, Sendable {
    public let canEdit: Bool
    public let canDelete: Bool
    public let canMount: Bool
    public let canUnmount: Bool
    public let canOpenFinder: Bool
    public let canRefreshStatistics: Bool

    public init(hasSelection: Bool, status: MountStatus) {
        guard hasSelection else {
            canEdit = false
            canDelete = false
            canMount = false
            canUnmount = false
            canOpenFinder = false
            canRefreshStatistics = false
            return
        }

        switch status {
        case .disconnected, .failed:
            canEdit = true
            canDelete = true
            canMount = true
            canUnmount = false
            canOpenFinder = false
            canRefreshStatistics = false
        case .mounted:
            canEdit = true
            canDelete = false
            canMount = false
            canUnmount = true
            canOpenFinder = true
            canRefreshStatistics = true
        case .connecting, .disconnecting:
            canEdit = false
            canDelete = false
            canMount = false
            canUnmount = false
            canOpenFinder = false
            canRefreshStatistics = false
        case .reconnecting:
            canEdit = false
            canDelete = false
            canMount = false
            canUnmount = true
            canOpenFinder = false
            canRefreshStatistics = false
        }
    }
}
