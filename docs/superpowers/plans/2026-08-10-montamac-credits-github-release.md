# MontaMac Credits and GitHub Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aggiungere crediti aziendali multilingua, preparare un repository pubblico privo di dati sensibili e pubblicare la prima release GitHub `v2.1.0` con installer e checksum.

**Architecture:** Un piccolo modello `CreditsContent` contiene esclusivamente dati pubblici verificati; una nuova vista SwiftUI li presenta dalle Impostazioni. La pubblicazione Git separa sorgenti e documentazione dagli artefatti binari, archivia localmente le vecchie release in `OLD/` e applica una scansione anti-segreto prima del primo commit e del push.

**Tech Stack:** Swift 6, SwiftUI, XCTest, Swift Package Manager, Git, GitHub CLI, pkgbuild, codesign, SHA-256.

## Global Constraints

- Repository pubblico `CultureDigitali/MontaMac` con branch `main`.
- Licenza MIT, copyright 2026 Culture Digitali Srl.
- Release GitHub `v2.1.0`; bundle build `4`.
- Il pacchetto non notarizzato deve avere un avviso esplicito.
- Nessun dato utente, token, password, configurazione rclone, log, certificato o file locale può essere tracciato.
- `OLD/`, `.superpowers/`, `.build/`, `MontaMac.app/` e `dist/` restano locali e ignorati.
- Nessuna nuova dipendenza Swift.

---

### Task 1: Modello e interfaccia Crediti

**Files:**
- Create: `Sources/MontaMacCore/CreditsContent.swift`
- Create: `Sources/MontaMac/CreditsView.swift`
- Create: `Tests/MontaMacCoreTests/CreditsContentTests.swift`
- Modify: `Sources/MontaMac/SettingsView.swift`
- Modify: `Tests/MontaMacCoreTests/LocalizationCompletenessTests.swift`
- Modify: `Sources/MontaMac/Resources/{it,en,fr,es}.lproj/Localizable.strings`

**Interfaces:**
- Produces: `CreditsContent.creator`, `company`, `website`, `email`, `phone`, `address`, `vatNumber`.
- Consumes: logo bundle `MontaMac-logo.png` e localizzazioni esistenti.

- [ ] **Step 1: Scrivere i test rossi**

```swift
func testCreditsContainVerifiedPublicIdentity() {
    XCTAssertEqual(CreditsContent.creator, "Luigi Strazzullo")
    XCTAssertEqual(CreditsContent.company, "Culture Digitali Srl")
    XCTAssertEqual(CreditsContent.email, "info@culturedigitali.eu")
    XCTAssertEqual(CreditsContent.vatNumber, "IT09465861210")
}
```

Aggiungere al test localizzazioni le chiavi `Crediti`, `Creato da Luigi Strazzullo per Culture Digitali Srl`, `Fondatore e amministratore, imprenditore e consulente digitale`, `Sito web`, `Email`, `Telefono`, `Sede`, `Partita IVA`.

- [ ] **Step 2: Verificare il rosso**

Run: `swift test --filter 'CreditsContentTests|LocalizationCompletenessTests'`

Expected: FAIL per modello e chiavi mancanti.

- [ ] **Step 3: Implementare modello e UI**

```swift
public enum CreditsContent {
    public static let creator = "Luigi Strazzullo"
    public static let company = "Culture Digitali Srl"
    public static let website = URL(string: "https://culturedigitali.eu/")!
    public static let email = "info@culturedigitali.eu"
    public static let phone = "+39 081 180 88 248"
    public static let address = "Via Coroglio 57D, 80124 Napoli"
    public static let vatNumber = "IT09465861210"
}
```

`CreditsView` mostra logo, attribuzione, ruolo e link cliccabili. `SettingsView` aggiunge un pulsante `Crediti` e presenta la vista in sheet.

- [ ] **Step 4: Verificare il verde**

Run: `swift test --filter 'CreditsContentTests|LocalizationCompletenessTests'`

Expected: PASS.

### Task 2: Igiene e documentazione del repository

**Files:**
- Modify: `.gitignore`
- Modify: `README.md`
- Create: `LICENSE`
- Create: `SECURITY.md`
- Create: `CHANGELOG.md`
- Create: `docs/releases/v2.1.0.md`
- Modify: `Resources/Info.plist`
- Modify: `Tests/MontaMacCoreTests/ReleaseHardeningTests.swift`

**Interfaces:**
- Produces: insieme pubblico documentato, licenza MIT e release notes.
- Consumes: versione applicativa `2.1.0` e build `4`.

- [ ] **Step 1: Scrivere i test rossi**

Aggiornare `ReleaseHardeningTests` affinché richieda `CFBundleVersion == "4"` e aggiungere un test che legga `.gitignore`, verificando le esclusioni `.superpowers/`, `OLD/`, `dist/`, `.env*`, `connections.json`, `activity.json`, `*.conf`, `*.p12`, `*.pem`.

- [ ] **Step 2: Verificare il rosso**

