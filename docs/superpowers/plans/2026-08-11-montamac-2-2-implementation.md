# MontaMac 2.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver MontaMac 2.2.0 build 6 with bounded mount recovery, localized issue handling, safe cache controls, live transfer telemetry, and production-ready signed update infrastructure.

**Architecture:** Keep `MountCoordinator` as the main-actor mount authority, but move retry policy, issue persistence, cache operations, JSON telemetry, and updates into focused services. Preserve current profiles and Keychain entries, and expose new state through native SwiftUI destinations without rewriting the application.

**Tech Stack:** Swift 6, SwiftUI, Combine, Foundation `Process`, rclone JSON logs, UserDefaults, secure JSON stores, Sparkle 2.9.2, zsh packaging, GitHub Actions, Apple `notarytool`.

## Global Constraints

- Target macOS 15 or later.
- Release version is 2.2.0 and bundle build is 6.
- Existing profile JSON and Keychain passwords must remain compatible.
- Passwords never leave Keychain; temporary rclone configuration remains protected and short-lived.
- Retry sequence is 2, 5, and 15 seconds with at most three automatic retries.
- Default cache limit is 5 GB per profile and reserved free space is 5 GB.
- Supported languages remain Italian, English, French, and Spanish with identical key sets.
- Live file names are memory-only and never persist in activity or diagnostic files.
- Secure updates remain disabled unless both `SUFeedURL` and `SUPublicEDKey` are injected.
- The original `montamac` directory must not be modified.

## File Structure

Create focused core files:

- `Sources/MontaMacCore/MountRecoveryPolicy.swift`: retry decisions.
- `Sources/MontaMacCore/MountProcess.swift`: testable process lifecycle adapter.
- `Sources/MontaMacCore/AppIssue.swift`: issue codes, severity, recovery metadata.
- `Sources/MontaMacCore/IssueStore.swift`: bounded protected issue persistence.
- `Sources/MontaMacCore/CachePolicy.swift`: cache limits and argument values.
- `Sources/MontaMacCore/CacheUsageService.swift`: cancellable measurement and contained cleanup.
- `Sources/MontaMacCore/TransferSnapshot.swift`: live transfer value types.
- `Sources/MontaMacCore/RcloneJSONLogParser.swift`: fragmented JSON stream parser.
- `Sources/MontaMacCore/UpdateConfiguration.swift`: secure updater gating.

Create focused app files:

- `Sources/MontaMac/IssueCenter.swift`: observable issue state and recovery routing.
- `Sources/MontaMac/IssueCenterView.swift`: history and banner UI.
- `Sources/MontaMac/CacheManagementView.swift`: cache dashboard and cleanup UI.
- `Sources/MontaMac/TransferCenterView.swift`: live per-profile transfers.
- `Sources/MontaMac/UpdateController.swift`: Sparkle controller wrapper.

Modify existing coordinator, model, navigation, settings, localization, build, installer, and workflow files only where their current responsibility requires it.

---

### Task 1: Recovery Policy and Status Model

**Files:**
- Create: `Sources/MontaMacCore/MountRecoveryPolicy.swift`
- Modify: `Sources/MontaMacCore/MontaMacCore.swift`
- Create: `Tests/MontaMacCoreTests/MountRecoveryPolicyTests.swift`
- Modify: `Tests/MontaMacCoreTests/MountStatusTests.swift`

**Interfaces:**
- Produces: `MountRecoveryPolicy.init(delays:)`, `delay(forAttempt:) -> TimeInterval?`, and `MountStatus.reconnecting(attempt:delay:)`.
- Consumes: no new interfaces.

- [ ] **Step 1: Write failing recovery-policy tests**

```swift
final class MountRecoveryPolicyTests: XCTestCase {
    func testDefaultPolicyStopsAfterThreeAttempts() {
        let policy = MountRecoveryPolicy()
        XCTAssertEqual(policy.delay(forAttempt: 1), 2)
        XCTAssertEqual(policy.delay(forAttempt: 2), 5)
        XCTAssertEqual(policy.delay(forAttempt: 3), 15)
        XCTAssertNil(policy.delay(forAttempt: 4))
    }
}
```

Add a status test asserting `.reconnecting(attempt: 2, delay: 5)` remains equatable and exposes a stable localization key rather than an Italian sentence.

- [ ] **Step 2: Run the focused tests and verify the red state**

Run: `swift test --filter MountRecoveryPolicyTests && swift test --filter MountStatusTests`

Expected: compilation fails because the policy and reconnecting status do not exist.

- [ ] **Step 3: Implement the policy and richer status**

```swift
public struct MountRecoveryPolicy: Sendable, Equatable {
    public let delays: [TimeInterval]
    public init(delays: [TimeInterval] = [2, 5, 15]) { self.delays = delays }
    public func delay(forAttempt attempt: Int) -> TimeInterval? {
        guard attempt > 0, attempt <= delays.count else { return nil }
        return delays[attempt - 1]
    }
}

public enum MountStatus: Equatable, Sendable {
    case disconnected, connecting, mounted, disconnecting
    case reconnecting(attempt: Int, delay: TimeInterval)
    case failed(String)
}
```

