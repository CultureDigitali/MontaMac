# MontaMac Menus and Language Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** aggiungere menu macOS completi, Impostazioni e cambio immediato tra italiano, inglese, francese e spagnolo.

**Architecture:** `AppSettings` conserva la lingua e fornisce il locale condiviso. I menu ricevono le azioni della finestra tramite `FocusedValues`; la disponibilità dei comandi è calcolata nel core. Le risorse localizzate vengono incluse realmente nel bundle `.app`, non lasciate soltanto nella directory SwiftPM.

**Tech Stack:** Swift 6, SwiftUI, Foundation, Combine, XCTest, macOS 15+.

## Global Constraints

- Lingue supportate: `it`, `en`, `fr`, `es`; fallback italiano.
- Cambio lingua senza riavvio e preferenza persistente.
- I comandi dipendenti da un profilo sono disabilitati senza selezione.
- Monta/Smonta continua a usare il controllo requisiti esistente.
- Eliminazione profilo sempre preceduta da conferma.
- Firma ad-hoc e pacchetto `.pkg` rigenerati al termine.

---

### Task 1: Preferenza lingua persistente

**Files:**
- Create: `Sources/MontaMacCore/AppSettings.swift`
- Create: `Tests/MontaMacCoreTests/AppSettingsTests.swift`

**Interfaces:**
- Produces: `AppLanguage: String, CaseIterable, Identifiable, Sendable` con casi `it`, `en`, `fr`, `es`.
- Produces: `@MainActor AppSettings: ObservableObject`, `language`, `locale`, `setLanguage(_:)`.
- Consumes: `UserDefaults` e chiave `MontaMac.selectedLanguage`.

- [ ] **Step 1: Scrivere i test che falliscono**

```swift
@MainActor
func testUnknownLanguageFallsBackToItalian() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    defaults.set("de", forKey: AppSettings.languageKey)
    XCTAssertEqual(AppSettings(defaults: defaults).language, .italian)
}

@MainActor
func testSelectedLanguagePersists() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let settings = AppSettings(defaults: defaults)
    settings.setLanguage(.french)
    XCTAssertEqual(AppSettings(defaults: defaults).language, .french)
}
```

- [ ] **Step 2: Verificare il fallimento**

Run: `swift test --filter AppSettingsTests`

Expected: FAIL perché `AppSettings` e `AppLanguage` non esistono.

- [ ] **Step 3: Implementare il modello**

Usare `@Published public private(set) var language`, salvare il raw value in `UserDefaults`, produrre `Locale(identifier: language.rawValue)` e nomi nativi `Italiano`, `English`, `Français`, `Español`.

- [ ] **Step 4: Verificare i test**

Run: `swift test --filter AppSettingsTests`

Expected: PASS.

### Task 2: Stato dei comandi

**Files:**
- Create: `Sources/MontaMacCore/AppCommandAvailability.swift`
- Create: `Tests/MontaMacCoreTests/AppCommandAvailabilityTests.swift`

**Interfaces:**
- Produces: `AppCommandAvailability(hasSelection:status:)` con `canEdit`, `canDelete`, `canMount`, `canUnmount`, `canOpenFinder`, `canRefreshStatistics`.
- Consumes: `MountStatus`.

- [ ] **Step 1: Scrivere il test che fallisce**

```swift
func testNoSelectionDisablesDriveCommands() {
    let state = AppCommandAvailability(hasSelection: false, status: .disconnected)
    XCTAssertFalse(state.canEdit)
    XCTAssertFalse(state.canMount)
    XCTAssertFalse(state.canUnmount)
}

func testMountedSelectionEnablesUnmountAndFinder() {
    let state = AppCommandAvailability(hasSelection: true, status: .mounted)
    XCTAssertFalse(state.canMount)
    XCTAssertTrue(state.canUnmount)
    XCTAssertTrue(state.canOpenFinder)
}
```

- [ ] **Step 2: Verificare il fallimento**

Run: `swift test --filter AppCommandAvailabilityTests`

Expected: FAIL perché il tipo non esiste.

- [ ] **Step 3: Implementare la matrice degli stati**

Montaggio permesso solo da `disconnected` o `failed`; smontaggio e Finder solo da `mounted`; modifica, eliminazione e statistiche richiedono una selezione non in transizione.

- [ ] **Step 4: Verificare i test**

Run: `swift test --filter AppCommandAvailabilityTests`

Expected: PASS.

### Task 3: Menu nativi e azioni focalizzate

**Files:**
- Create: `Sources/MontaMac/MenuActions.swift`
- Create: `Sources/MontaMac/MontaMacCommands.swift`
- Modify: `Sources/MontaMac/MainWindowView.swift:4-46`
- Modify: `Sources/MontaMac/AppViewModel.swift:27-82`

**Interfaces:**
- Produces: `MenuActions` con closure per nuovo/modifica/elimina, monta/smonta, Finder, statistiche, dashboard, filtri, requisiti, guida e onboarding.
- Produces: `FocusedValues.menuActions`.
- Consumes: `AppCommandAvailability` da Task 2 e `AppSettings` da Task 1.

- [ ] **Step 1: Creare MenuActions e FocusedValueKey**

Definire closure `() -> Void`, stato `availability` e proprietà `hasSelectedProfile`. Nessuna azione crea un secondo `AppViewModel`.

- [ ] **Step 2: Aggiungere i menu**

Implementare:

```text
File: Nuovo profilo ⌘N, Modifica profilo ⌘E, Elimina profilo ⌫
Drive: Monta ⌘M, Smonta ⇧⌘M, Apri nel Finder ⌘O, Aggiorna statistiche ⌘R, Requisiti di sistema
Visualizza: Dashboard ⌘1, Profili ⌘2, Preferiti ⌘3, Montati ⌘4
Lingua: Italiano, English, Français, Español
Aiuto: Guida MontaMac, Mostra introduzione, Diagnostica
```

- [ ] **Step 3: Collegare la finestra**

Esporre `.focusedSceneValue(\.menuActions, actions)`. Mostrare `confirmationDialog` prima di `removeSelected`; menu e toolbar richiamano la stessa richiesta di eliminazione.

- [ ] **Step 4: Verificare la compilazione**

Run: `swift test`

Expected: suite completa PASS e target `MontaMac` compilato.

### Task 4: Scena Impostazioni e cambio lingua immediato

**Files:**
- Create: `Sources/MontaMac/SettingsView.swift`
- Modify: `Sources/MontaMac/MontaMacApp.swift:1-6`

**Interfaces:**
- Consumes: `AppSettings` da Task 1 e `MontaMacCommands` da Task 3.
- Produces: `Settings` scene e locale condiviso con finestra e menu.

- [ ] **Step 1: Costruire SettingsView**

Mostrare picker lingua, versione `2.0` e stato di Homebrew/rclone/FUSE-T; la finestra Impostazioni non crea né controlla un secondo `AppViewModel`.

- [ ] **Step 2: Aggiornare MontaMacApp**

Creare un solo `@StateObject AppSettings`, applicare `.environmentObject(settings)` e `.environment(\.locale, settings.locale)` a `WindowGroup` e `Settings`; registrare `.commands { MontaMacCommands(settings: settings) }`.

- [ ] **Step 3: Verificare il cambio lingua**

Run: `swift test --filter AppSettingsTests && swift build -c release`

Expected: PASS e build release senza warning.

### Task 5: Localizzazione completa delle schermate

**Files:**
- Modify: tutti i file `Sources/MontaMac/*.swift` che mostrano testo.
- Modify: `Sources/MontaMac/Resources/it.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/fr.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/es.lproj/Localizable.strings`
- Create: `Tests/MontaMacCoreTests/LocalizationCompletenessTests.swift`

**Interfaces:**
- Produces: traduzioni per dashboard, profili, editor, dettagli, statistiche, requisiti, guida, onboarding, menu, impostazioni, diagnostica, log, stati e messaggi di errore.

- [ ] **Step 1: Scrivere il test di completezza che fallisce**

Il test legge i quattro `Localizable.strings` e verifica che ciascuno contenga le chiavi obbligatorie:

```swift
let required = [
  "Nuovo profilo", "Modifica profilo", "Elimina profilo", "Monta", "Smonta",
  "Apri nel Finder", "Aggiorna statistiche", "Requisiti di sistema", "Dashboard",
  "Profili", "Preferiti", "Montati", "Guida MontaMac", "Mostra introduzione",
  "Diagnostica", "Impostazioni", "Lingua", "Configurazione drive",
  "Tutto pronto per montare i drive.", "Nessuna attività registrata."
]
```

- [ ] **Step 2: Verificare il fallimento**

Run: `swift test --filter LocalizationCompletenessTests`

Expected: FAIL elencando le chiavi mancanti.

- [ ] **Step 3: Completare le quattro traduzioni**

Run: `rg -n 'Text\(|Button\(|Label\(|Section\(|GroupBox\(|ContentUnavailableView\(|LabeledContent\(|TextField\(|SecureField\(|Toggle\(|Picker\(|Menu\(' Sources/MontaMac Sources/MontaMacCore`

Aggiungere ogni chiave trovata ai quattro cataloghi. Per stringhe dinamiche usare `LocalizedStringKey`, inclusi `status.message`, errori di validazione, argomenti dell’onboarding, argomenti della guida, eventi attività, diagnostica e titoli dei filtri.

- [ ] **Step 4: Verificare la completezza**

Run: `swift test --filter LocalizationCompletenessTests`

Expected: PASS per `it`, `en`, `fr`, `es`.

### Task 6: Inserire realmente le risorse nell’app e verificare

**Files:**
- Modify: `Scripts/build-app.sh:1-13`
- Modify: `README.md`

**Interfaces:**
- Consumes: `.build/.../MontaMac_MontaMac.bundle` prodotto da SwiftPM.
- Produces: `.lproj` in `MontaMac.app/Contents/Resources` e `MontaMac_MontaMac.bundle` dentro `MontaMac.app`.

- [ ] **Step 1: Creare una verifica di packaging che fallisce**

Run: `zsh Scripts/build-app.sh && test -f MontaMac.app/Contents/Resources/fr.lproj/Localizable.strings`

Expected: FAIL perché lo script attuale copia solo binario, `Info.plist` e icona.

- [ ] **Step 2: Correggere build-app.sh**

Copiare il resource bundle accanto al bundle principale per `Bundle.module` e copiare `it.lproj`, `en.lproj`, `fr.lproj`, `es.lproj` in `Contents/Resources` per la localizzazione di `Bundle.main`; firmare solo dopo tutte le copie.

- [ ] **Step 3: Verifica finale**

Run: `swift test && swift build -c release && zsh Scripts/build-pkg.sh && test -f MontaMac.app/Contents/Resources/es.lproj/Localizable.strings && codesign --verify --deep --strict --verbose=2 MontaMac.app`

Expected: test senza fallimenti, risorse presenti, app valida e `.pkg` aggiornato.

- [ ] **Step 4: Prova manuale**

Run: `open -n MontaMac.app`

Expected: menu visibili, Impostazioni apribile e testi aggiornati passando tra le quattro lingue senza riavviare.
