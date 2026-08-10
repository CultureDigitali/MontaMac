# MontaMac 2.1.0 Security & Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Distribuire MontaMac 2.1.0 con dati locali protetti, ciclo di vita sicuro delle credenziali e dei mount, compatibilità FTP non bloccante e maggiore stabilità.

**Architecture:** Il core riceve componenti piccoli e testabili per permessi, percorsi, pulizia profili e redazione dei log. `MountCoordinator` usa protocolli iniettabili per riconciliare mount esistenti, impedire duplicati e pulire configurazioni; l'app collega queste regole all'interfaccia senza nuovi popup.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Security.framework, XCTest, Swift Package Manager, rclone, pkgbuild, codesign, macOS 15+.

## Global Constraints

- FTP deve restare disponibile con un avviso discreto e non modale.
- Nessuna password deve essere scritta nei log o nei file JSON.
- Directory applicative e cache: `0700`; file sensibili: `0600`.
- Non eliminare aggressivamente la cache VFS per evitare perdita di upload in sospeso.
- Nessuna nuova dipendenza Swift esterna.
- Versione finale: `2.1.0`; installer: `dist/MontaMac-2.1.0.pkg`.
- Firma locale con Hardened Runtime; Developer ID e notarizzazione restano opzionali perché non sono presenti identità valide.
- Il progetto non è un repository Git: i commit non sono applicabili.

---

### Task 1: Permessi sicuri per dati locali

**Files:**
- Create: `Sources/MontaMacCore/SecureFileStore.swift`
- Create: `Tests/MontaMacCoreTests/SecureFileStoreTests.swift`
- Modify: `Sources/MontaMacCore/ConnectionStore.swift`
- Modify: `Sources/MontaMacCore/ActivityStore.swift`
- Modify: `Sources/MontaMacCore/RcloneConfigurationWriter.swift`

**Interfaces:**
- Produces: `SecureFileStore.secureDirectory(_:)`, `write(_:to:)`, `secureExistingFile(_:)`.
- Consumes: `FileManager`, `Data`, URL locali.

- [ ] **Step 1: Scrivere test rossi per `0700/0600`**

```swift
func testWriteCreatesPrivateDirectoryAndFile() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = root.appendingPathComponent("connections.json")
    defer { try? FileManager.default.removeItem(at: root) }

    try SecureFileStore.write(Data("[]".utf8), to: file)

    XCTAssertEqual(try permissions(root), 0o700)
    XCTAssertEqual(try permissions(file), 0o600)
}

func testSecureExistingFileRepairsLoosePermissions() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = root.appendingPathComponent("activity.json")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("[]".utf8).write(to: file)
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)

    try SecureFileStore.secureExistingFile(file)

    XCTAssertEqual(try permissions(root), 0o700)
    XCTAssertEqual(try permissions(file), 0o600)
}

private func permissions(_ url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
}
```

- [ ] **Step 2: Eseguire il test rosso**

Run: `swift test --filter SecureFileStoreTests`

Expected: FAIL perché `SecureFileStore` non esiste.

- [ ] **Step 3: Implementare il minimo**

```swift
public enum SecureFileStore {
    public static func secureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    public static func write(_ data: Data, to url: URL) throws {
        try secureDirectory(url.deletingLastPathComponent())
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static func secureExistingFile(_ url: URL) throws {
        try secureDirectory(url.deletingLastPathComponent())
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
```

- [ ] **Step 4: Usare il helper in store e configurazioni**

`ConnectionStore.save`, `ActivityStore.save` e `RcloneConfigurationWriter.write` devono passare da `SecureFileStore.write`. I metodi di lettura chiamano `secureExistingFile` prima di caricare file già presenti.

- [ ] **Step 5: Verificare il verde**

Run: `swift test --filter SecureFileStoreTests`

Expected: 2 test superati.

### Task 2: Identità rclone e percorsi sicuri