Keep a `localizationKey` property for non-failure states and preserve the failure detail separately.

- [ ] **Step 4: Run focused and full core tests**

Run: `swift test --filter MountRecoveryPolicyTests && swift test --filter MountStatusTests && swift test`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/MontaMacCore/MountRecoveryPolicy.swift Sources/MontaMacCore/MontaMacCore.swift Tests/MontaMacCoreTests/MountRecoveryPolicyTests.swift Tests/MontaMacCoreTests/MountStatusTests.swift
git commit -m "feat: add bounded mount recovery policy"
```

### Task 2: Testable Process Lifecycle and Automatic Recovery

**Files:**
- Create: `Sources/MontaMacCore/MountProcess.swift`
- Modify: `Sources/MontaMacCore/RcloneServicing.swift`
- Modify: `Sources/MontaMacCore/RcloneService.swift`
- Modify: `Sources/MontaMacCore/MountCoordinator.swift`
- Modify: `Tests/MontaMacCoreTests/MountCoordinatorSecurityTests.swift`

**Interfaces:**
- Consumes: `MountRecoveryPolicy.delay(forAttempt:)` and existing `MountMonitoring`.
- Produces: `MountProcessHandling`, observable retry state, `cancelRecovery(for:)`, and `handleUnexpectedTermination(for:status:)` for coordinator tests.

- [ ] **Step 1: Add failing lifecycle tests with a fake process**

```swift
private final class FakeMountProcess: MountProcessHandling {
    var isRunning = true
    var terminationHandler: (@Sendable (Int32) -> Void)?
    func terminate() { isRunning = false }
    func observeTermination(_ handler: @escaping @Sendable (Int32) -> Void) {
        terminationHandler = handler
    }
    func exit(_ status: Int32) { isRunning = false; terminationHandler?(status) }
}
```

Cover these behaviors:

- unexpected exit schedules attempt 1 and publishes reconnecting;
- a successful remount resets the retry counter;
- attempt 4 becomes failed and starts no process;
- manual unmount cancels the pending retry;
- an already mounted profile still starts no duplicate process.

- [ ] **Step 2: Run the coordinator tests and verify failure**

Run: `swift test --filter MountCoordinatorSecurityTests`

Expected: compilation fails because `MountProcessHandling` and recovery APIs are missing.

- [ ] **Step 3: Introduce the process adapter**

```swift
public protocol MountProcessHandling: AnyObject {
    var isRunning: Bool { get }
    func terminate()
    func observeTermination(_ handler: @escaping @Sendable (Int32) -> Void)
}

extension Process: MountProcessHandling {
    public func observeTermination(_ handler: @escaping @Sendable (Int32) -> Void) {
        terminationHandler = { process in handler(process.terminationStatus) }
    }
}
```

Change `RcloneServicing.startMount` to return `any MountProcessHandling` and update its fakes.

- [ ] **Step 4: Add coordinator session intent and recovery tasks**

Store per-profile process, intended-mounted state, retry count, and retry `Task`. Register termination observation immediately after start. Route callbacks to `Task { @MainActor in ... }`.

Use the exact decision structure:

```swift
guard intendedMounted.contains(connection.id) else { return }
let attempt = retryCounts[connection.id, default: 0] + 1
guard let delay = recoveryPolicy.delay(forAttempt: attempt) else {
    fail(connection, "mount.recovery.exhausted")
    return
}
statuses[connection.id] = .reconnecting(attempt: attempt, delay: delay)
retryCounts[connection.id] = attempt
```

Before retry, remove the stale process and configuration, sleep through an injected async sleeper, re-check intent, and call the internal mount routine. Manual unmount clears intent before terminating the process.

- [ ] **Step 5: Add periodic mount-health reconciliation**

Create one cancellable health task per mounted profile. Every five seconds it checks both process state and `monitor.isMounted`. Loss routes through the same unexpected-termination method. Cancel it on manual unmount, deletion, or final failure.

- [ ] **Step 6: Run lifecycle and full tests**

Run: `swift test --filter MountCoordinatorSecurityTests && swift test`

Expected: all tests pass without real delays because tests inject an immediate sleeper.

- [ ] **Step 7: Commit**

```bash
git add Sources/MontaMacCore/MountProcess.swift Sources/MontaMacCore/RcloneServicing.swift Sources/MontaMacCore/RcloneService.swift Sources/MontaMacCore/MountCoordinator.swift Tests/MontaMacCoreTests/MountCoordinatorSecurityTests.swift
git commit -m "feat: recover interrupted mounts safely"
```

### Task 3: Issue Model, Persistence, and Localized Runtime Errors

**Files:**
- Create: `Sources/MontaMacCore/AppIssue.swift`
- Create: `Sources/MontaMacCore/IssueStore.swift`
- Create: `Sources/MontaMac/IssueCenter.swift`
- Create: `Sources/MontaMac/IssueCenterView.swift`
- Modify: `Sources/MontaMac/AppViewModel.swift`
- Modify: `Sources/MontaMac/MainWindowView.swift`
- Modify: `Sources/MontaMac/MontaMacApp.swift`
- Modify: `Sources/MontaMacCore/SensitiveLogRedactor.swift`
- Modify: `Sources/MontaMacCore/DiagnosticsService.swift`
- Create: `Tests/MontaMacCoreTests/IssueStoreTests.swift`
- Modify: `Tests/MontaMacCoreTests/SensitiveLogRedactorTests.swift`

**Interfaces:**
- Produces: `AppIssue`, `AppIssueCode`, `IssueStore.record`, `IssueStore.recent`, and `IssueCenter.report`.
- Consumes: `SecureFileStore`, selected `AppLanguage`, connection IDs, and safe recovery actions.

- [ ] **Step 1: Write failing bounded-store and coalescing tests**

```swift
func testRepeatedIssueIsCoalescedAndCounted() throws {
    let store = IssueStore(fileURL: temporaryURL)
    let issue = AppIssue(code: .mountInterrupted, profileID: profileID, arguments: [])
    try store.record(issue)
    try store.record(issue)
    let saved = try store.recent(limit: 100)
    XCTAssertEqual(saved.count, 1)
    XCTAssertEqual(saved[0].occurrenceCount, 2)
}
```

Also verify storage is capped at 100 and contains no supplied password, host, username, mount path, or active filename after redaction.

- [ ] **Step 2: Run issue tests and verify failure**

Run: `swift test --filter IssueStoreTests && swift test --filter SensitiveLogRedactorTests`

Expected: compilation fails because issue types are missing.

- [ ] **Step 3: Implement stable issue values and protected storage**

```swift
public enum AppIssueCode: String, Codable, Sendable {
    case profileSaveFailed, credentialSaveFailed, activityWriteFailed
    case mountInterrupted, mountRecoveryExhausted, cacheCleanupFailed
    case diagnosticsExportFailed, updateCheckFailed
}

