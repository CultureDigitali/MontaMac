# MontaMac Profile Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** aggiungere profili di drive con cartelle, preferiti, ricerca e montaggio rapido.

**Architecture:** `RemoteConnection` resta il profilo persistente e riceve metadati retrocompatibili. `ProfileFilter` mantiene la logica di filtro e ordinamento nel core; SwiftUI usa `ProfileManagerView` per visualizzare e azionare i risultati tramite `AppViewModel`.

**Tech Stack:** Swift 6, SwiftUI, Foundation, XCTest, macOS 15+.

## Global Constraints

- Conservare i file `connections.json` già creati senza migrazioni manuali.
- Non duplicare né leggere le password fuori dal Portachiavi macOS.
- Non montare automaticamente un drive; l’utente avvia ogni montaggio.
- Localizzare tutte le nuove stringhe in italiano, inglese, francese e spagnolo.
- Rigenerare l’app con firma ad-hoc e il `.pkg` dopo ogni verifica finale.

---

### Task 1: Metadati profilo retrocompatibili

**Files:**
- Modify: `Sources/MontaMacCore/Connection.swift:12-49`
- Create: `Tests/MontaMacCoreTests/ConnectionStoreCompatibilityTests.swift`

**Interfaces:**
- Produces: `RemoteConnection.profileGroup: String`, `isFavorite: Bool`, `lastUsedAt: Date?`.
- Produces: decoder con valori di default `Senza cartella`, `false`, `nil` per JSON preesistente.

- [ ] **Step 1: Scrivere il test che fallisce**

```swift
func testLegacyConnectionDecodesProfileDefaults() throws {
    let json = #"[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"Archivio\",\"protocolType\":\"sftp\",\"host\":\"host.example\",\"port\":22,\"username\":\"anna\",\"remotePath\":\"/\",\"mountPath\":\"/Users/anna/MontaMac/archivio\"}]"#.data(using: .utf8)!
    let decoded = try JSONDecoder().decode([RemoteConnection].self, from: json)
    XCTAssertEqual(decoded[0].profileGroup, "Senza cartella")
    XCTAssertFalse(decoded[0].isFavorite)
    XCTAssertNil(decoded[0].lastUsedAt)
}

func testMarkUsedStoresProvidedDate() {
    var profile = RemoteConnection.blank(protocolType: .ftp)
    let date = Date(timeIntervalSinceReferenceDate: 10)
    profile.markUsed(at: date)
    XCTAssertEqual(profile.lastUsedAt, date)
}
```

- [ ] **Step 2: Verificare il fallimento**

Run: `swift test --filter ConnectionStoreCompatibilityTests`

Expected: FAIL perché le proprietà o il decoder non esistono.

- [ ] **Step 3: Implementare modello e decoder**

```swift
public var profileGroup: String
public var isFavorite: Bool
public var lastUsedAt: Date?

enum CodingKeys: String, CodingKey { case id, name, protocolType, host, port, username, remotePath, mountPath, profileGroup, isFavorite, lastUsedAt }
```

Decodificare i tre nuovi campi con `decodeIfPresent`, normalizzare una cartella vuota a `Senza cartella`, aggiornare `init` e `blank`; aggiungere `mutating func markUsed(at: Date = .now)`.

- [ ] **Step 4: Verificare il test**

Run: `swift test --filter ConnectionStoreCompatibilityTests`

Expected: PASS.

### Task 2: Filtro e ordinamento dei profili

**Files:**
- Create: `Sources/MontaMacCore/ProfileFilter.swift`
- Create: `Tests/MontaMacCoreTests/ProfileFilterTests.swift`

**Interfaces:**
- Produces: `public enum ProfileScope { case all, favorites, mounted, group(String) }`.
- Produces: `ProfileFilter.profiles(_:scope:query:statusFor:) -> [RemoteConnection]`.
- Consumes: `MountStatus` e i metadati da Task 1.

- [ ] **Step 1: Scrivere i test che falliscono**

```swift
func testFavoritesSearchAndRecentOrdering() {
    let result = ProfileFilter.profiles(profiles, scope: .favorites, query: "server", statusFor: { _ in .disconnected })
    XCTAssertEqual(result.map(\.name), ["Server recente", "Server precedente"])
}

func testMountedScopeKeepsOnlyMountedProfiles() {
    let result = ProfileFilter.profiles(profiles, scope: .mounted, query: "", statusFor: { $0.name == "Online" ? .mounted : .disconnected })
    XCTAssertEqual(result.map(\.name), ["Online"])
}
```

- [ ] **Step 2: Verificare il fallimento**

Run: `swift test --filter ProfileFilterTests`

Expected: FAIL perché `ProfileFilter` non esiste.

- [ ] **Step 3: Implementare il filtro**

