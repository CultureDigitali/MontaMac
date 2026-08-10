# MontaMac Transfer and Cache Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make transfer statistics accurate, expose VFS cache disk usage, add dashboard credits, and ship MontaMac 2.1.1.

**Architecture:** Parse rclone one-line statistics inside MontaMacCore, track positive per-session byte deltas in MountCoordinator, and persist compact transfer events through AppViewModel. Measure the private cache root asynchronously with a dedicated service and render transfer, cache, and credits in an adaptive dashboard.

**Tech Stack:** Swift 6, SwiftUI, Combine, XCTest, rclone 1.73, zsh packaging scripts, macOS 15.

## Global Constraints

- Keep FTP, SFTP and WebDAV mount behavior unchanged.
- Do not open an rclone RC port or add dependencies.
- Keep cache and configuration permissions private.
- Localize new user-facing text in Italian, English, French and Spanish.
- Release version is `2.1.1`, build `5`.
- Use test-first red-green cycles for every behavior change.

---

### Task 1: Parse and track rclone transfer totals

**Files:**
- Create: `Sources/MontaMacCore/RcloneTransferStatistics.swift`
- Create: `Tests/MontaMacCoreTests/RcloneTransferStatisticsTests.swift`

**Interfaces:**
- Produces: `RcloneTransferStatisticsParser.totalBytes(from:) -> Int64?`
- Produces: `TransferProgressTracker.consume(totalBytes:) -> Int64`
- Produces: `TransferProgressTracker.reset()`

- [ ] **Step 1: Write failing parser and tracker tests**

```swift
func testParserReadsIECAndByteTotals() {
    XCTAssertEqual(RcloneTransferStatisticsParser.totalBytes(from: "Transferred: 1.500 MiB / 2 MiB, 75%, 1 MiB/s, ETA 1s"), 1_572_864)
    XCTAssertEqual(RcloneTransferStatisticsParser.totalBytes(from: "Transferred: 800 B / 800 B, 100%, 0 B/s, ETA -"), 800)
}

func testTrackerReturnsOnlyPositiveDeltasAndHandlesReset() {
    var tracker = TransferProgressTracker()
    XCTAssertEqual(tracker.consume(totalBytes: 1_000), 1_000)
    XCTAssertEqual(tracker.consume(totalBytes: 1_000), 0)
    XCTAssertEqual(tracker.consume(totalBytes: 1_500), 500)
    XCTAssertEqual(tracker.consume(totalBytes: 200), 200)
}
```

- [ ] **Step 2: Run `swift test --filter RcloneTransferStatisticsTests` and confirm missing symbols fail**
- [ ] **Step 3: Implement unit parsing and positive-delta tracking**
- [ ] **Step 4: Run the focused tests and confirm they pass**
- [ ] **Step 5: Commit `feat: parse rclone transfer statistics`**

### Task 2: Wire rclone output into live session totals

**Files:**
- Modify: `Sources/MontaMacCore/RcloneService.swift`
- Modify: `Sources/MontaMacCore/MountCoordinator.swift`
- Modify: `Tests/MontaMacCoreTests/RcloneServiceTests.swift`
- Modify: `Tests/MontaMacCoreTests/MountCoordinatorSecurityTests.swift`

**Interfaces:**
- Produces: `MountCoordinator.transferTotals: [UUID: Int64]`
- Produces: `MountCoordinator.cacheRootURL: URL`
- Consumes: `RcloneTransferStatisticsParser` and `TransferProgressTracker`

- [ ] **Step 1: Add failing tests for required stats flags and parsed coordinator totals**

```swift
XCTAssertTrue(arguments.contains("--stats"))
XCTAssertTrue(arguments.contains("5s"))
XCTAssertTrue(arguments.contains("--stats-one-line"))
XCTAssertTrue(arguments.contains("--stats-log-level"))
XCTAssertTrue(arguments.contains("NOTICE"))

rclone.emit("Transferred: 2 KiB / 2 KiB, 100%, 0 B/s, ETA -\n")
XCTAssertEqual(coordinator.transferTotals[connection.id], 2_048)
```

- [ ] **Step 2: Run both focused suites and confirm expected failures**
- [ ] **Step 3: Add the rclone flags, line buffering and per-profile transfer trackers**
- [ ] **Step 4: Reset tracker state when mounting a new process and expose the cache root read-only**
- [ ] **Step 5: Run focused tests and confirm they pass**
- [ ] **Step 6: Commit `feat: report live mount transfers`**

### Task 3: Persist compact transfer activity

**Files:**
- Modify: `Sources/MontaMacCore/ActivityStore.swift`
- Modify: `Sources/MontaMac/AppViewModel.swift`
- Modify: `Tests/MontaMacCoreTests/ActivityStoreTests.swift`

**Interfaces:**
- Consumes: `MountCoordinator.$transferTotals`
- Produces: compact consecutive `.transfer` events for the same connection