public struct AppIssue: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let code: AppIssueCode
    public let profileID: UUID?
    public let arguments: [String]
    public let severity: IssueSeverity
    public var timestamp: Date
    public var occurrenceCount: Int
    public let recovery: IssueRecovery?
}
```

Persist with `SecureFileStore`, merge only consecutive matching code/profile pairs, and keep the latest 100.

- [ ] **Step 4: Replace user-impacting silent failures**

Inject `IssueCenter` into `AppViewModel`. Replace `try?` for profile, credential, activity, cleanup, and diagnostics operations with `do/catch` that reports the matching issue and leaves state consistent. Do not classify best-effort resource-value reads as user-facing failures.

- [ ] **Step 5: Build Issue Center UI and diagnostic export**

Add a dismissible top banner to `MainWindowView` and an Issue Center destination showing timestamp, localized description, count, severity, and supported recovery button. Export diagnostics through `NSSavePanel`; generate content in core code and exclude all active file names plus configuration contents.

- [ ] **Step 6: Convert core runtime messages to localization keys**

Replace preformatted Italian core errors with stable codes and safe arguments. Add every new key to all four localization files, including reconnecting, retry exhausted, save failures, cache failures, update failures, retry, diagnostics, and issue-history copy.

- [ ] **Step 7: Run issue, localization, and full tests**

Run: `swift test --filter IssueStoreTests && swift test --filter LocalizationCompletenessTests && swift test`

Expected: all tests pass and language key sets are identical.

- [ ] **Step 8: Commit**

```bash
git add Sources/MontaMacCore/AppIssue.swift Sources/MontaMacCore/IssueStore.swift Sources/MontaMac/IssueCenter.swift Sources/MontaMac/IssueCenterView.swift Sources/MontaMac/AppViewModel.swift Sources/MontaMac/MainWindowView.swift Sources/MontaMac/MontaMacApp.swift Sources/MontaMacCore/SensitiveLogRedactor.swift Sources/MontaMacCore/DiagnosticsService.swift Sources/MontaMac/Resources Tests/MontaMacCoreTests
git commit -m "feat: add localized issue center"
```

### Task 4: Cache Policy Settings and Profile Compatibility

**Files:**
- Create: `Sources/MontaMacCore/CachePolicy.swift`
- Modify: `Sources/MontaMacCore/AppSettings.swift`
- Modify: `Sources/MontaMacCore/Connection.swift`
- Modify: `Sources/MontaMac/ConnectionEditorView.swift`
- Modify: `Sources/MontaMac/SettingsView.swift`
- Modify: `Sources/MontaMacCore/RcloneServicing.swift`
- Modify: `Sources/MontaMacCore/RcloneService.swift`
- Create: `Tests/MontaMacCoreTests/CachePolicyTests.swift`
- Modify: `Tests/MontaMacCoreTests/ConnectionStoreCompatibilityTests.swift`
- Modify: `Tests/MontaMacCoreTests/RcloneServiceTests.swift`

**Interfaces:**
- Produces: `CacheLimit`, `CachePolicy`, `CachePolicyResolver`, and an optional `RemoteConnection.cacheLimit` override.
- Consumes: UserDefaults and rclone VFS flags.

- [ ] **Step 1: Write failing policy and legacy-decoding tests**

```swift
func testDefaultPolicyProducesFiveGigabyteLimitAndReserve() {
    let policy = CachePolicy.default
    XCTAssertEqual(policy.limit, .gb5)
    XCTAssertEqual(policy.reservedFreeSpaceGB, 5)
    XCTAssertEqual(policy.rcloneArguments, [
        "--vfs-cache-max-size", "5G",
        "--vfs-cache-min-free-space", "5G",
        "--vfs-cache-poll-interval", "1m",
    ])
}
```

Extend the legacy JSON fixture to prove missing `cacheLimit` decodes as `nil` and re-encoding preserves existing fields.

- [ ] **Step 2: Run focused tests and verify failure**

Run: `swift test --filter CachePolicyTests && swift test --filter ConnectionStoreCompatibilityTests && swift test --filter RcloneServiceTests`

Expected: policy tests fail to compile.

- [ ] **Step 3: Implement policy and settings persistence**

```swift
public enum CacheLimit: String, Codable, CaseIterable, Sendable {
    case gb1, gb5, gb10, gb25, unlimited
    public var rcloneValue: String? {
        switch self {
        case .gb1: "1G"; case .gb5: "5G"; case .gb10: "10G"
        case .gb25: "25G"; case .unlimited: nil
        }
    }
}

