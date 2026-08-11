# Changelog

All notable changes to MontaMac are documented here.

## [2.2.0] - 2026-08-11

### Added

- Bounded automatic reconnection with live health checks and manual cancellation.
- Localized issue center with redacted diagnostic export.
- Configurable global and per-profile VFS cache limits with reserved disk space.
- Safe cache manager showing total, per-profile, and available disk space.
- Live transfer center with structured rclone JSON telemetry, speed, progress, ETA, and current file.
- Signed Sparkle update support and a fail-closed GitHub release workflow for Developer ID signing, notarization, stapling, checksums, and appcast generation.

### Fixed

- Release builds now compile current source before packaging instead of reusing a stale binary.
- Sidebar and profile status now refresh immediately when mount state changes.
- Transfer metrics no longer depend on human-formatted rclone output.

### Security

- Update feeds require HTTPS and a matching EdDSA public key.
- Cache deletion is restricted to the exact UUID profile directory and blocked while the drive is active.
- Diagnostic exports redact host, username, paths, and known secrets.

## [2.1.1] - 2026-08-10

### Fixed

- Dashboard transfer bytes now follow live rclone statistics instead of remaining at zero.
- Consecutive transfer updates are compacted to keep the activity store bounded.

### Added

- Live local VFS cache disk-usage indicator.
- Adaptive dashboard metric grid and creator credits footer.
- Automatic dashboard refresh in all four supported languages.

## [2.1.0] - 2026-08-10

### Added

- Native profile manager with favorites, groups and search.
- Activity dashboard, statistics, diagnostics and Finder integration.
- Italian, English, French and Spanish interface.
- Guided rclone and FUSE-T requirement checks.
- Official credits for Luigi Strazzullo and Culture Digitali Srl.

### Security

- Private permissions for application data, rclone configuration and caches.
- Keychain-only password storage with explicit accessibility policy.
- UUID-based internal rclone identifiers and protected mount paths.
- Redacted and bounded runtime logs.
- Cleanup of credentials and temporary artifacts when deleting profiles.
- HTTPS/TLS hardening for requirement downloads.

### Known limitations

- FTP traffic is not encrypted.
- The public package is not Apple notarized and may trigger Gatekeeper.