- [ ] **Step 1: Add a failing test proving consecutive transfer events are merged**

```swift
try store.record(.transfer(connectionID: id, bytes: 1_024, at: date))
try store.record(.transfer(connectionID: id, bytes: 2_048, at: date.addingTimeInterval(1)))
XCTAssertEqual(try store.summary(since: date.addingTimeInterval(-1)).transferredBytes, 3_072)
XCTAssertEqual(try store.recentEvents().count, 1)
```

- [ ] **Step 2: Run `swift test --filter ActivityStoreTests` and confirm recent event count fails**
- [ ] **Step 3: Merge only adjacent transfer events for the same connection in `record`**
- [ ] **Step 4: Subscribe AppViewModel to transfer totals and persist positive deltas on the main actor**
- [ ] **Step 5: Run ActivityStore tests and the full suite**
- [ ] **Step 6: Commit `fix: persist transferred bytes`**

### Task 4: Measure local cache disk usage

**Files:**
- Create: `Sources/MontaMacCore/DirectorySizeService.swift`
- Create: `Tests/MontaMacCoreTests/DirectorySizeServiceTests.swift`
- Modify: `Sources/MontaMac/AppViewModel.swift`

**Interfaces:**
- Produces: `DirectorySizeService.allocatedBytes(at:) throws -> Int64`
- Produces: `AppViewModel.cacheBytes: Int64`
- Produces: `AppViewModel.refreshDashboardMetrics()`

- [ ] **Step 1: Add a failing nested-directory size test with literal file sizes**

```swift
try Data(repeating: 0x41, count: 1_024).write(to: root.appendingPathComponent("a.bin"))
try Data(repeating: 0x42, count: 2_048).write(to: nested.appendingPathComponent("b.bin"))
XCTAssertGreaterThanOrEqual(try DirectorySizeService().allocatedBytes(at: root), 3_072)
```

- [ ] **Step 2: Run the focused test and confirm missing symbol failure**
- [ ] **Step 3: Implement a recursive, symlink-safe allocated-size scan with logical-size fallback**
- [ ] **Step 4: Refresh cache bytes asynchronously at startup, on dashboard refresh and after transfer changes**
- [ ] **Step 5: Run focused and full tests**
- [ ] **Step 6: Commit `feat: measure temporary cache usage`**

### Task 5: Redesign dashboard metrics and footer credits

**Files:**
- Modify: `Sources/MontaMac/DashboardView.swift`
- Modify: `Sources/MontaMac/MainWindowView.swift`
- Modify: `Sources/MontaMac/Resources/it.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/fr.lproj/Localizable.strings`
- Modify: `Sources/MontaMac/Resources/es.lproj/Localizable.strings`
- Modify: `Tests/MontaMacCoreTests/LocalizationCompletenessTests.swift`

**Interfaces:**
- `DashboardView` consumes `cacheBytes` and `onRefresh`
- Footer consumes `CreditsContent.website`

- [ ] **Step 1: Add failing localization requirements for `Cache temporanea` and `Aggiornamento automatico`**
- [ ] **Step 2: Run `swift test --filter LocalizationCompletenessTests` and confirm missing keys fail**
- [ ] **Step 3: Add all four translations**
- [ ] **Step 4: Replace the metric HStack with an adaptive LazyVGrid and add the cache card**
- [ ] **Step 5: Add a subtle linked creator footer and a cancellable ten-second refresh task**
- [ ] **Step 6: Build the executable and run the localization test**
- [ ] **Step 7: Commit `feat: improve dashboard storage insights`**

### Task 6: Version, package, install and publish

**Files:**
- Modify: `Resources/Info.plist`
- Modify: `Scripts/build-pkg.sh`
- Modify: `Tests/MontaMacCoreTests/ReleaseHardeningTests.swift`
- Create: `docs/releases/v2.1.1.md`

**Interfaces:**
- Produces: `MontaMac.app` version `2.1.1` build `5`
- Produces: `dist/MontaMac-2.1.1.pkg`

- [ ] **Step 1: Update the metadata test to expect version 2.1.1, build 5 and installer name 2.1.1**
- [ ] **Step 2: Run `swift test --filter ReleaseHardeningTests` and confirm it fails against 2.1.0**
- [ ] **Step 3: Update plist, package script and release notes**
- [ ] **Step 4: Run `swift test`, `Scripts/build-app.sh` and `Scripts/build-pkg.sh`**
- [ ] **Step 5: Verify plist versions, signatures, package contents and secret scan**
- [ ] **Step 6: Replace `/Applications/MontaMac.app`, relaunch it and verify the running bundle is 2.1.1 (5)**
- [ ] **Step 7: Commit release changes, push the branch and open a ready pull request to `main`**
- [ ] **Step 8: Verify GitHub CI and report the PR URL**