public struct CachePolicy: Equatable, Sendable {
    public var limit: CacheLimit
    public var reservedFreeSpaceGB: Int
    public static let `default` = CachePolicy(limit: .gb5, reservedFreeSpaceGB: 5)
}
```

Add UserDefaults-backed automatic reconnect, default cache limit, reserved free space, and automatic update-check settings to `AppSettings`.

- [ ] **Step 4: Add the optional per-profile override and editor picker**

Add `cacheLimit: CacheLimit?` to `RemoteConnection` with `decodeIfPresent`. Present `Use app default`, 1, 5, 10, 25 GB, and Unlimited in the connection editor.

- [ ] **Step 5: Apply policy to rclone arguments**

Change `mountArguments` to accept `CachePolicy`. Always pass minimum free space and poll interval; pass maximum size only when not unlimited. Keep `--vfs-cache-max-age 1h` and existing secure umask.

- [ ] **Step 6: Run focused and full tests**

Run: `swift test --filter CachePolicyTests && swift test --filter ConnectionStoreCompatibilityTests && swift test --filter RcloneServiceTests && swift test`

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/MontaMacCore/CachePolicy.swift Sources/MontaMacCore/AppSettings.swift Sources/MontaMacCore/Connection.swift Sources/MontaMac/ConnectionEditorView.swift Sources/MontaMac/SettingsView.swift Sources/MontaMacCore/RcloneServicing.swift Sources/MontaMacCore/RcloneService.swift Tests/MontaMacCoreTests
git commit -m "feat: add configurable cache policy"
```

### Task 5: Cache Measurement, Safe Cleanup, and Cache UI

**Files:**
- Create: `Sources/MontaMacCore/CacheUsageService.swift`
- Modify: `Sources/MontaMacCore/DirectorySizeService.swift`
- Create: `Sources/MontaMac/CacheManagementView.swift`
- Modify: `Sources/MontaMac/AppViewModel.swift`
- Modify: `Sources/MontaMac/ProfileManagerView.swift`
- Modify: `Sources/MontaMac/MainWindowView.swift`
- Create: `Tests/MontaMacCoreTests/CacheUsageServiceTests.swift`
- Modify: `Tests/MontaMacCoreTests/DirectorySizeServiceTests.swift`

**Interfaces:**
- Consumes: profile UUID cache directories, `CachePolicy`, and coordinator mount status.
- Produces: `CacheUsageSnapshot`, `measure`, and `clear(profileID:cacheRoot:isMounted:)`.

- [ ] **Step 1: Write failing containment and mounted-profile tests**

```swift
func testClearRefusesMountedProfileAndUnrelatedPath() throws {
    let service = CacheUsageService()
    XCTAssertThrowsError(try service.clear(profileID: id, cacheRoot: root, isMounted: true))
    XCTAssertTrue(FileManager.default.fileExists(atPath: profileCache.path))
}

func testClearDeletesOnlyExactUUIDChild() throws {
    try CacheUsageService().clear(profileID: id, cacheRoot: root, isMounted: false)
    XCTAssertFalse(FileManager.default.fileExists(atPath: profileCache.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: sibling.path))
}
```

Add cancellation coverage for a multi-file scan and verify symbolic links are not followed.

- [ ] **Step 2: Run focused tests and verify failure**

Run: `swift test --filter CacheUsageServiceTests && swift test --filter DirectorySizeServiceTests`

Expected: compilation fails because the service is missing.

- [ ] **Step 3: Implement measurement and cleanup**