```swift
public static func profiles(
    _ profiles: [RemoteConnection], scope: ProfileScope, query: String,
    statusFor: (RemoteConnection) -> MountStatus
) -> [RemoteConnection]
```

Confrontare query normalizzata con `name`, `host`, `protocolType.title` e `profileGroup`; ordinare preferiti prima, poi `lastUsedAt` decrescente, infine nome localizzato.

- [ ] **Step 4: Verificare i test**

Run: `swift test --filter ProfileFilterTests`

Expected: PASS.

### Task 3: Azioni del view model

**Files:**
- Modify: `Sources/MontaMac/AppViewModel.swift:7-73`
- Modify: `Tests/MontaMacCoreTests/ProfileFilterTests.swift`

**Interfaces:**
- Consumes: `ProfileFilter.profiles(_:scope:query:statusFor:)`.
- Produces: `profileScope`, `profileQuery`, `visibleProfiles`, `profileGroups`, `toggleFavorite(_:)`, `selectAndToggleMount(_:)`.

- [ ] **Step 1: Scrivere il test che fallisce**

```swift
func testGroupsExcludeDefaultGroupAndAreSorted() {
    XCTAssertEqual(ProfileFilter.groups(in: profiles), ["Clienti", "Personale"])
}
```

- [ ] **Step 2: Verificare il fallimento**

Run: `swift test --filter ProfileFilterTests/testGroupsExcludeDefaultGroupAndAreSorted`

Expected: FAIL perché `groups(in:)` non esiste.

- [ ] **Step 3: Implementare azioni e persistenza**

Aggiornare `recordMounted` per invocare `connections[index].markUsed()`, quindi salvare `connections`; alternare `isFavorite` e salvare. `selectAndToggleMount` seleziona il profilo, smonta se `mounted`, altrimenti chiama il montaggio esistente.

- [ ] **Step 4: Verificare i test**

Run: `swift test --filter ProfileFilterTests`

Expected: PASS.

### Task 4: Gestore Profili e editor

**Files:**
- Create: `Sources/MontaMac/ProfileManagerView.swift`
- Modify: `Sources/MontaMac/MainWindowView.swift:12-65`
- Modify: `Sources/MontaMac/ConnectionEditorView.swift:11-22`
- Modify: `Sources/MontaMac/ConnectionRow.swift:4-13`

**Interfaces:**
- Consumes: `AppViewModel.visibleProfiles`, `profileGroups`, `profileScope`, `profileQuery` e azioni Task 3.
- Produces: sezione laterale Profili, filtri, cartelle, preferiti e pulsante Monta/Smonta.

- [ ] **Step 1: Implementare ProfileManagerView**

Creare ricerca, picker scope, pulsanti cartella, lista con stella e bottone `externaldrive.badge.plus`/`eject`. Impostare `.accessibilityLabel` per azioni e stato.

- [ ] **Step 2: Collegare la navigazione**

Sostituire l’elenco statico in `MainWindowView` con `ProfileManagerView`; il click seleziona il profilo e apre il dettaglio. Inserire nel dashboard scorciatoie per i preferiti tramite closure di montaggio.

- [ ] **Step 3: Aggiornare l’editor**

Inserire `TextField("Cartella profilo", text: $connection.profileGroup)` e `Toggle("Preferito", isOn: $connection.isFavorite)`; un valore vuoto viene normalizzato dal modello.

- [ ] **Step 4: Verifica manuale**

Run: `zsh Scripts/build-app.sh && open -n MontaMac.app`

Expected: creare profilo, assegnare cartella, renderlo preferito, filtrarlo, montarlo e smontarlo senza errori UI.

### Task 5: Localizzazione e rilascio verificato

**Files:**
- Modify: `Sources/MontaMac/Resources/it.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/fr.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/es.lproj/Localizable.strings`
- Modify: `README.md:1-20`

**Interfaces:**
- Produces: stringhe locali per profili, preferiti, cartelle, filtri e azioni rapide.

- [ ] **Step 1: Aggiungere le traduzioni**

Tradurre `Profili`, `Preferiti`, `Montati`, `Tutti`, `Cartella profilo`, `Senza cartella`, `Cerca profili`, `Monta`, `Smonta`, `Ultimo utilizzo` nelle quattro lingue.

- [ ] **Step 2: Documentare**

Aggiungere nel README una riga: `Profili: organizza i drive salvati in cartelle, preferiti e scorciatoie di montaggio.`

- [ ] **Step 3: Verifica completa**

Run: `swift test && swift build -c release && zsh Scripts/build-pkg.sh && codesign --verify --deep --strict --verbose=2 MontaMac.app`

Expected: test senza fallimenti, bundle firmato ad-hoc e pacchetto creato.
