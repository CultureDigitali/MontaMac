# MontaMac 2.2 Reliability and Operations Design

Date: 2026-08-11
Status: Approved design
Target: MontaMac 2.2.0, build 6

## Objective

Turn MontaMac into a more resilient daily-use remote-drive utility without replacing its existing SwiftUI, rclone, Keychain, profile, localization, or packaging foundations.

The release delivers five connected capabilities:

1. mount health monitoring and bounded automatic recovery;
2. visible, recoverable, localized error handling;
3. safe per-profile cache controls;
4. live per-profile transfer telemetry;
5. signed, notarized, automatic-update infrastructure that activates only when release credentials exist.

Existing profiles and passwords must continue to work without manual migration. The original `montamac` directory remains untouched.

## Chosen Approach

Use an incremental modular evolution of the current application. New behavior lives in small services with injected dependencies and observable state. `MountCoordinator` remains the single mount authority, while `AppViewModel` coordinates UI state instead of owning operating-system details.

Rejected approaches:

- adding all behavior directly to `AppViewModel` and `MountCoordinator`, because it would make process lifecycle, retries, telemetry, and errors difficult to test;
- rewriting the application, because the current profile, Keychain, localization, security, and packaging behavior is already proven.

## Scope and Delivery Order

The work is one release implemented in five internally reviewable phases:

1. reliability foundation;
2. issue handling and complete runtime localization;
3. cache policy and cleanup;
4. transfer telemetry and interface;
5. update and release pipeline.

Each phase receives focused tests before the full suite runs. No phase may weaken credential storage, mount-path validation, log redaction, or temporary configuration cleanup.

## 1. Mount Reliability

### Components

`MountSession` represents one active or recovering profile. It records the process, intended state, retry count, last healthy time, configuration URL, and whether termination was requested by the user.

`MountRecoveryPolicy` returns bounded retry delays. The default sequence is 2, 5, and 15 seconds, with at most three automatic retries per unexpected interruption. A successful stable mount resets the counter.

`MountHealthMonitor` periodically verifies both conditions:

- the rclone process is still running;
- the configured path still appears in the system mount table.

`MountCoordinator` owns these components and publishes richer statuses: connecting, mounted, reconnecting with attempt number, disconnecting, disconnected, and failed.

### Lifecycle

Every rclone process receives a termination handler. Unexpected termination or loss of the real mount begins recovery only when the connection was previously intended to remain mounted. Manual unmount, profile deletion, application shutdown, or validation failure cancels pending retries.

Before retrying, MontaMac terminates any stale process, removes the exact temporary configuration, verifies requirements, creates a new protected configuration, and checks that the mount is real. A new attempt never runs beside an existing process for the same profile.

After the third failure the profile remains failed, displays the last redacted reason, and offers a manual retry. Automatic retries are non-blocking and never request administrator access.

## 2. Issues, Recovery, and Localization

### Issue model

`AppIssue` contains:

- stable identifier;
- optional profile identifier;
- localized message key and safe interpolation values;
- severity: information, warning, or error;
- timestamp;
- optional recovery action such as retry, open requirements, or open diagnostics.

`IssueCenter` keeps the latest 100 issues in protected application storage. It publishes a short-lived non-modal banner and supplies a dedicated history view. Duplicate repeating health errors are coalesced.

### Error policy

User-impacting operations may not silently discard errors. This includes profile persistence, Keychain changes, activity writes, mount configuration, cache cleanup, and update checks. Expected best-effort filesystem metadata reads may remain non-fatal, but they must not make a successful destructive action appear complete when it failed.

Diagnostic export creates a timestamped text file chosen through the macOS save panel. It includes versions, dependency state, mount status, and redacted recent logs. It excludes passwords, obscured passwords, temporary rclone configuration contents, access tokens, and full remote URLs containing credentials.

### Complete localization

All runtime messages use stable localization keys resolved through the selected app language. SwiftUI labels continue using localized resources. Core errors expose codes and safe arguments instead of preformatted Italian text. Italian, English, French, and Spanish must contain identical key sets.

## 3. Cache Management

### Policy

`CachePolicy` is stored in app settings with an optional per-profile override. Available limits are 1, 5, 10, and 25 GB or unlimited. The default is 5 GB per profile. MontaMac also reserves at least 5 GB of free disk space by passing supported rclone VFS flags.

Each mount receives:

- `--vfs-cache-max-size` for the selected profile limit;
- `--vfs-cache-min-free-space 5G`;
- `--vfs-cache-poll-interval 1m`;
- the existing maximum-age policy.

The interface explains that open files may temporarily exceed the configured limit because rclone cannot evict them safely.

### Measurement and cleanup

`CacheUsageService` reports total usage and usage per profile away from the main actor. Scans are cancellable and do not follow symbolic links.

The Cache section shows total usage, disk free space, each profile's usage, selected limit, and last refresh. Cleanup is enabled only for a disconnected profile. The deletion target must resolve to the profile UUID directory directly below MontaMac's cache root. Cleanup never removes mount folders or remote files.

Automatic cleanup is delegated to rclone limits. MontaMac does not delete an active cache behind rclone.

## 4. Transfer Center

### Structured telemetry