```swift
public struct CacheUsageSnapshot: Equatable, Sendable {
    public let totalBytes: Int64
    public let bytesByProfile: [UUID: Int64]
    public let availableDiskBytes: Int64
    public let measuredAt: Date
}
```

Check `Task.isCancelled` during enumeration. Before deletion, require the standardized target's parent to equal the standardized cache root and its last component to equal the UUID string. Reject mounted profiles before any filesystem mutation.

- [ ] **Step 4: Add observable cache state to the view model**

Publish one snapshot and refresh it from a cancellable utility-priority task. Propagate cancellation to the scan instead of leaving detached scans running. Report cleanup failures through `IssueCenter`.

- [ ] **Step 5: Build native Cache Management UI**

Show total cache, free disk, last refresh, and a row for every profile with usage, effective policy, mount state, and `Clear Cache`. Disable cleanup while mounted and include the rclone quota caveat. Add the Cache sidebar destination and refresh command.

- [ ] **Step 6: Run focused and full tests**

Run: `swift test --filter CacheUsageServiceTests && swift test --filter DirectorySizeServiceTests && swift test`

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/MontaMacCore/CacheUsageService.swift Sources/MontaMacCore/DirectorySizeService.swift Sources/MontaMac/CacheManagementView.swift Sources/MontaMac/AppViewModel.swift Sources/MontaMac/ProfileManagerView.swift Sources/MontaMac/MainWindowView.swift Tests/MontaMacCoreTests
git commit -m "feat: add safe cache management"
```

### Task 6: Structured rclone JSON Telemetry

**Files:**
- Create: `Sources/MontaMacCore/TransferSnapshot.swift`
- Create: `Sources/MontaMacCore/RcloneJSONLogParser.swift`
- Modify: `Sources/MontaMacCore/RcloneService.swift`
- Modify: `Sources/MontaMacCore/MountCoordinator.swift`
- Create: `Tests/MontaMacCoreTests/RcloneJSONLogParserTests.swift`
- Modify: `Tests/MontaMacCoreTests/RcloneServiceTests.swift`
- Modify: `Tests/MontaMacCoreTests/MountCoordinatorSecurityTests.swift`

**Interfaces:**
- Produces: `TransferSnapshot`, `ActiveTransfer`, `RcloneLogRecord`, and stateful `RcloneJSONLogParser.consume`.
- Consumes: newline-delimited rclone `--use-json-log` output.

- [ ] **Step 1: Write failing fragmented JSON tests**

```swift
func testFragmentedStatsRecordProducesSnapshotOnlyWhenComplete() throws {
    var parser = RcloneJSONLogParser()
    XCTAssertTrue(parser.consume("{\"msg\":\"stats\",\"stats\":{").isEmpty)
    let records = parser.consume("\"bytes\":2048,\"totalBytes\":4096,\"speed\":512,\"eta\":4}}\n")
    XCTAssertEqual(records.first?.snapshot?.bytes, 2_048)
    XCTAssertEqual(records.first?.snapshot?.totalBytes, 4_096)
    XCTAssertEqual(records.first?.snapshot?.bytesPerSecond, 512)
    XCTAssertEqual(records.first?.snapshot?.etaSeconds, 4)
}
```

Add active-transfer decoding, malformed-line fallback, multiple records per chunk, and no-persisted-filename assertions.

- [ ] **Step 2: Run parser tests and verify failure**

Run: `swift test --filter RcloneJSONLogParserTests`

Expected: compilation fails because telemetry types are missing.

- [ ] **Step 3: Implement value types and incremental parser**

```swift
public struct ActiveTransfer: Equatable, Sendable {
    public let name: String
    public let bytes: Int64
    public let size: Int64
    public let percentage: Int
    public let bytesPerSecond: Double
    public let etaSeconds: Int?
}

public struct TransferSnapshot: Equatable, Sendable {
    public let bytes: Int64
    public let totalBytes: Int64
    public let bytesPerSecond: Double
    public let etaSeconds: Int?
    public let active: [ActiveTransfer]
    public let capturedAt: Date
}
```

Decode rclone's `stats` object keys `bytes`, `totalBytes`, `speed`, `eta`, and `transferring`. Keep incomplete bytes in the parser buffer. Return non-stats JSON messages separately for redacted logging.

- [ ] **Step 4: Switch rclone mount output to JSON stats**

Replace one-line text flags with:

```swift
"--use-json-log",
"--stats", "1s",
"--stats-log-level", "NOTICE",
```

Do not append structured stats records to the persistent log. Publish snapshots through `MountCoordinator.transferSnapshots`; derive positive cumulative byte deltas from `snapshot.bytes` and preserve remount reset behavior.

- [ ] **Step 5: Run parser, coordinator, and full tests**

Run: `swift test --filter RcloneJSONLogParserTests && swift test --filter MountCoordinatorSecurityTests && swift test --filter RcloneServiceTests && swift test`

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/MontaMacCore/TransferSnapshot.swift Sources/MontaMacCore/RcloneJSONLogParser.swift Sources/MontaMacCore/RcloneService.swift Sources/MontaMacCore/MountCoordinator.swift Tests/MontaMacCoreTests
git commit -m "feat: collect structured transfer telemetry"
```

