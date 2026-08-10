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
    public static let languageKey = "MontaMac.selectedLanguage"

    @Published public private(set) var language: AppLanguage
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: Self.languageKey) ?? "") ?? .italian
    }

    public var locale: Locale { language.locale }

    public func setLanguage(_ language: AppLanguage) {
        self.language = language
        defaults.set(language.rawValue, forKey: Self.languageKey)
    }

    public func localized(_ key: String, bundle: Bundle = .main) -> String {
        guard let languageURL = bundle.url(forResource: language.rawValue, withExtension: "lproj"),
              let languageBundle = Bundle(url: languageURL) else { return key }
        return languageBundle.localizedString(forKey: key, value: key, table: nil)
    }
}
