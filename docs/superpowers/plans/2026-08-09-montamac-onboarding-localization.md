# MontaMac Onboarding and Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make MontaMac self-guiding and fully available in Italian, English, French and Spanish.

**Architecture:** A localization layer wraps all user-facing copy behind stable keys. A first-run preference controls an onboarding sheet, while reusable guide content powers a searchable Help window and Settings controls.

**Tech Stack:** Swift 6.3, SwiftUI, Foundation, XCTest, `.xcstrings`/`Localizable.strings` resources.

## Global Constraints

- Support `it`, `en`, `fr`, `es`; default to macOS language and fall back to English.
- No user-facing SwiftUI string remains hard-coded.
- Keep credentials and mount behavior unchanged.
- Build and test before recreating `MontaMac.app`.

---

### Task 1: Localization catalog and language preference

**Files:**
- Create: `Sources/MontaMac/Localization.swift`
- Create: `Resources/{it,en,fr,es}.lproj/Localizable.strings`
- Create: `Tests/MontaMacCoreTests/LocalizationTests.swift`

- [ ] Write a failing test that requires Italian, English, French and Spanish values for `dashboard.title`.
- [ ] Run `swift test --filter LocalizationTests`; expect missing catalog support.
- [ ] Implement `AppLanguage`, `LocalizedText.key(_:)` and all four catalogs.
- [ ] Run the same test; expect PASS.

### Task 2: Onboarding and integrated guide

**Files:**
- Create: `Sources/MontaMac/OnboardingView.swift`
- Create: `Sources/MontaMac/HelpView.swift`
- Modify: `Sources/MontaMac/AppViewModel.swift`
- Modify: `Sources/MontaMac/MainWindowView.swift`

- [ ] Write a failing test asserting a new preference defaults to `showOnboarding == true`.
- [ ] Run the test; expect missing onboarding state.
- [ ] Implement three steps: requirements, connection, first mount; add searchable help and reset action.
- [ ] Run onboarding tests; expect PASS.

### Task 3: Translate all UI and package

**Files:**
- Modify: all `Sources/MontaMac/*.swift` UI files
- Modify: `README.md`

- [ ] Replace every user-facing string with localization keys.
- [ ] Build `swift test && swift build -c release`.
- [ ] Rebuild `MontaMac.app` with `zsh Scripts/build-app.sh` and validate its plist.

## Plan review

- Covers complete UI localization, language selection, onboarding, documentation and help.
- No placeholder requirements remain.