**Files:**
- Create: `Sources/MontaMacCore/MountPathPolicy.swift`
- Create: `Tests/MontaMacCoreTests/MountPathPolicyTests.swift`
- Modify: `Sources/MontaMacCore/Connection.swift`
- Modify: `Sources/MontaMacCore/RcloneConfigurationWriter.swift`
- Modify: `Tests/MontaMacCoreTests/ConnectionTests.swift`
- Modify: `Tests/MontaMacCoreTests/RcloneConfigurationWriterTests.swift`

**Interfaces:**
- Produces: `MountPathPolicy.validationError(for:)`, `RemoteConnection.rcloneRemoteName`.
- Consumes: percorso locale e UUID del profilo.

- [ ] **Step 1: Scrivere test rossi**

```swift
func testSystemPathsAreRejectedButUserPathIsAllowed() {
    for path in ["/", "/System", "/Library/Test", "/private/tmp"] {
        XCTAssertNotNil(MountPathPolicy.validationError(for: path), path)
    }
    XCTAssertNil(MountPathPolicy.validationError(for: "/Users/test/MontaMac/Drive"))
}

func testRcloneRemoteNameUsesOnlyUUID() {
    let id = UUID(uuidString: "13ADFB99-EE60-4FA3-8AA7-3E47A402EEB6")!
    let connection = RemoteConnection(id: id, name: "Nome ] malevolo", protocolType: .ftp, host: "example.test", port: 21, username: "user", remotePath: "/", mountPath: "/Users/test/MontaMac/Drive")
    XCTAssertEqual(connection.rcloneRemoteName, "montamac_13adfb99ee604fa38aa73e47a402eeb6")
    XCTAssertEqual(connection.remoteSpec, "montamac_13adfb99ee604fa38aa73e47a402eeb6:/")
}
```

- [ ] **Step 2: Eseguire il test rosso**

Run: `swift test --filter MountPathPolicyTests && swift test --filter ConnectionTests`

Expected: FAIL per API mancanti o remote name ancora basato sul nome visibile.

- [ ] **Step 3: Implementare policy e remote name**

```swift
public enum MountPathPolicy {
    private static let forbiddenRoots = ["/", "/System", "/Library", "/Applications", "/usr", "/bin", "/sbin", "/private"]

    public static func validationError(for path: String) -> String? {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        let forbidden = forbiddenRoots.contains { normalized == $0 || ($0 != "/" && normalized.hasPrefix($0 + "/")) }
        return forbidden ? "Scegli una cartella locale sicura dentro il tuo profilo utente." : nil
    }
}

public var rcloneRemoteName: String {
    "montamac_" + id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
}
```

`validationError` deve chiamare la policy dopo il controllo del percorso assoluto; `remoteSpec` e la sezione generata da `RcloneConfigurationWriter` devono usare `rcloneRemoteName`.

- [ ] **Step 4: Verificare il verde**

Run: `swift test --filter MountPathPolicyTests && swift test --filter ConnectionTests && swift test --filter RcloneConfigurationWriterTests`

Expected: tutti i test selezionati superati.

### Task 3: Lifecycle dei mount, cache e log redatti

**Files:**
- Create: `Sources/MontaMacCore/RcloneServicing.swift`
- Create: `Sources/MontaMacCore/SensitiveLogRedactor.swift`
- Create: `Tests/MontaMacCoreTests/MountCoordinatorSecurityTests.swift`
- Create: `Tests/MontaMacCoreTests/SensitiveLogRedactorTests.swift`
- Modify: `Sources/MontaMacCore/RcloneService.swift`
- Modify: `Sources/MontaMacCore/RcloneConfigurationWriter.swift`
- Modify: `Sources/MontaMacCore/MountMonitor.swift`
- Modify: `Sources/MontaMacCore/MountCoordinator.swift`
- Modify: `Sources/MontaMac/AppViewModel.swift`
- Modify: `Tests/MontaMacCoreTests/RcloneServiceTests.swift`

