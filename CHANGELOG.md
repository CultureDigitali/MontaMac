# Changelog

All notable changes to MontaMac are documented here.

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
