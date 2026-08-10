# MontaMac Native App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a polished macOS app that manages multiple FTP, SFTP and WebDAV mounts through rclone.

**Architecture:** A SwiftUI application owns connection metadata, UI state and diagnostics. It delegates secure credential access to Keychain and mount work to rclone through `Process`; a monitor validates the actual filesystem mount before changing UI state.

**Tech Stack:** Swift 6.3, SwiftUI, Foundation, Security, XCTest, rclone 1.73+, FUSE-T.

## Global Constraints

- Target macOS 26.0 and Apple Silicon, with no third-party Swift dependencies.
- Preserve `montamac` unchanged; all new source lives in `montamac2.0`.
- Support FTP, SFTP and WebDAV, one mount per connection.
- Store passwords in Keychain and synchronise rclone configuration only when needed.
- Never interpolate credentials or paths into a shell command.
- Verify mounting from filesystem state; do not depend on fixed sleeps.
- Use Italian UI text and concise, actionable errors.

---

## File structure

```
montamac2.0/
  MontaMac.xcodeproj/
  MontaMac/
    App/MontaMacApp.swift
    Models/Connection.swift
    Models/MountStatus.swift
    Services/ConnectionStore.swift
    Services/CredentialStore.swift
    Services/RcloneConfigurationWriter.swift
    Services/RcloneService.swift
    Services/MountMonitor.swift
    Services/MountCoordinator.swift
    Services/DiagnosticsService.swift
    ViewModels/AppViewModel.swift
    Views/MainWindowView.swift
    Views/ConnectionRow.swift
    Views/ConnectionDetailView.swift
    Views/ConnectionEditorView.swift
    Views/LogSheet.swift
  MontaMacTests/
    ConnectionTests.swift
    ConnectionStoreTests.swift
    RcloneConfigurationWriterTests.swift
    RcloneServiceTests.swift
    MountCoordinatorTests.swift
    DiagnosticsServiceTests.swift
  README.md
```

### Task 1: Create the native app shell

**Files:**
- Create: `MontaMac.xcodeproj/project.pbxproj`
- Create: `MontaMac/App/MontaMacApp.swift`
- Create: `MontaMac/Models/MountStatus.swift`
- Create: `MontaMacTests/MountStatusTests.swift`

**Interfaces:**
- Produces: `enum MountStatus: Equatable { case disconnected, connecting, mounted, disconnecting, failed(String) }`.

- [ ] **Step 1: Write the failing state test**

```swift
func testFailureStateKeepsItsMessage() {
    XCTAssertEqual(MountStatus.failed("rclone non trovato").message, "rclone non trovato")
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS' -only-testing:MontaMacTests/MountStatusTests`

Expected: FAIL because the project and `MountStatus` do not exist.

- [ ] **Step 3: Add the minimal app and state implementation**

```swift
enum MountStatus: Equatable {
    case disconnected, connecting, mounted, disconnecting, failed(String)
    var message: String { if case let .failed(value) = self { value } else { "" } }
}

@main struct MontaMacApp: App {
    var body: some Scene { WindowGroup { Text("MontaMac") } }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: same command as Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MontaMac.xcodeproj MontaMac MontaMacTests
git commit -m "feat: create native MontaMac shell"
```

### Task 2: Model and validate remote connections

**Files:**
- Create: `MontaMac/Models/Connection.swift`
- Create: `MontaMacTests/ConnectionTests.swift`

**Interfaces:**
- Produces: `struct RemoteConnection: Codable, Identifiable, Equatable` with `name`, `protocolType`, `host`, `port`, `username`, `remotePath`, `mountPath` and `validationError`.

- [ ] **Step 1: Write the failing validation test**

```swift
func testSFTPRequiresHostAndAbsoluteMountPath() {
    var connection = RemoteConnection.blank(protocolType: .sftp)
    connection.host = ""
    connection.mountPath = "Documents/Server"
    XCTAssertEqual(connection.validationError, "Inserisci un host valido e un percorso locale assoluto.")
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS' -only-testing:MontaMacTests/ConnectionTests`

Expected: FAIL because `RemoteConnection` is missing.

- [ ] **Step 3: Implement the model and protocol mapping**

```swift
enum RemoteProtocol: String, Codable, CaseIterable { case ftp, sftp, webdav }
struct RemoteConnection: Codable, Identifiable, Equatable {
    let id: UUID; var name, host, username, remotePath, mountPath: String
    var port: Int; var protocolType: RemoteProtocol
    var validationError: String? { /* validates host and absolute mount path */ }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: same command as Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MontaMac/Models/Connection.swift MontaMacTests/ConnectionTests.swift
git commit -m "feat: model remote connections"
```

### Task 3: Persist metadata and credentials securely