Run: `swift test --filter ReleaseHardeningTests`

Expected: FAIL per build e ignore mancanti.

- [ ] **Step 3: Implementare documentazione ed esclusioni**

Aggiornare `CFBundleVersion` a `4`; estendere `.gitignore`; creare licenza MIT, policy sicurezza, changelog e note bilingui. Il README documenta build, installazione, protocolli, crediti, sicurezza e limite di notarizzazione.

- [ ] **Step 4: Verificare il verde**

Run: `swift test --filter ReleaseHardeningTests`

Expected: PASS.

### Task 3: Archivio OLD e pacchetto aggiornato

**Files:**
- Create local archive: `OLD/releases/`
- Move locally: `dist/MontaMac-2.0.pkg`, `dist/MontaMac-2.0.1.pkg`
- Generate: `MontaMac.app`
- Generate: `dist/MontaMac-2.1.0.pkg`
- Generate: `dist/MontaMac-2.1.0.pkg.sha256`

**Interfaces:**
- Produces: installer `2.1.0` build `4` e checksum.
- Consumes: script `Scripts/build-pkg.sh` esistente.

- [ ] **Step 1: Risolvere con controlli read-only gli artefatti obsoleti**

Run: `find dist -maxdepth 1 -type f -print`

Expected: pacchetti `2.0`, `2.0.1`, `2.1.0`.

- [ ] **Step 2: Archiviare in modo recuperabile**

Creare `OLD/releases` e spostare solo `MontaMac-2.0.pkg` e `MontaMac-2.0.1.pkg`. Non spostare sorgenti o documentazione.

- [ ] **Step 3: Eseguire suite e build**

Run: `swift test && zsh Scripts/build-pkg.sh`

Expected: test verdi e nuovo `dist/MontaMac-2.1.0.pkg`.

- [ ] **Step 4: Generare e verificare checksum**

Run: `shasum -a 256 dist/MontaMac-2.1.0.pkg`

Scrivere la riga prodotta in `dist/MontaMac-2.1.0.pkg.sha256` e verificarla con `shasum -a 256 -c` dalla directory `dist`.

### Task 4: Inizializzazione Git e controllo anti-segreto

**Files:**
- Create: `.git/` local metadata
- Consume: tutti i file non ignorati del progetto

**Interfaces:**
- Produces: branch locale `main` con commit iniziale pulito.
- Consumes: `.gitignore`, documentazione, sorgenti e test verificati.

- [ ] **Step 1: Inizializzare Git**

Run: `git init -b main`

- [ ] **Step 2: Controllare l'insieme candidabile**

Run: `git status --short --ignored` e `git ls-files --others --exclude-standard`.

Verificare che `.superpowers`, `.build`, `MontaMac.app`, `dist` e `OLD` siano ignorati.

- [ ] **Step 3: Scansionare prima dello staging**

Cercare chiavi private, token, password, URL con credenziali, percorsi `/Users/<utente>`, host reali e file locali. Le sole occorrenze ammesse sono fixture sintetiche con domini `.example` e password letterali nei test.

- [ ] **Step 4: Stage e nuova scansione dell'esatto contenuto**

Run: `git add .`, poi `git diff --cached --name-only`, `git diff --cached --check` e scansione dei blob staged.

- [ ] **Step 5: Creare il commit iniziale**

Run: `git commit -m "feat: prepare MontaMac 2.1.0 public release"`

### Task 5: Repository GitHub e release pubblica

**Files:**
- External: `https://github.com/CultureDigitali/MontaMac`
- Upload: `dist/MontaMac-2.1.0.pkg`, `dist/MontaMac-2.1.0.pkg.sha256`

**Interfaces:**
- Produces: repository pubblico, tag `v2.1.0` e GitHub Release.
- Consumes: commit locale verificato e autenticazione GitHub dell'account `CultureDigitali`.

- [ ] **Step 1: Ripristinare autenticazione GitHub**

Run: `gh auth login -h github.com -w`

L'utente completa nel browser il login dell'account `CultureDigitali`. Nessun token viene salvato nel progetto.

- [ ] **Step 2: Creare e spingere il repository**

Run: `gh repo create CultureDigitali/MontaMac --public --source=. --remote=origin --push`

- [ ] **Step 3: Creare e spingere il tag annotato**

Run: `git tag -a v2.1.0 -m "MontaMac 2.1.0"` e `git push origin v2.1.0`.

- [ ] **Step 4: Pubblicare la release**

Run: `gh release create v2.1.0 dist/MontaMac-2.1.0.pkg dist/MontaMac-2.1.0.pkg.sha256 --title "MontaMac 2.1.0" --notes-file docs/releases/v2.1.0.md`.

- [ ] **Step 5: Verificare pubblicazione**

Run: `gh repo view CultureDigitali/MontaMac`, `gh release view v2.1.0` e confronto del checksum dell'allegato.

Expected: repository pubblico, branch `main`, licenza MIT, tag e due asset della release.
