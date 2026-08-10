# MontaMac 2.0.1 Finder After Mount Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aprire automaticamente nel Finder il percorso locale esatto dopo un mount riuscito e distribuire MontaMac 2.0.1.

**Architecture:** Un nuovo `MountCompletionHandler` nel core decide ed esegue l'apertura tramite una closure iniettabile, senza dipendere da AppKit. `AppViewModel` lo usa esclusivamente dopo lo stato `.mounted`, registra l'esito nel log e mantiene separati il successo del mount e quello dell'apertura Finder.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSWorkspace`, XCTest, Swift Package Manager, `pkgbuild`, macOS 15+.

## Global Constraints

- Il mount resta riuscito solo dopo la conferma del `MountMonitor`.
- Finder non deve essere aperto quando il mount fallisce.
- Nessuna password o credenziale deve comparire nei log.
- Il comando manuale `Apri nel Finder` resta disponibile.
- La release finale è `2.0.1` e l'installer è `dist/MontaMac-2.0.1.pkg`.
- Il progetto non contiene un repository Git: i passi di commit non sono applicabili.

## Struttura dei file

- Creare `Sources/MontaMacCore/MountCompletionHandler.swift`: policy testabile e apertura della cartella.
- Creare `Tests/MontaMacCoreTests/MountCompletionHandlerTests.swift`: regressioni per successo, fallimento e percorso.
- Modificare `Sources/MontaMac/AppViewModel.swift`: integrazione dopo mount e log dell'esito.
- Modificare `Resources/Info.plist`, `Scripts/build-pkg.sh`, `Sources/MontaMac/SettingsView.swift`: versione 2.0.1 coerente.

---

### Task 1: Gestore testabile dell'apertura Finder

**Files:**
- Create: `Sources/MontaMacCore/MountCompletionHandler.swift`
- Test: `Tests/MontaMacCoreTests/MountCompletionHandlerTests.swift`

**Interfaces:**
- Consumes: `MountStatus`, `RemoteConnection`.
- Produces: `MountCompletionOutcome` e `MountCompletionHandler.handle(status:connection:)`.

- [ ] **Step 1: Scrivere i test fallenti**

```swift
import XCTest
@testable import MontaMacCore

final class MountCompletionHandlerTests: XCTestCase {
    @MainActor
    func testMountedConnectionOpensExactConfiguredPathOnce() {
        var openedURLs: [URL] = []
        let handler = MountCompletionHandler { url in
            openedURLs.append(url)
            return true
        }
        let connection = RemoteConnection(
            name: "Test", protocolType: .ftp, host: "example.test", port: 21,
            username: "user", remotePath: "/", mountPath: "/tmp/MontaMac Drive"
        )

        let outcome = handler.handle(status: .mounted, connection: connection)

        XCTAssertEqual(openedURLs, [URL(fileURLWithPath: "/tmp/MontaMac Drive")])
        XCTAssertEqual(outcome, .opened(URL(fileURLWithPath: "/tmp/MontaMac Drive")))
    }

    @MainActor
    func testFailedMountDoesNotOpenFinder() {
        var openCount = 0
        let handler = MountCompletionHandler { _ in openCount += 1; return true }
        let connection = RemoteConnection(
            name: "Test", protocolType: .ftp, host: "example.test", port: 21,
            username: "user", remotePath: "/", mountPath: "/tmp/MontaMac Drive"
        )

        let outcome = handler.handle(status: .failed("errore"), connection: connection)

        XCTAssertEqual(openCount, 0)
        XCTAssertEqual(outcome, .skipped)
    }

    @MainActor
    func testFinderFailureIsReportedSeparately() {
        let handler = MountCompletionHandler { _ in false }
        let connection = RemoteConnection(
            name: "Test", protocolType: .ftp, host: "example.test", port: 21,
            username: "user", remotePath: "/", mountPath: "/tmp/MontaMac Drive"
        )

        XCTAssertEqual(
            handler.handle(status: .mounted, connection: connection),
            .openFailed(URL(fileURLWithPath: "/tmp/MontaMac Drive"))
        )
    }
}
```

- [ ] **Step 2: Eseguire il test e verificare il rosso**

Run: `swift test --filter MountCompletionHandlerTests`

Expected: FAIL perché `MountCompletionHandler` e `MountCompletionOutcome` non esistono.

- [ ] **Step 3: Implementare il minimo necessario**