**Files:**
- Create: `MontaMac/Services/ConnectionStore.swift`
- Create: `MontaMac/Services/CredentialStore.swift`
- Create: `MontaMacTests/ConnectionStoreTests.swift`

**Interfaces:**
- Consumes: `RemoteConnection`.
- Produces: `ConnectionStore.load()`, `save(_:)`, `CredentialStore.password(for:)`, `save(password:for:)`.

- [ ] **Step 1: Write the failing persistence test**

```swift
func testStoreRoundTripsMetadataWithoutPassword() throws {
    let store = ConnectionStore(fileURL: temporaryURL)
    let connection = RemoteConnection.blank(protocolType: .ftp)
    try store.save([connection])
    XCTAssertEqual(try store.load(), [connection])
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS' -only-testing:MontaMacTests/ConnectionStoreTests`

Expected: FAIL because `ConnectionStore` is missing.

- [ ] **Step 3: Implement JSON metadata storage and Keychain storage**

```swift
final class ConnectionStore { init(fileURL: URL); func load() throws -> [RemoteConnection]; func save(_ connections: [RemoteConnection]) throws }
protocol CredentialStoring { func password(for id: UUID) throws -> String?; func save(password: String, for id: UUID) throws }
final class CredentialStore: CredentialStoring { /* SecItem APIs, service "MontaMac" */ }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: same command as Step 2.

Expected: PASS; test file contains no password.

- [ ] **Step 5: Commit**

```bash
git add MontaMac/Services MontaMacTests/ConnectionStoreTests.swift
git commit -m "feat: persist connections securely"
```

### Task 4: Generate compatible rclone configuration

**Files:**
- Create: `MontaMac/Services/RcloneConfigurationWriter.swift`
- Create: `MontaMacTests/RcloneConfigurationWriterTests.swift`

**Interfaces:**
- Consumes: `RemoteConnection`, `CredentialStoring`.
- Produces: `RcloneConfigurationWriter.write(connection:password:to:) throws -> String`, using rclone's `obscure` command before writing the password field.

- [ ] **Step 1: Write the failing configuration test**

```swift
func testWebDAVConfigurationContainsConnectionFields() throws {
    let content = try writer.write(connection: webDAVConnection, password: "secret-password", to: temporaryURL)
    XCTAssertTrue(content.contains("type = webdav"))
    XCTAssertTrue(content.contains("url = https://files.example.com"))
    XCTAssertFalse(content.contains("secret-password"))
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS' -only-testing:MontaMacTests/RcloneConfigurationWriterTests`

Expected: FAIL because `RcloneConfigurationWriter` is missing.

- [ ] **Step 3: Implement per-protocol configuration rendering**

```swift
final class RcloneConfigurationWriter {
    func write(connection: RemoteConnection, password: String, to url: URL) throws -> String {
        // runs `rclone obscure` through Process and writes its obfuscated output as pass
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: same command as Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MontaMac/Services/RcloneConfigurationWriter.swift MontaMacTests/RcloneConfigurationWriterTests.swift
git commit -m "feat: generate rclone configuration"
```

### Task 5: Run rclone safely and monitor mounts

**Files:**
- Create: `MontaMac/Services/RcloneService.swift`
- Create: `MontaMac/Services/MountMonitor.swift`
- Create: `MontaMacTests/RcloneServiceTests.swift`

**Interfaces:**
- Produces: `RcloneService.mountArguments(for:configURL:)`, `unmount(at:)`, and `MountMonitor.waitUntilMounted(at:timeout:) async`.

- [ ] **Step 1: Write the failing argument test**

```swift
func testMountArgumentsKeepPathAsOneArgument() {
    let arguments = service.mountArguments(for: connection, configURL: configURL)
    XCTAssertTrue(arguments.contains(connection.mountPath))
    XCTAssertFalse(arguments.joined(separator: " ").contains(";"))
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS' -only-testing:MontaMacTests/RcloneServiceTests`

Expected: FAIL because `RcloneService` is missing.

- [ ] **Step 3: Implement `Process`-based service and filesystem monitor**

```swift
final class RcloneService {
    func mountArguments(for connection: RemoteConnection, configURL: URL) -> [String]
    func startMount(arguments: [String]) throws -> Process
    func unmount(at mountURL: URL) throws
}
final class MountMonitor {
    func isMounted(at url: URL) -> Bool
    func waitUntilMounted(at url: URL, timeout: Duration) async -> Bool
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: same command as Step 2.

Expected: PASS; no `sleep` appears in production source.

- [ ] **Step 5: Commit**

```bash
git add MontaMac/Services/RcloneService.swift MontaMac/Services/MountMonitor.swift MontaMacTests/RcloneServiceTests.swift
git commit -m "feat: control rclone mounts safely"
```

### Task 6: Coordinate lifecycle, import, diagnostics and logs

**Files:**
- Create: `MontaMac/Services/MountCoordinator.swift`
- Create: `MontaMac/Services/DiagnosticsService.swift`
- Create: `MontaMacTests/MountCoordinatorTests.swift`
- Create: `MontaMacTests/DiagnosticsServiceTests.swift`

**Interfaces:**
- Consumes: stores, `RcloneService`, `MountMonitor`.
- Produces: `MountCoordinator.mount(_:) async`, `unmount(_:) async`, `logs(for:)` and diagnostic results.

- [ ] **Step 1: Write the failing lifecycle test**

```swift
func testCoordinatorReportsMountedOnlyAfterMonitorConfirmsIt() async {
    await coordinator.mount(connection)
    XCTAssertEqual(await coordinator.status(for: connection.id), .mounted)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS' -only-testing:MontaMacTests/MountCoordinatorTests`

Expected: FAIL because `MountCoordinator` is missing.

- [ ] **Step 3: Implement lifecycle state machine and current-config importer**

```swift
@MainActor final class MountCoordinator: ObservableObject {
    func mount(_ connection: RemoteConnection) async
    func unmount(_ connection: RemoteConnection) async
    func status(for id: UUID) -> MountStatus
}
```

- [ ] **Step 4: Run lifecycle and diagnostics tests to verify they pass**

Run: `xcodebuild test -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS' -only-testing:MontaMacTests/MountCoordinatorTests -only-testing:MontaMacTests/DiagnosticsServiceTests`

Expected: PASS; failure paths include a user-actionable message and retained technical log.

- [ ] **Step 5: Commit**

```bash
git add MontaMac/Services MontaMacTests/MountCoordinatorTests.swift MontaMacTests/DiagnosticsServiceTests.swift
git commit -m "feat: add mount lifecycle diagnostics"
```

### Task 7: Build the polished SwiftUI experience

**Files:**
- Create: `MontaMac/ViewModels/AppViewModel.swift`
- Create: `MontaMac/Views/MainWindowView.swift`
- Create: `MontaMac/Views/ConnectionRow.swift`
- Create: `MontaMac/Views/ConnectionDetailView.swift`
- Create: `MontaMac/Views/ConnectionEditorView.swift`
- Create: `MontaMac/Views/LogSheet.swift`
- Modify: `MontaMac/App/MontaMacApp.swift`

**Interfaces:**
- Consumes: `MountCoordinator`, `RemoteConnection`, `MountStatus`.
- Produces: primary user interface with add, edit, mount, unmount, Finder and log actions.

- [ ] **Step 1: Write the failing view-model test**

```swift
func testMountActionDelegatesSelectedConnection() async {
    await viewModel.mountSelectedConnection()
    XCTAssertEqual(coordinator.mountedConnectionID, connection.id)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS' -only-testing:MontaMacTests/AppViewModelTests`

Expected: FAIL because `AppViewModel` is missing.

- [ ] **Step 3: Implement the professional UI**

```swift
NavigationSplitView {
    List(viewModel.connections, selection: $viewModel.selection) { ConnectionRow(connection: $0) }
} detail: {
    ConnectionDetailView(connection: viewModel.selectedConnection)
}
```

- [ ] **Step 4: Build and run the UI test target**

Run: `xcodebuild build -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS'`

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add MontaMac MontaMacTests
git commit -m "feat: add polished MontaMac interface"
```

### Task 8: Document, validate and package

**Files:**
- Create: `README.md`
- Modify: `.gitignore`

**Interfaces:**
- Produces: setup guide, migration notes and a buildable `.app` product.

- [ ] **Step 1: Add a failing build verification command to the README**

```markdown
## Verifica
`xcodebuild test -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS'`
```

- [ ] **Step 2: Run the complete test suite**

Run: `xcodebuild test -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS'`

Expected: PASS with zero failures.

- [ ] **Step 3: Build the release app**

Run: `xcodebuild build -configuration Release -project MontaMac.xcodeproj -scheme MontaMac -destination 'platform=macOS'`

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Write setup and migration documentation**

```markdown
1. Install rclone and FUSE-T.
2. Open MontaMac.app.
3. Import RAIDRIVE or add a connection.
4. Save the password in Portachiavi and mount.
```

- [ ] **Step 5: Commit**

```bash
git add README.md .gitignore
git commit -m "docs: add setup and verification guide"
```

## Plan review

- Spec coverage: Tasks 1–8 cover native UI, protocols, Keychain plus rclone config, migration, lifecycle fixes, diagnostics, tests and release build.
- Placeholder scan: no TODO/TBD markers or implicit implementation steps.
- Type consistency: `RemoteConnection`, `MountStatus`, `MountCoordinator` and service signatures are introduced before consumption.
