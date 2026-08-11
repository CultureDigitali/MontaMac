import Foundation

public final class IssueStore {
    public let fileURL: URL
    private let maximumCount: Int

    public init(
        fileURL: URL = ConnectionStore.defaultURL.deletingLastPathComponent().appendingPathComponent("issues-v1.json"),
        maximumCount: Int = 100
    ) {
        self.fileURL = fileURL
        self.maximumCount = maximumCount
    }

    public func record(_ issue: AppIssue) throws {
        var issues = try load()
        if let last = issues.last,
           last.code == issue.code,
           last.profileID == issue.profileID,
           last.arguments == issue.arguments {
            var merged = last
            merged.timestamp = issue.timestamp
            merged.occurrenceCount += 1
            issues[issues.count - 1] = merged
        } else {
            issues.append(issue)
        }
        try save(Array(issues.suffix(maximumCount)))
    }

    public func recent(limit: Int = 100) throws -> [AppIssue] {
        Array(try load().suffix(max(0, limit)))
    }

    public func clear() throws {
        try save([])
    }

    private func load() throws -> [AppIssue] {
        try SecureFileStore.secureExistingFile(fileURL)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([AppIssue].self, from: Data(contentsOf: fileURL))
    }

    private func save(_ issues: [AppIssue]) throws {
        try SecureFileStore.write(JSONEncoder().encode(issues), to: fileURL)
    }
}
