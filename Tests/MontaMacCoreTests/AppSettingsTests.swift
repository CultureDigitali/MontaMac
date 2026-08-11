import XCTest
@testable import MontaMacCore

@MainActor
final class AppSettingsTests: XCTestCase {
    func testUnknownLanguageFallsBackToItalian() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("de", forKey: AppSettings.languageKey)

        XCTAssertEqual(AppSettings(defaults: defaults).language, .italian)
    }

    func testSelectedLanguagePersists() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)

        settings.setLanguage(.french)

        XCTAssertEqual(AppSettings(defaults: defaults).language, .french)
    }

    func testSupportedLanguagesExposeExpectedLocales() {
        XCTAssertEqual(AppLanguage.allCases.map(\.rawValue), ["it", "en", "fr", "es"])
        XCTAssertEqual(AppLanguage.spanish.locale.identifier, "es")
    }

    func testLocalizedStringUsesSelectedLanguageBundle() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)
        settings.setLanguage(.french)
        let bundleURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        let frenchURL = bundleURL.appendingPathComponent("fr.lproj")
        try FileManager.default.createDirectory(at: frenchURL, withIntermediateDirectories: true)
        try "\"Hello\" = \"Bonjour\";".write(to: frenchURL.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)

        let bundle = try XCTUnwrap(Bundle(path: bundleURL.path))

        XCTAssertEqual(settings.localized("Hello", bundle: bundle), "Bonjour")
    }

    func testReliabilityAndCachePreferencesPersist() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)

        settings.setAutomaticReconnect(false)
        settings.setDefaultCacheLimit(.twentyFiveGB)
        settings.setReservedFreeSpaceGB(9)
        settings.setAutomaticUpdateChecks(false)

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertFalse(reloaded.automaticReconnect)
        XCTAssertEqual(reloaded.defaultCacheLimit, .twentyFiveGB)
        XCTAssertEqual(reloaded.reservedFreeSpaceGB, 9)
        XCTAssertFalse(reloaded.automaticUpdateChecks)
    }
}
