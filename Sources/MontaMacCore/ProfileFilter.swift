import Foundation

public enum ProfileScope: Equatable, Sendable {
    case all
    case favorites
    case mounted
    case group(String)
}

public enum ProfileFilter {
    public static func profiles(
        _ profiles: [RemoteConnection],
        scope: ProfileScope,
        query: String,
        statusFor: (RemoteConnection) -> MountStatus
    ) -> [RemoteConnection] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return profiles
            .filter { profile in matches(profile, scope: scope, status: statusFor(profile)) }
            .filter { profile in matches(profile, query: query) }
            .sorted(by: isOrderedBefore)
    }

    public static func groups(in profiles: [RemoteConnection]) -> [String] {
        Array(Set(profiles.map(\.profileGroup).filter { $0 != RemoteConnection.defaultProfileGroup }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func matches(_ profile: RemoteConnection, scope: ProfileScope, status: MountStatus) -> Bool {
        switch scope {
        case .all: return true
        case .favorites: return profile.isFavorite
        case .mounted:
            if case .mounted = status { return true }
            return false
        case let .group(group): return profile.profileGroup == group
        }
    }

    private static func matches(_ profile: RemoteConnection, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return [profile.name, profile.host, profile.protocolType.title, profile.profileGroup]
            .contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    private static func isOrderedBefore(_ lhs: RemoteConnection, _ rhs: RemoteConnection) -> Bool {
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
        let lhsDate = lhs.lastUsedAt ?? .distantPast
        let rhsDate = rhs.lastUsedAt ?? .distantPast
        if lhsDate != rhsDate { return lhsDate > rhsDate }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
