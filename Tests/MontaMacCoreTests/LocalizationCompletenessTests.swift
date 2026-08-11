import XCTest

final class LocalizationCompletenessTests: XCTestCase {
    func testEveryLanguageHasExactlyTheSameKeys() throws {
        let root = projectRoot
        let dictionaries = try ["it", "en", "fr", "es"].map { language in
            try localizationDictionary(language: language, projectRoot: root)
        }
        let italianKeys = Set(dictionaries[0].keys)

        for dictionary in dictionaries.dropFirst() {
            XCTAssertEqual(Set(dictionary.keys), italianKeys)
        }
    }

    func testEveryLanguageContainsRequiredApplicationKeys() throws {
        let projectRoot = projectRoot
        let required = [
            "Nuovo profilo", "Modifica profilo", "Elimina profilo", "Monta", "Smonta",
            "Apri nel Finder", "Aggiorna statistiche", "Requisiti di sistema", "Dashboard",
            "Profili", "Preferiti", "Montati", "Guida MontaMac", "Mostra introduzione",
            "Diagnostica", "Impostazioni", "Lingua", "Configurazione drive",
            "Tutto pronto per montare i drive.", "Nessuna attività registrata.",
            "FTP non cifra credenziali e dati. Quando possibile usa SFTP o WebDAV HTTPS.",
            "Scegli una cartella locale sicura dentro il tuo profilo utente.",
            "Crediti", "Creato da Luigi Strazzullo per Culture Digitali Srl",
            "Fondatore e amministratore, imprenditore e consulente digitale",
            "Sito web", "Email", "Telefono", "Sede", "Partita IVA",
            "Cache temporanea", "Aggiornamento automatico",
        ]

        for language in ["it", "en", "fr", "es"] {
            let url = projectRoot.appendingPathComponent("Sources/MontaMac/Resources/\(language).lproj/Localizable.strings")
            let data = try Data(contentsOf: url)
            let dictionary = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
            let missing = required.filter { dictionary[$0] == nil }
            XCTAssertTrue(missing.isEmpty, "\(language) missing: \(missing.joined(separator: ", "))")
        }
    }

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func localizationDictionary(language: String, projectRoot: URL) throws -> [String: String] {
        let url = projectRoot.appendingPathComponent("Sources/MontaMac/Resources/\(language).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }
}