**Interfaces:**
- Produces: `RcloneServicing`, `MountMonitoring`, `MountCoordinator.reconcile(_:)`, `SensitiveLogRedactor.redact(_:connection:)`.
- Consumes: monitor macOS, rclone, credenziali e directory configurazione/cache iniettabili.

- [ ] **Step 1: Scrivere test rossi per mount esistente e cleanup**

```swift
@MainActor
func testExistingMountDoesNotStartSecondRcloneProcess() async {
    let rclone = FakeRcloneService()
    let coordinator = MountCoordinator(credentials: EmptyCredentials(), rclone: rclone, monitor: FakeMountMonitor(isMounted: true))
    let connection = makeConnection()

    await coordinator.mount(connection)

    XCTAssertEqual(rclone.startCount, 0)
    XCTAssertEqual(coordinator.status(for: connection), .mounted)
}

@MainActor
func testStartFailureRemovesTemporaryConfiguration() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let rclone = FakeRcloneService(startError: TestError.startFailed)
    let coordinator = MountCoordinator(credentials: PasswordCredentials(), rclone: rclone, monitor: FakeMountMonitor(isMounted: false), configurationDirectory: directory)
    let connection = makeConnection()

    await coordinator.mount(connection)

    XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(connection.id.uuidString).conf").path))
}

private enum TestError: Error { case startFailed }

private final class EmptyCredentials: CredentialStoring {
    func password(for id: UUID) throws -> String? { nil }
    func save(password: String, for id: UUID) throws {}
    func deletePassword(for id: UUID) throws {}
}

private final class PasswordCredentials: CredentialStoring {
    func password(for id: UUID) throws -> String? { "password" }
    func save(password: String, for id: UUID) throws {}
    func deletePassword(for id: UUID) throws {}
}

private final class FakeRcloneService: RcloneServicing {
    var startCount = 0
    let startError: Error?
    var isAvailable: Bool { true }
    init(startError: Error? = nil) { self.startError = startError }
    func mountArguments(for connection: RemoteConnection, configURL: URL, cacheDirectory: URL) -> [String] { [] }
    func startMount(arguments: [String], output: @escaping @Sendable (String) -> Void) throws -> Process {
        startCount += 1
        if let startError { throw startError }
        return Process()
    }
    func obscure(_ password: String) throws -> String { "obscured" }
    func unmount(at url: URL) throws {}
}

@MainActor
private final class FakeMountMonitor: MountMonitoring {
    let mounted: Bool
    init(isMounted: Bool) { mounted = isMounted }
    func isMounted(at url: URL) -> Bool { mounted }
    func waitUntilMounted(at url: URL, timeout: TimeInterval) async -> Bool { mounted }
}

private func makeConnection() -> RemoteConnection {
    RemoteConnection(name: "Test", protocolType: .ftp, host: "example.test", port: 21, username: "user", remotePath: "/", mountPath: "/Users/test/MontaMac/Test")
}
```

- [ ] **Step 2: Scrivere test rosso per redazione**

```swift
func testRedactorRemovesConnectionMetadata() {
    let connection = RemoteConnection(name: "Test", protocolType: .ftp, host: "secret.example", port: 21, username: "private-user", remotePath: "/", mountPath: "/Users/test/Secret Mount")
    let input = "failed private-user@secret.example in /Users/test/Secret Mount"
    let output = SensitiveLogRedactor.redact(input, connection: connection)
    XCTAssertFalse(output.contains("secret.example"))
    XCTAssertFalse(output.contains("private-user"))
    XCTAssertFalse(output.contains("/Users/test/Secret Mount"))
}
```

- [ ] **Step 3: Eseguire i test rossi**

Run: `swift test --filter MountCoordinatorSecurityTests && swift test --filter SensitiveLogRedactorTests`

Expected: FAIL per protocolli e API mancanti.

- [ ] **Step 4: Introdurre protocolli e logica minima**

