import Foundation

public enum CacheLimit: String, Codable, CaseIterable, Identifiable, Sendable {
    case oneGB
    case fiveGB
    case tenGB
    case twentyFiveGB
    case unlimited

    public var id: String { rawValue }
    public var gigabytes: Int? {
        switch self {
        case .oneGB: return 1
        case .fiveGB: return 5
        case .tenGB: return 10
        case .twentyFiveGB: return 25
        case .unlimited: return nil
        }
    }
    public var titleKey: String {
        switch self {
        case .oneGB: return "1 GB"
        case .fiveGB: return "5 GB"
        case .tenGB: return "10 GB"
        case .twentyFiveGB: return "25 GB"
        case .unlimited: return "Senza limite"
        }
    }
}

public struct CachePolicy: Equatable, Sendable {
    public var limit: CacheLimit
    public var reservedFreeSpaceGB: Int

    public init(limit: CacheLimit, reservedFreeSpaceGB: Int) {
        self.limit = limit
        self.reservedFreeSpaceGB = max(1, reservedFreeSpaceGB)
    }

    public static let `default` = CachePolicy(limit: .fiveGB, reservedFreeSpaceGB: 5)

    public var rcloneArguments: [String] {
        var arguments: [String] = []
        if let gigabytes = limit.gigabytes {
            arguments += ["--vfs-cache-max-size", "\(gigabytes)G"]
        }
        arguments += [
            "--vfs-cache-min-free-space", "\(reservedFreeSpaceGB)G",
            "--vfs-cache-poll-interval", "1m",
        ]
        return arguments
    }
}

public struct CachePolicyResolver {
    private let defaults: UserDefaults?
    private let fallbackLimit: CacheLimit
    private let fallbackReservedFreeSpaceGB: Int

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        fallbackLimit = .fiveGB
        fallbackReservedFreeSpaceGB = 5
    }

    public init(defaultLimit: CacheLimit, reservedFreeSpaceGB: Int) {
        defaults = nil
        fallbackLimit = defaultLimit
        fallbackReservedFreeSpaceGB = reservedFreeSpaceGB
    }

    public func policy(for connection: RemoteConnection) -> CachePolicy {
        let savedLimit = defaults.flatMap { CacheLimit(rawValue: $0.string(forKey: AppSettings.defaultCacheLimitKey) ?? "") }
        let savedReserve = defaults?.object(forKey: AppSettings.reservedFreeSpaceKey) == nil
            ? nil : defaults?.integer(forKey: AppSettings.reservedFreeSpaceKey)
        return CachePolicy(
            limit: connection.cacheLimit ?? savedLimit ?? fallbackLimit,
            reservedFreeSpaceGB: savedReserve ?? fallbackReservedFreeSpaceGB
        )
    }
}
