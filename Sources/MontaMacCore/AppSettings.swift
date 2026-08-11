import Combine
import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case italian = "it"
    case english = "en"
    case french = "fr"
    case spanish = "es"

    public var id: String { rawValue }
    public var locale: Locale { Locale(identifier: rawValue) }
    public var nativeName: String {
        switch self {
        case .italian: return "Italiano"
        case .english: return "English"
        case .french: return "Français"
        case .spanish: return "Español"
        }
    }
}

@MainActor
public final class AppSettings: ObservableObject {
    nonisolated public static let languageKey = "MontaMac.selectedLanguage"
    nonisolated public static let automaticReconnectKey = "MontaMac.automaticReconnect"
    nonisolated public static let defaultCacheLimitKey = "MontaMac.defaultCacheLimit"
    nonisolated public static let reservedFreeSpaceKey = "MontaMac.reservedFreeSpaceGB"
    nonisolated public static let automaticUpdateChecksKey = "MontaMac.automaticUpdateChecks"

    @Published public private(set) var language: AppLanguage
    @Published public private(set) var automaticReconnect: Bool
    @Published public private(set) var defaultCacheLimit: CacheLimit
    @Published public private(set) var reservedFreeSpaceGB: Int
    @Published public private(set) var automaticUpdateChecks: Bool
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: Self.languageKey) ?? "") ?? .italian
        automaticReconnect = defaults.object(forKey: Self.automaticReconnectKey) == nil ? true : defaults.bool(forKey: Self.automaticReconnectKey)
        defaultCacheLimit = CacheLimit(rawValue: defaults.string(forKey: Self.defaultCacheLimitKey) ?? "") ?? .fiveGB
        reservedFreeSpaceGB = defaults.object(forKey: Self.reservedFreeSpaceKey) == nil ? 5 : max(1, defaults.integer(forKey: Self.reservedFreeSpaceKey))
        automaticUpdateChecks = defaults.object(forKey: Self.automaticUpdateChecksKey) == nil ? true : defaults.bool(forKey: Self.automaticUpdateChecksKey)
    }

    public var locale: Locale { language.locale }

    nonisolated public static func automaticReconnectValue(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: automaticReconnectKey) == nil ? true : defaults.bool(forKey: automaticReconnectKey)
    }

    public func setLanguage(_ language: AppLanguage) {
        self.language = language
        defaults.set(language.rawValue, forKey: Self.languageKey)
    }

    public func setAutomaticReconnect(_ enabled: Bool) {
        automaticReconnect = enabled
        defaults.set(enabled, forKey: Self.automaticReconnectKey)
    }

    public func setDefaultCacheLimit(_ limit: CacheLimit) {
        defaultCacheLimit = limit
        defaults.set(limit.rawValue, forKey: Self.defaultCacheLimitKey)
    }

    public func setReservedFreeSpaceGB(_ value: Int) {
        reservedFreeSpaceGB = max(1, value)
        defaults.set(reservedFreeSpaceGB, forKey: Self.reservedFreeSpaceKey)
    }

    public func setAutomaticUpdateChecks(_ enabled: Bool) {
        automaticUpdateChecks = enabled
        defaults.set(enabled, forKey: Self.automaticUpdateChecksKey)
    }

    public func localized(_ key: String, bundle: Bundle = .main) -> String {
        guard let languageURL = bundle.url(forResource: language.rawValue, withExtension: "lproj"),
              let languageBundle = Bundle(url: languageURL) else { return key }
        return languageBundle.localizedString(forKey: key, value: key, table: nil)
    }
}