```swift
public protocol RcloneServicing: AnyObject {
    var isAvailable: Bool { get }
    func mountArguments(for connection: RemoteConnection, configURL: URL, cacheDirectory: URL) -> [String]
    func startMount(arguments: [String], output: @escaping @Sendable (String) -> Void) throws -> Process
    func obscure(_ password: String) throws -> String
    func unmount(at url: URL) throws
}

@MainActor
public protocol MountMonitoring: AnyObject {
    func isMounted(at url: URL) -> Bool
    func waitUntilMounted(at url: URL, timeout: TimeInterval) async -> Bool
}
```

La redazione usa valori non vuoti ordinati dal più lungo al più corto:

```swift
public enum SensitiveLogRedactor {
    public static func redact(_ text: String, connection: RemoteConnection) -> String {
        [connection.mountPath, connection.username, connection.host]
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
            .reduce(text) { $0.replacingOccurrences(of: $1, with: "<redacted>") }
    }
}
```

`RcloneService` e `MountMonitor` devono conformare. `mountArguments` aggiunge:

```swift
["--cache-dir", cacheDirectory.path, "--vfs-cache-max-age", "1h", "--umask", "077"]
```

`MountCoordinator.mount` controlla `monitor.isMounted` prima della password, protegge la cache con `0700`, raccoglie output redatto e rimuove la configurazione in ogni ramo di fallimento. `reconcile` marca i mount esistenti e rimuove solo le configurazioni dei profili non montati.

- [ ] **Step 5: Collegare la riconciliazione all'avvio**

In `AppViewModel.init`, dopo il caricamento:

```swift
coordinator.reconcile(connections)
```

- [ ] **Step 6: Verificare il verde**

Run: `swift test --filter MountCoordinatorSecurityTests && swift test --filter SensitiveLogRedactorTests && swift test --filter RcloneServiceTests`

Expected: test selezionati superati.

### Task 4: Cancellazione sicura dei profili

**Files:**
- Create: `Sources/MontaMacCore/ProfileSecurityCleaner.swift`
- Create: `Tests/MontaMacCoreTests/ProfileSecurityCleanerTests.swift`
- Modify: `Sources/MontaMacCore/CredentialStore.swift`
- Modify: `Sources/MontaMacCore/AppCommandAvailability.swift`
- Modify: `Tests/MontaMacCoreTests/AppCommandAvailabilityTests.swift`
- Modify: `Sources/MontaMac/AppViewModel.swift`
- Modify: `Sources/MontaMac/MainWindowView.swift`

**Interfaces:**
- Produces: `ProfileSecurityCleaner.deleteArtifacts(for:)`.
- Consumes: `CredentialStoring`, UUID profilo e directory rclone.

- [ ] **Step 1: Scrivere test rossi**

```swift
func testCleanerDeletesCredentialAndConfiguration() throws {
    let credentials = RecordingCredentials()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let id = UUID()
    let config = directory.appendingPathComponent("\(id.uuidString).conf")
    defer { try? FileManager.default.removeItem(at: directory) }
    try SecureFileStore.write(Data("secret".utf8), to: config)

    try ProfileSecurityCleaner(credentials: credentials, configurationDirectory: directory).deleteArtifacts(for: id)

    XCTAssertEqual(credentials.deletedIDs, [id])
    XCTAssertFalse(FileManager.default.fileExists(atPath: config.path))
}

func testMountedProfileCannotBeDeleted() {
    XCTAssertFalse(AppCommandAvailability(hasSelection: true, status: .mounted).canDelete)
}

func testCredentialFailureLeavesConfigurationUntouched() throws {
    let credentials = RecordingCredentials(deleteError: TestCredentialError.denied)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let id = UUID()
    let config = directory.appendingPathComponent("\(id.uuidString).conf")
    defer { try? FileManager.default.removeItem(at: directory) }
    try SecureFileStore.write(Data("secret".utf8), to: config)

    XCTAssertThrowsError(try ProfileSecurityCleaner(credentials: credentials, configurationDirectory: directory).deleteArtifacts(for: id))
    XCTAssertTrue(FileManager.default.fileExists(atPath: config.path))
}

private enum TestCredentialError: Error { case denied }

private final class RecordingCredentials: CredentialStoring {
    var deletedIDs: [UUID] = []
    let deleteError: Error?
    init(deleteError: Error? = nil) { self.deleteError = deleteError }
    func password(for id: UUID) throws -> String? { nil }
    func save(password: String, for id: UUID) throws {}
    func deletePassword(for id: UUID) throws {
        if let deleteError { throw deleteError }
        deletedIDs.append(id)
    }
}
```

