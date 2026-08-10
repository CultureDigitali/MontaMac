# MontaMac Insights and Brand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a full MontaMac dashboard, safe drive statistics and an original macOS brand asset set.

**Architecture:** Core services record non-sensitive events locally and obtain remote statistics only on demand through rclone. SwiftUI consumes the aggregate view model for dashboard cards, activity and per-drive health; generated artwork is packaged as an app asset.

**Tech Stack:** Swift 6.3, SwiftUI, Foundation, XCTest, rclone, Image Generation.

## Global Constraints

- Preserve existing credentials and temporary rclone-config protections.
- Do not scan remotes continuously; manual refresh only.
- Keep historical data non-sensitive and local to Application Support.
- Use Italian UI copy and the approved blue/electric-green identity.
- Build and test before recreating `MontaMac.app`.

---

### Task 1: Event model and activity persistence

**Files:**
- Create: `Sources/MontaMacCore/ActivityStore.swift`
- Create: `Tests/MontaMacCoreTests/ActivityStoreTests.swift`

**Interfaces:**
- Produces: `ActivityEvent`, `ActivityStore.record(_:)`, `recentEvents(limit:)`, `summary(since:)`.

- [ ] **Step 1: Write the failing aggregation test**

```swift
func testSummaryCountsTransferredBytesAndFailures() throws {
    try store.record(.transfer(connectionID: id, bytes: 2048, at: date))
    try store.record(.failure(connectionID: id, message: "offline", at: date))
    XCTAssertEqual(try store.summary(since: date.addingTimeInterval(-1)).transferredBytes, 2048)
    XCTAssertEqual(try store.summary(since: date.addingTimeInterval(-1)).failureCount, 1)
}
```

- [ ] **Step 2: Run test and verify it fails**

Run: `swift test --filter ActivityStoreTests`

Expected: FAIL because `ActivityStore` is missing.

- [ ] **Step 3: Implement JSON-backed events**

```swift
public struct ActivitySummary: Sendable { public var transferredBytes: Int64; public var failureCount: Int; public var mountedSeconds: TimeInterval }
public final class ActivityStore { public func record(_ event: ActivityEvent) throws; public func summary(since: Date) throws -> ActivitySummary }
```

- [ ] **Step 4: Run test and verify it passes**

Run: `swift test --filter ActivityStoreTests`

Expected: PASS.

### Task 2: On-demand remote metrics and health checks

**Files:**
- Create: `Sources/MontaMacCore/RemoteStatisticsService.swift`
- Modify: `Sources/MontaMacCore/DiagnosticsService.swift`
- Create: `Tests/MontaMacCoreTests/RemoteStatisticsServiceTests.swift`

**Interfaces:**
- Consumes: `RemoteConnection`, `RcloneService`.
- Produces: `RemoteStatistics`, `RemoteStatisticsService.parseSizeOutput(_:)`, `HealthCheckService.inspect(_:)`.

- [ ] **Step 1: Write the failing parser test**

```swift
func testSizeParserExtractsBytesAndFileCount() throws {
    let stats = try RemoteStatisticsService.parseSizeOutput("Total objects: 42\nTotal size: 1.500 GiB\n")
    XCTAssertEqual(stats.fileCount, 42)
    XCTAssertEqual(stats.totalBytes, 1_610_612_736)
}
```

- [ ] **Step 2: Run test and verify it fails**

Run: `swift test --filter RemoteStatisticsServiceTests`

Expected: FAIL because `RemoteStatisticsService` is missing.

- [ ] **Step 3: Implement explicit-refresh rclone metrics**

```swift
public struct RemoteStatistics: Sendable { public var fileCount: Int; public var totalBytes: Int64; public var scannedAt: Date }
public final class RemoteStatisticsService { public func refresh(_ connection: RemoteConnection) async throws -> RemoteStatistics }
```

- [ ] **Step 4: Run test and verify it passes**

Run: `swift test --filter RemoteStatisticsServiceTests`

Expected: PASS.

### Task 3: Dashboard and per-drive insights UI

**Files:**
- Create: `Sources/MontaMac/DashboardView.swift`
- Create: `Sources/MontaMac/DriveInsightsView.swift`
- Modify: `Sources/MontaMac/AppViewModel.swift`
- Modify: `Sources/MontaMac/MainWindowView.swift`

**Interfaces:**
- Consumes: `ActivitySummary`, `RemoteStatistics`, `HealthCheckService`.
- Produces: `AppViewModel.dashboardSummary`, `refreshStatistics()`, dashboard sidebar selection.

- [ ] **Step 1: Write the failing view-model test**

```swift
func testDashboardShowsStoredFailureCount() throws {
    try activityStore.record(.failure(connectionID: id, message: "offline", at: .now))
    XCTAssertEqual(try viewModel.dashboardSummary().failureCount, 1)
}
```

- [ ] **Step 2: Run test and verify it fails**

Run: `swift test --filter DashboardViewModelTests`

Expected: FAIL because `dashboardSummary()` is missing.

- [ ] **Step 3: Implement cards, chart, timeline and refresh flow**

```swift
struct DashboardView: View { let summary: ActivitySummary; let events: [ActivityEvent] }
struct DriveInsightsView: View { let connection: RemoteConnection; let statistics: RemoteStatistics? }
```

- [ ] **Step 4: Build and run all tests**

Run: `swift test && swift build -c release`

Expected: PASS and `Build complete!`.

### Task 4: Official logo, iconset and app packaging

**Files:**
- Create: `Assets/MontaMac-logo.png`
- Create: `Assets/AppIcon.iconset/`
- Modify: `Resources/Info.plist`
- Modify: `Scripts/build-app.sh`

**Interfaces:**
- Produces: application icon plus dashboard/status asset references.

- [ ] **Step 1: Generate the approved original logo asset**

Prompt: `Original macOS utility logo: geometric M monogram embracing a compact remote-drive shape, electric blue and aqua green, clean premium vector-like 3D, no text, no watermark, flat solid #ff00ff chroma-key background, centered with generous padding.`

- [ ] **Step 2: Remove chroma background and create icon dimensions**

Run the image-generation chroma-key helper, then create 16, 32, 64, 128, 256, 512 and 1024-pixel PNG variants in the iconset.

- [ ] **Step 3: Package icon into the macOS bundle**

```xml
<key>CFBundleIconFile</key><string>AppIcon</string>
```

- [ ] **Step 4: Rebuild and verify the bundle**

Run: `zsh Scripts/build-app.sh && plutil -lint MontaMac.app/Contents/Info.plist`

Expected: app bundle and valid plist.

## Plan review

- Spec coverage: Tasks 1–4 deliver event history, aggregated statistics, safe remote refresh, health checks, dashboard, drive detail, notifications-ready event data and original brand assets.
- Placeholder scan: no unfinished requirements.
- Type consistency: the dashboard consumes `ActivitySummary` and `RemoteStatistics` produced by the earlier core tasks.