rclone runs with JSON logging and periodic statistics. `RcloneJSONLogParser` incrementally buffers process output by line and decodes only complete JSON records. Stats records provide total bytes, total size, speed, ETA, error state, and active transfers including file name, bytes, size, percentage, and speed.

`TransferSnapshot` contains current session-level values and an array of `ActiveTransfer` values. The existing transferred-byte tracker continues persisting positive byte deltas for dashboard history.

Live file names remain in memory only and pass through the sensitive-data redactor before display. They are never written to `activity.json` or diagnostic exports.

Malformed or non-JSON rclone output remains available as a redacted log entry and cannot crash or reset a valid snapshot.

### Interface

The sidebar gains a `Transfers` destination. It presents:

- aggregate current speed and active-transfer count;
- one card per mounted profile;
- progress, speed, and ETA when rclone supplies a known total;
- the active file name when available;
- an explicit idle state when mounted with no current transfer.

Profile rows gain a compact activity indicator. The dashboard keeps its cumulative 30-day metric and adds current aggregate speed without duplicating the detailed view.

## 5. Updates and Release Security

### Application behavior

Sparkle 2 provides update checks and verified installation. Settings adds an automatic-update toggle and a `Check for Updates` action.

Update installation is available only when the built app contains both a feed URL and a Sparkle EdDSA public key. Local ad-hoc builds without release configuration clearly report that secure automatic updates are unavailable and never download or execute an unverified package.

The build script injects update metadata only from explicit environment variables. No private signing material enters the application bundle or repository.

### GitHub release pipeline

A tag-triggered GitHub Actions workflow will:

1. run the complete test suite;
2. build the release application;
3. sign it with Developer ID Application when the configured secrets exist;
4. notarize and staple the application;
5. build and sign the installer with Developer ID Installer;
6. generate a SHA-256 checksum and signed Sparkle appcast;
7. verify signatures, notarization, package contents, and versions;
8. publish GitHub release assets.

Required Apple and Sparkle secrets are documented by name and purpose. The workflow fails closed when a release tag requests production distribution without them. Pull-request and local builds continue with ad-hoc signing and cannot masquerade as production releases.

The existing GitHub release 2.1.0 is not modified during implementation. MontaMac 2.2.0 becomes the next published release only after all checks pass and credentials are available.

## Settings and Navigation

Settings gains three grouped sections:

- Reliability: automatic reconnection toggle and retry summary;
- Cache: default limit and reserved free space;
- Updates: automatic checks, current channel, last check, and manual check.

The main navigation adds Transfers, Cache, and Issues using native SF Symbols and keyboard-accessible labels. New views preserve the sober native macOS visual language and adapt to the existing minimum window size.

## Data Compatibility

New Codable properties use explicit defaults when older JSON omits them. Existing connection IDs, profile groups, favorites, remote paths, mount paths, and Keychain items remain unchanged.

Issue history uses a new versioned file under the existing protected application-support directory. Cache, retry, and update preferences use the existing app-settings storage with safe defaults. Corrupt optional issue history must not prevent profile loading or mounting.

Live transfer state is ephemeral. Aggregate activity remains bounded to 500 events through the existing compaction behavior.

## Security Requirements

- Passwords remain in Keychain only.
- rclone is launched through `Process` with argument arrays and no shell interpolation.
- Temporary configuration permissions and cleanup remain enforced.
- All logs and exported diagnostics pass through redaction.
- Cache cleanup validates containment and refuses active profiles.
- Retry loops are bounded and cancellable.
- Update metadata and artifacts require cryptographic verification.
- Production release secrets exist only in GitHub Actions secrets or the developer Keychain.

## Testing Strategy

Unit tests cover:

- retry delay, limit, reset, cancellation, and manual-stop behavior;
- process termination and mount-loss transitions;
- fragmented, malformed, and valid rclone JSON statistics;
- telemetry byte deltas, speed, ETA, and active files;
- issue coalescing, persistence, redaction, and recovery actions;
- cache policy arguments, containment checks, cleanup refusal, and cancellable measurement;
- backward-compatible profile decoding;
- complete localization key parity;
- update configuration gating and version comparison;
- release metadata for 2.2.0 build 6.

Integration verification covers:

- the existing full Swift test suite plus new tests;
- release application and installer builds;
- app signature and package-content checks;
- dependency detection on the current Mac;
- launch of the exact installed bundle after terminating stale copies;
- a controlled local rclone transfer fixture validating live JSON telemetry;
- GitHub Actions validation without exposing secrets.

Production notarization and live automatic update installation cannot be claimed until valid Apple and Sparkle signing credentials are supplied and the published artifacts pass external verification.

## Acceptance Criteria

MontaMac 2.2.0 is ready for review when:

- unexpected rclone termination causes at most three visible, cancellable retries;
- manual unmount never reconnects;
- user-impacting failures appear in the localized Issue Center;
- all four languages have matching runtime and interface keys;
- cache limits affect rclone arguments and cleanup cannot target active or unrelated paths;
- Transfer Center displays structured live stats from fragmented JSON output;
- aggregate dashboard bytes remain correct across remounts;
- secure updates are enabled only in correctly configured signed builds;
- local unsigned builds remain usable and explicitly non-production;
- old profiles load without changes;
- all tests, build, package, installation, launch, and security checks pass.
