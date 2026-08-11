import Foundation

public enum AppIssueCode: String, Codable, CaseIterable, Sendable {
    case profileSaveFailed = "issue.profile.save_failed"
    case credentialSaveFailed = "issue.credential.save_failed"
    case activityWriteFailed = "issue.activity.write_failed"
    case mountInterrupted = "issue.mount.interrupted"
    case mountRecoveryExhausted = "issue.mount.recovery_exhausted"
    case cacheCleanupFailed = "issue.cache.cleanup_failed"
    case diagnosticsExportFailed = "issue.diagnostics.export_failed"
    case updateCheckFailed = "issue.update.check_failed"
}

public enum IssueSeverity: String, Codable, Sendable {
    case information
    case warning
    case error
}

public enum IssueRecovery: String, Codable, Sendable {
    case retry
    case openRequirements
    case openDiagnostics
}

public struct AppIssue: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let code: AppIssueCode
    public let profileID: UUID?
    public let arguments: [String]
    public let severity: IssueSeverity
    public var timestamp: Date
    public var occurrenceCount: Int
    public let recovery: IssueRecovery?

    public init(
        id: UUID = UUID(),
        code: AppIssueCode,
        profileID: UUID? = nil,
        arguments: [String] = [],
        severity: IssueSeverity,
        timestamp: Date = .now,
        occurrenceCount: Int = 1,
        recovery: IssueRecovery? = nil
    ) {
        self.id = id
        self.code = code
        self.profileID = profileID
        self.arguments = arguments
        self.severity = severity
        self.timestamp = timestamp
        self.occurrenceCount = occurrenceCount
        self.recovery = recovery
    }
}