### Task 7: Transfer Center, Navigation, and Live Profile Indicators

**Files:**
- Create: `Sources/MontaMac/TransferCenterView.swift`
- Modify: `Sources/MontaMac/AppViewModel.swift`
- Modify: `Sources/MontaMac/ProfileManagerView.swift`
- Modify: `Sources/MontaMac/ConnectionRow.swift`
- Modify: `Sources/MontaMac/MainWindowView.swift`
- Modify: `Sources/MontaMac/DashboardView.swift`
- Modify: `Sources/MontaMac/MontaMacCommands.swift`
- Modify: `Sources/MontaMac/MenuActions.swift`
- Modify: all four `Localizable.strings` files
- Modify: `Tests/MontaMacCoreTests/LocalizationCompletenessTests.swift`

**Interfaces:**
- Consumes: `MountCoordinator.transferSnapshots`, connections, and mount statuses.
- Produces: `UtilityDestination.dashboard`, `.transfers`, `.cache`, `.issues` and native transfer views.

- [ ] **Step 1: Add a failing navigation-state test in core**

Create `UtilityDestination` in core so it can be tested without SwiftUI:

```swift
func testUtilityDestinationsHaveStableIdentifiers() {
    XCTAssertEqual(UtilityDestination.allCases.map(\.rawValue), [
        "dashboard", "transfers", "cache", "issues",
    ])
}
```

- [ ] **Step 2: Run the focused test and verify failure**

Run: `swift test --filter UtilityDestinationTests`

Expected: compilation fails because the destination type is missing.

- [ ] **Step 3: Implement navigation state without losing profile selection**

Add `@Published var utilityDestination: UtilityDestination? = .dashboard`. Selecting a profile sets it to `nil`; selecting a utility destination keeps the last profile ID but shows the requested detail. Update menu actions to expose all four destinations.

- [ ] **Step 4: Build the Transfer Center**

Use an adaptive card grid. Show aggregate current speed and active count, then one card per mounted or reconnecting profile. Each active transfer shows redacted filename, `ProgressView`, transferred/size, speed, and ETA. Show `Mounted and idle` when no transfer exists.

- [ ] **Step 5: Add compact live indicators and dashboard speed**

Pass the snapshot into `ConnectionRow`; animate a small bidirectional-arrow indicator only while speed is positive. Add aggregate current speed to the dashboard while keeping the existing 30-day transferred-byte total.

- [ ] **Step 6: Complete four-language UI keys and accessibility labels**

Add Transfers, Cache, Issues, Current speed, Active files, ETA, Idle, Reconnecting, Clear Cache, Retry, and update-related strings to all locales. Require equality of complete key sets, not only a hand-maintained subset.

- [ ] **Step 7: Run localization and full tests, then build**

Run: `swift test --filter LocalizationCompletenessTests && swift test && zsh Scripts/build-app.sh`

