import Foundation

public struct MountRecoveryPolicy: Sendable, Equatable {
    public let delays: [TimeInterval]

    public init(delays: [TimeInterval] = [2, 5, 15]) {
        self.delays = delays
    }

    public func delay(forAttempt attempt: Int) -> TimeInterval? {
        guard attempt > 0, attempt <= delays.count else { return nil }
        return delays[attempt - 1]
    }
}