- [ ] **Step 2: Eseguire i test rossi**

Run: `swift test --filter ProfileSecurityCleanerTests && swift test --filter AppCommandAvailabilityTests`

Expected: FAIL perché cleaner manca e `canDelete` è ancora true per `.mounted`.

- [ ] **Step 3: Implementare cleaner e regole UI**

```swift
public final class ProfileSecurityCleaner {
    private let credentials: CredentialStoring
    private let configurationDirectory: URL

    public init(credentials: CredentialStoring, configurationDirectory: URL) {
        self.credentials = credentials
        self.configurationDirectory = configurationDirectory
    }

    public func deleteArtifacts(for id: UUID) throws {
        try credentials.deletePassword(for: id)
        let config = configurationDirectory.appendingPathComponent("\(id.uuidString).conf")
        if FileManager.default.fileExists(atPath: config.path) {
            try FileManager.default.removeItem(at: config)
        }
    }
}
```

`CredentialStore.save` aggiunge `kSecAttrAccessibleWhenUnlocked`. `AppCommandAvailability` imposta `canDelete = false` per `.mounted`; `AppViewModel.removeSelected` usa il cleaner e non rimuove il profilo in caso di errore. Il pulsante toolbar usa `viewModel.commandAvailability.canDelete`.

- [ ] **Step 4: Verificare il verde**

Run: `swift test --filter ProfileSecurityCleanerTests && swift test --filter AppCommandAvailabilityTests`

Expected: test selezionati superati.

### Task 5: Installer e script requisiti rafforzati

**Files:**
- Modify: `Sources/MontaMacCore/RequirementChecker.swift`
- Modify: `Sources/MontaMac/RequirementsView.swift`
- Modify: `Tests/MontaMacCoreTests/RequirementCheckerTests.swift`

**Interfaces:**
- Produces: comandi download HTTPS/TLS e script autoeliminante.
- Consumes: stati requisiti esistenti.

- [ ] **Step 1: Scrivere test rossi**

```swift
func testRcloneInstallerRequiresHTTPSAndTLS12() {
    let statuses = RequirementChecker(executables: ["brew", "fuse-t"]).check()
    let command = RequirementChecker.installationCommand(for: statuses)!
    XCTAssertTrue(command.contains("--proto '=https'"))
    XCTAssertTrue(command.contains("--tlsv1.2"))
    XCTAssertTrue(command.contains("--fail"))
}

func testInstallationScriptDeletesItself() throws {
    let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".command")
    try RequirementInstallScript.make(command: "true").write(to: scriptURL, atomically: true, encoding: .utf8)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = [scriptURL.path]
    try process.run(); process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0)
    XCTAssertFalse(FileManager.default.fileExists(atPath: scriptURL.path))
}
```

- [ ] **Step 2: Eseguire il test rosso**

Run: `swift test --filter RequirementCheckerTests`

Expected: FAIL per flags mancanti e script persistente.

- [ ] **Step 3: Implementare comandi e script**

Usare `/usr/bin/curl --fail --silent --show-error --location --proto '=https' --tlsv1.2` per i due domini ufficiali. Lo script inizia con:

```zsh
#!/bin/zsh
set -euo pipefail
umask 077
trap '/bin/rm -f -- "$0"' EXIT
```

`RequirementsView` protegge la directory Application Support con `SecureFileStore.secureDirectory` prima di scrivere lo script.

