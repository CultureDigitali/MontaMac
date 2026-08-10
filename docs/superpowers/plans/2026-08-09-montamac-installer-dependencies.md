# MontaMac Installer Dependencies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a prerequisite checker, user-confirmed setup assistant and installable macOS package.

**Architecture:** `RequirementChecker` detects Homebrew, rclone and FUSE-T without changing the system. The Setup view opens a user-confirmed Terminal command for missing dependencies; packaging scripts build an unsigned local `.pkg` that installs the app then launches it.

**Tech Stack:** SwiftUI, Foundation, XCTest, pkgbuild, productbuild, Homebrew.

## Global Constraints

- Never install dependencies silently or without explicit user confirmation.
- Run Homebrew commands as the logged-in user, not root.
- Do not ship credentials or rclone config files in the package.

---

### Task 1: Prerequisite checker

**Files:** `Sources/MontaMacCore/RequirementChecker.swift`, `Tests/MontaMacCoreTests/RequirementCheckerTests.swift`.

- [ ] Write a failing test for a checker whose PATH contains rclone but not FUSE-T.
- [ ] Run `swift test --filter RequirementCheckerTests`; expect missing type.
- [ ] Implement `RequirementStatus` and paths for `brew`, `rclone`, and FUSE-T.
- [ ] Run the test; expect PASS.

### Task 2: Setup Assistant

**Files:** `Sources/MontaMac/RequirementsView.swift`, `Sources/MontaMac/AppViewModel.swift`, `Sources/MontaMac/MainWindowView.swift`.

- [ ] Write a failing test for `installationCommand()` returning `brew install rclone` and `brew install --cask macos-fuse-t` only for missing requirements.
- [ ] Run test; expect missing command builder.
- [ ] Implement status cards, confirmation dialog, Terminal launch and live refresh.
- [ ] Run test; expect PASS.

### Task 3: Installer package

**Files:** `Scripts/build-pkg.sh`, `Installer/scripts/preinstall`, `Installer/scripts/postinstall`.

- [ ] Build app bundle first.
- [ ] Package `MontaMac.app` using `pkgbuild` and a distribution package using `productbuild`.
- [ ] Validate with `pkgutil --check-signature` and list package payload.

## Plan review

- Covers detection, user-confirmed installation, app packaging and verification.