Expected: tests and release build pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/MontaMac Sources/MontaMacCore/UtilityDestination.swift Sources/MontaMac/Resources Tests/MontaMacCoreTests
git commit -m "feat: add live transfer center"
```

### Task 8: Secure Sparkle Update Integration

**Files:**
- Modify: `Package.swift`
- Modify: `Package.resolved`
- Create: `Sources/MontaMacCore/UpdateConfiguration.swift`
- Create: `Sources/MontaMac/UpdateController.swift`
- Modify: `Sources/MontaMac/MontaMacApp.swift`
- Modify: `Sources/MontaMac/SettingsView.swift`
- Modify: `Resources/Info.plist`
- Create: `Resources/MontaMac.local.entitlements`
- Modify: `Scripts/build-app.sh`
- Create: `Tests/MontaMacCoreTests/UpdateConfigurationTests.swift`
- Modify: `Tests/MontaMacCoreTests/ReleaseHardeningTests.swift`

**Interfaces:**
- Produces: `UpdateConfiguration.init(infoDictionary:)`, `isSecurelyConfigured`, and `UpdateController.checkForUpdates`.
- Consumes: Sparkle 2.9.2, `SUFeedURL`, `SUPublicEDKey`, and automatic-check preferences.

- [ ] **Step 1: Write failing updater-gating tests**

```swift
func testSecureUpdatesRequireFeedAndPublicKeyTogether() {
    XCTAssertFalse(UpdateConfiguration(infoDictionary: [:]).isSecurelyConfigured)
    XCTAssertFalse(UpdateConfiguration(infoDictionary: ["SUFeedURL": "https://example.com/appcast.xml"]).isSecurelyConfigured)
    XCTAssertTrue(UpdateConfiguration(infoDictionary: [
        "SUFeedURL": "https://example.com/appcast.xml",
        "SUPublicEDKey": "public-key",
    ]).isSecurelyConfigured)
}
```

- [ ] **Step 2: Run updater tests and verify failure**

Run: `swift test --filter UpdateConfigurationTests`

Expected: compilation fails because the configuration type is missing.

- [ ] **Step 3: Add the exact Sparkle dependency**

```swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.2"),
],
```

Add `.product(name: "Sparkle", package: "Sparkle")` to the executable target only. Resolve and commit `Package.resolved`.

- [ ] **Step 4: Implement secure configuration and controller wrapper**

```swift
final class UpdateController: ObservableObject {
    let configuration: UpdateConfiguration
    private let controller: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        configuration = UpdateConfiguration(infoDictionary: bundle.infoDictionary ?? [:])
        controller = configuration.isSecurelyConfigured
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
    }

    func checkForUpdates() { controller?.checkForUpdates(nil) }
}
```

Expose configured/unavailable state in Settings. Never create a live updater when either key is missing.

- [ ] **Step 5: Embed and sign Sparkle in the hand-built app bundle**

Create `Contents/Frameworks`, copy `Sparkle.framework` from the SwiftPM release product with `ditto` to preserve symlinks and permissions, then sign nested Sparkle components before signing the app. Verify with:

```bash
codesign --verify --deep --strict MontaMac.app
otool -L MontaMac.app/Contents/MacOS/MontaMac | grep Sparkle
test -d MontaMac.app/Contents/Frameworks/Sparkle.framework
```

Inject both plist keys only when `MONTAMAC_UPDATE_FEED_URL` and `MONTAMAC_SPARKLE_PUBLIC_KEY` are non-empty; otherwise remove both from the copied app plist.

For local ad-hoc builds only, sign the host app with an entitlement file containing `com.apple.security.cs.disable-library-validation = true` so the ad-hoc host can load the embedded framework. Production Developer ID builds must omit this entitlement and rely on consistent Apple signing for the host and every nested Sparkle component.

- [ ] **Step 6: Run tests and local ad-hoc build checks**

Run: `swift test --filter UpdateConfigurationTests && swift test && zsh Scripts/build-app.sh && codesign --verify --deep --strict MontaMac.app`

Expected: the local app builds, Sparkle is embedded, and updater configuration reports unavailable without environment keys.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Package.resolved Sources/MontaMacCore/UpdateConfiguration.swift Sources/MontaMac/UpdateController.swift Sources/MontaMac/MontaMacApp.swift Sources/MontaMac/SettingsView.swift Resources/Info.plist Resources/MontaMac.local.entitlements Scripts/build-app.sh Tests/MontaMacCoreTests
git commit -m "feat: add securely gated automatic updates"
```

### Task 9: Signed and Notarized GitHub Release Pipeline

**Files:**
- Create: `.github/workflows/release.yml`
- Create: `docs/RELEASING.md`
- Modify: `.github/workflows/ci.yml`
- Modify: `Scripts/build-pkg.sh`
- Modify: `SECURITY.md`
- Modify: `README.md`
- Modify: `Tests/MontaMacCoreTests/ReleaseHardeningTests.swift`

**Interfaces:**
- Consumes: Apple Developer ID identities, notary credentials, Sparkle EdDSA private key, tag `v2.2.0`, and update metadata.
- Produces: signed/stapled app archive, signed package, SHA-256 file, signed appcast, and GitHub release assets.

- [ ] **Step 1: Extend failing hardening tests**

Require the release workflow to contain these exact secret names and verification commands:

```swift
let requiredSecrets = [
    "APPLE_APPLICATION_P12_BASE64", "APPLE_APPLICATION_P12_PASSWORD",
    "APPLE_INSTALLER_P12_BASE64", "APPLE_INSTALLER_P12_PASSWORD",
    "APPLE_ID", "APPLE_TEAM_ID", "APPLE_APP_SPECIFIC_PASSWORD",
    "SPARKLE_PRIVATE_KEY", "SPARKLE_PUBLIC_KEY",
]
```

Require `codesign --verify --deep --strict`, `xcrun notarytool submit --wait`, `xcrun stapler validate`, `pkgutil --check-signature`, `shasum -a 256`, and `sign_update --ed-key-file`.

- [ ] **Step 2: Run hardening tests and verify failure**

Run: `swift test --filter ReleaseHardeningTests`

Expected: tests fail because the release workflow is absent and metadata is still 2.1.1.

- [ ] **Step 3: Make packaging version-driven and fail closed**

Read version from the built app plist instead of duplicating it in `build-pkg.sh`. When `MONTAMAC_PRODUCTION_RELEASE=1`, require both application and installer identities plus update metadata. Local builds retain ad-hoc signing and print `LOCAL NON-PRODUCTION BUILD`.

- [ ] **Step 4: Implement tag-triggered release workflow**

Use `macos-15`, `permissions: contents: write`, and a `v*` tag trigger. The workflow must:

- validate all required secrets before building;
- import P12 files into a temporary Keychain;
- build with feed URL and public key environment variables;
- sign nested Sparkle components and the app with Developer ID Application;
- zip, notarize, staple, and validate the app;
- build and sign the package with Developer ID Installer;
- create an app archive for Sparkle and sign it using `sign_update --ed-key-file`;
- generate `appcast.xml` containing version 2.2.0, build 6, HTTPS asset URL, size, and EdDSA signature;
- upload app archive, package, checksum, appcast, and release notes through `gh release create`.

- [ ] **Step 5: Document release credentials and rotation**

Document how to produce each P12, create the app-specific password, generate/export the Sparkle key, configure GitHub secrets, rotate keys without removing the previous public key prematurely, run a dry build, and verify Gatekeeper on a second Mac.

- [ ] **Step 6: Validate YAML, hardening tests, and local package**

Run:

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml")'
swift test --filter ReleaseHardeningTests
zsh Scripts/build-pkg.sh
EXPANDED_DIR="$(mktemp -d /private/tmp/montamac-220-expanded.XXXXXX)"
pkgutil --expand-full dist/MontaMac-2.2.0.pkg "$EXPANDED_DIR"
```

Expected: YAML parses, tests pass, and the local non-production package contains MontaMac 2.2.0 build 6 with Sparkle embedded.

- [ ] **Step 7: Commit**

```bash
git add .github/workflows docs/RELEASING.md Scripts/build-pkg.sh SECURITY.md README.md Tests/MontaMacCoreTests/ReleaseHardeningTests.swift
git commit -m "build: add signed release pipeline"
```

### Task 10: Version, Migration, Final Integration, Installation, and Publication

**Files:**
- Modify: `Resources/Info.plist`
- Modify: `CHANGELOG.md`
- Modify: `ROADMAP.md`
- Create: `docs/releases/v2.2.0.md`
- Modify: `Tests/MontaMacCoreTests/ReleaseHardeningTests.swift`
- Modify: any test fixture that explicitly expects 2.1.1 build 5.

**Interfaces:**
- Consumes: all prior tasks.
- Produces: verified MontaMac 2.2.0 build 6, local installer, installed application, GitHub branch, and ready pull request.

- [ ] **Step 1: Write the failing release-metadata expectation**

```swift
func testReleaseMetadataIsVersion220() throws {
    XCTAssertEqual(try plistValue("CFBundleShortVersionString"), "2.2.0")
    XCTAssertEqual(try plistValue("CFBundleVersion"), "6")
    XCTAssertTrue(try buildPackageScript().contains("MontaMac-2.2.0.pkg"))
}
```

- [ ] **Step 2: Run the release test and verify failure**

Run: `swift test --filter ReleaseHardeningTests`

Expected: failure showing 2.1.1 and build 5.

- [ ] **Step 3: Update version and release documentation**

Set plist version 2.2.0 and build 6. Document all five feature groups, compatibility, non-production local signing, credential requirements, and safe rollback to 2.1.1 without deleting profiles or Keychain entries.

- [ ] **Step 4: Run the complete verification suite**

Run:

```bash
swift test
zsh Scripts/build-app.sh
zsh Scripts/build-pkg.sh
codesign --verify --deep --strict MontaMac.app
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' MontaMac.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' MontaMac.app/Contents/Info.plist
shasum -a 256 dist/MontaMac-2.2.0.pkg
git diff --check
```

Expected: all tests pass, version is 2.2.0 build 6, signatures validate, checksum is produced, and no whitespace errors exist.

- [ ] **Step 5: Run security and privacy checks**

Scan tracked files for private keys, GitHub tokens, Apple credentials, passwords, absolute user paths, and generated rclone configurations. Verify no active filenames are present in issue or activity fixtures. Confirm `git status` contains only intended source changes.

- [ ] **Step 6: Install and launch the exact verified application**

Terminate every stale MontaMac process, install the newly built app into `/Applications/MontaMac.app`, launch that exact bundle, and verify process path, version, build, binary checksum, dependency status, and a native UI smoke check. Do not claim production notarization in the local build.

- [ ] **Step 7: Commit final release metadata**

```bash
git add Resources/Info.plist CHANGELOG.md ROADMAP.md docs/releases/v2.2.0.md Tests/MontaMacCoreTests
git commit -m "feat: prepare MontaMac 2.2.0"
```

- [ ] **Step 8: Review, publish branch, and open ready PR**

Review `main...HEAD`, rerun the complete suite after any review fix, push `agent/montamac-2-2`, open a ready pull request targeting `main`, and monitor GitHub Actions until completion. Do not merge without explicit user authorization.

## Plan Self-Review

- Spec coverage: all five approved capabilities, compatibility, security, UI, localization, release gating, testing, installation, and publication map to Tasks 1-10.
- Type consistency: recovery flows into coordinator; settings resolve cache policy; JSON telemetry feeds coordinator and Transfer Center; Issue Center receives user-impacting errors; Sparkle reads injected build metadata.
- Scope: each task ends in an independently testable commit while producing one coherent 2.2.0 release.
- External limitation: real notarization and live Sparkle installation remain unverified until valid Apple and Sparkle credentials are provided.