- [ ] **Step 4: Verificare il verde**

Run: `swift test --filter RequirementCheckerTests`

Expected: tutti i test requisiti superati.

### Task 6: Avviso FTP, traduzioni e release 2.1.0

**Files:**
- Modify: `Sources/MontaMac/ConnectionEditorView.swift`
- Modify: `Sources/MontaMac/Resources/it.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/fr.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/es.lproj/Localizable.strings`
- Modify: `Tests/MontaMacCoreTests/LocalizationCompletenessTests.swift`
- Modify: `Resources/Info.plist`
- Modify: `Scripts/build-app.sh`
- Modify: `Scripts/build-pkg.sh`

**Interfaces:**
- Produces: warning FTP non modale, Hardened Runtime e artefatti 2.1.0.
- Consumes: protocollo selezionato, localizzazioni e identità di firma opzionali.

- [ ] **Step 1: Aggiungere la chiave richiesta al test localizzazioni**

```swift
"FTP non cifra credenziali e dati. Usa SFTP o WebDAV quando possibile.",
"Scegli una cartella locale sicura dentro il tuo profilo utente."
```

- [ ] **Step 2: Eseguire il test rosso**

Run: `swift test --filter LocalizationCompletenessTests`

Expected: FAIL in tutte le lingue per chiave mancante.

- [ ] **Step 3: Implementare warning e traduzioni**

Nel form:

```swift
if connection.protocolType == .ftp {
    Label("FTP non cifra credenziali e dati. Usa SFTP o WebDAV quando possibile.", systemImage: "exclamationmark.shield")
        .font(.caption)
        .foregroundStyle(.orange)
}
```

Tradurre la chiave in tutte le quattro `.lproj`.

- [ ] **Step 4: Aggiornare build e versione**

Impostare `CFBundleShortVersionString=2.1.0`, incrementare `CFBundleVersion` a `3` e generare `MontaMac-2.1.0.pkg`. In `build-app.sh` usare:

```zsh
SIGN_IDENTITY="${MONTAMAC_SIGN_IDENTITY:--}"
CODESIGN_ARGS=(--force --deep --options runtime --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then CODESIGN_ARGS+=(--timestamp); fi
codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"
```

In `build-pkg.sh`, se `MONTAMAC_INSTALLER_IDENTITY` è valorizzata, aggiungere `--sign "$MONTAMAC_INSTALLER_IDENTITY"` a `pkgbuild`.

- [ ] **Step 5: Verificare il verde**

Run: `swift test --filter LocalizationCompletenessTests`

Expected: test localizzazioni superato.

### Task 7: Verifica finale e avvio

**Files:**
- Generate: `MontaMac.app`
- Generate: `dist/MontaMac-2.1.0.pkg`

- [ ] **Step 1: Eseguire la suite completa**

Run: `swift test`

Expected: 0 failure.

- [ ] **Step 2: Costruire app e installer**

Run: `zsh Scripts/build-pkg.sh`

Expected: app e package 2.1.0 creati.

- [ ] **Step 3: Verificare sicurezza degli artefatti**

```zsh
codesign --verify --deep --strict MontaMac.app
codesign -dvvv MontaMac.app 2>&1 | rg 'runtime'
test "$(plutil -extract CFBundleShortVersionString raw MontaMac.app/Contents/Info.plist)" = "2.1.0"
for language in it en fr es; do test -s "MontaMac.app/Contents/Resources/$language.lproj/Localizable.strings"; done
```

Espandere il package con `pkgutil --expand` e verificare `version="2.1.0"`, `preinstall`, `postinstall`, icona e logo.

- [ ] **Step 4: Verificare i permessi migrati**

Avviare una volta la nuova app, poi controllare che Application Support sia `0700` e i due JSON `0600`.

- [ ] **Step 5: Avviare la release**

Run: `open -n MontaMac.app`

Expected: MontaMac 2.1.0 avviata senza interrompere mount esistenti.