```swift
import Foundation

public enum MountCompletionOutcome: Equatable {
    case skipped
    case opened(URL)
    case openFailed(URL)
}

@MainActor
public struct MountCompletionHandler {
    private let openFolder: (URL) -> Bool

    public init(openFolder: @escaping (URL) -> Bool) {
        self.openFolder = openFolder
    }

    public func handle(status: MountStatus, connection: RemoteConnection) -> MountCompletionOutcome {
        guard case .mounted = status else { return .skipped }
        let url = URL(fileURLWithPath: connection.mountPath)
        return openFolder(url) ? .opened(url) : .openFailed(url)
    }
}
```

- [ ] **Step 4: Eseguire il test e verificare il verde**

Run: `swift test --filter MountCompletionHandlerTests`

Expected: 3 test superati, 0 errori.

### Task 2: Integrazione dopo il mount riuscito

**Files:**
- Modify: `Sources/MontaMac/AppViewModel.swift`

**Interfaces:**
- Consumes: `MountCompletionHandler`, `MountCompletionOutcome`.
- Produces: apertura automatica e log del percorso dopo `.mounted`.

- [ ] **Step 1: Aggiungere il gestore applicativo**

In `AppViewModel` aggiungere:

```swift
private let mountCompletionHandler = MountCompletionHandler { url in
    NSWorkspace.shared.open(url)
}
```

- [ ] **Step 2: Collegarlo al solo ramo di successo**

Sostituire il ramo successivo a `await coordinator.mount(connection)` con:

```swift
let status = coordinator.status(for: connection)
if case .mounted = status {
    recordMounted(connection)
    switch mountCompletionHandler.handle(status: status, connection: connection) {
    case let .opened(url):
        coordinator.append("Cartella aperta nel Finder: \(url.path)", for: connection)
    case let .openFailed(url):
        coordinator.append("Drive montato, ma Finder non ha aperto: \(url.path)", for: connection)
    case .skipped:
        break
    }
}
```

- [ ] **Step 3: Verificare compilazione e regressioni**

Run: `swift test`

Expected: tutti i test superati e nessun errore di compilazione Swift 6.

### Task 3: Metadati della release 2.0.1

**Files:**
- Modify: `Resources/Info.plist`
- Modify: `Scripts/build-pkg.sh`
- Modify: `Sources/MontaMac/SettingsView.swift`

**Interfaces:**
- Consumes: file di build e metadati esistenti.
- Produces: app `2.0.1` e installer `MontaMac-2.0.1.pkg`.

- [ ] **Step 1: Aggiornare app, installer e schermata Informazioni**

In `Resources/Info.plist` impostare:

```xml
<key>CFBundleShortVersionString</key><string>2.0.1</string>
<key>CFBundleVersion</key><string>2</string>
```

In `Scripts/build-pkg.sh` usare:

```zsh
--version "2.0.1" \
"$DIST_DIR/MontaMac-2.0.1.pkg"
```

In `SettingsView` mostrare la versione dal bundle:

```swift
LabeledContent(
    "Versione",
    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.1"
)
```

- [ ] **Step 2: Verificare i metadati sugli artefatti reali**

Dopo la build, leggere `CFBundleShortVersionString` dal bundle e `version` dal `PackageInfo` estratto con `pkgutil --expand`. Entrambi devono essere esattamente `2.0.1`.

### Task 4: Verifica e distribuzione

**Files:**
- Generate: `MontaMac.app`
- Generate: `dist/MontaMac-2.0.1.pkg`

**Interfaces:**
- Consumes: sorgenti e metadati 2.0.1.
- Produces: artefatti finali verificati e app avviata.

- [ ] **Step 1: Eseguire la suite completa**

Run: `swift test`

Expected: tutti i test superati, 0 failure.

- [ ] **Step 2: Costruire app e installer**

Run: `zsh Scripts/build-pkg.sh`

Expected: creazione di `MontaMac.app` e `dist/MontaMac-2.0.1.pkg`.

- [ ] **Step 3: Verificare firma e risorse**

Run:

```zsh
codesign --verify --deep --strict MontaMac.app
plutil -lint MontaMac.app/Contents/Info.plist
for language in it en fr es; do
    test -s "MontaMac.app/Contents/Resources/$language.lproj/Localizable.strings"
done
test -s MontaMac.app/Contents/Resources/AppIcon.icns
test -s MontaMac.app/Contents/Resources/MontaMac-logo.png
```

Expected: exit code 0 per ogni controllo.

- [ ] **Step 4: Verificare il comportamento reale**

Montare il profilo di test e confermare che Finder apra automaticamente esattamente `connection.mountPath`. Se non è opportuno rimontare il server reale, usare il test automatico del gestore come prova del comportamento e lasciare il test end-to-end all'utente.

- [ ] **Step 5: Avviare la build finale**

Run: `open -n MontaMac.app`

Expected: MontaMac 2.0.1 in esecuzione.
