# Releasing MontaMac

Releases are created only by a `vX.Y.Z` tag matching `CFBundleShortVersionString`.

## Required GitHub secrets

- `APPLE_APPLICATION_P12_BASE64`
- `APPLE_APPLICATION_P12_PASSWORD`
- `APPLE_INSTALLER_P12_BASE64`
- `APPLE_INSTALLER_P12_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `SPARKLE_PRIVATE_KEY`
- `SPARKLE_PUBLIC_KEY`

Keep the Sparkle private key and Apple certificates out of the repository. Rotate a secret immediately if it appears in logs or commits.

## Release sequence

1. Update `Resources/Info.plist`, `CHANGELOG.md`, `ROADMAP.md`, and the release notes.
2. Run `swift test` and `zsh Scripts/build-pkg.sh` locally.
3. Merge the release branch after review.
4. Create and push the matching signed tag.
5. GitHub Actions signs, notarizes, staples, creates checksums and the Sparkle appcast, then publishes the release.

Production mode refuses to build when the signing identity, HTTPS feed, public Sparkle key, or installer identity is missing. Local builds remain ad-hoc signed and contain no update feed or key.
