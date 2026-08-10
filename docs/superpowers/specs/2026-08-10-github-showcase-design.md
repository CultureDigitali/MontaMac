# MontaMac GitHub Showcase Design

**Date:** 2026-08-10

**Status:** Approved direction
**Audience:** macOS users and open-source contributors

## Goal

Transform the MontaMac repository into a credible product showcase that improves discovery, communicates value quickly, converts visitors into users and contributors, and encourages organic stars without misleading claims or artificial growth tactics.

## Positioning

MontaMac is presented as the native, open-source macOS app that mounts FTP, SFTP and WebDAV storage directly in Finder. The page leads with the user outcome—remote files behaving like a Mac drive—then provides the technical and security evidence developers expect.

The primary language is English for international reach. A concise Italian section covers the product promise, installation and support for the original audience.

## Repository Landing Page

The root README will use this order:

1. Branded hero with logo, concise promise and essential status badges.
2. Primary calls to action: download the latest release, read the quick start and star the project.
3. Real application screenshots showing the dashboard, profile manager and statistics.
4. User benefits and supported protocols.
5. A short comparison between MontaMac and manual command-line mounting.
6. Three-step installation and checksum verification.
7. Security and privacy guarantees, with a clear non-notarized-package notice.
8. Supported languages and platform requirements.
9. Roadmap, contribution path and support links.
10. Credits, license and concise Italian section.

The README will remain compact enough to scan. Detailed build, contribution and security material will live in dedicated documents linked from the landing page.

## Visual System

The existing MontaMac logo remains the official identity. A wide 1280x640 social preview will use a solid dark blue background, the drive-and-mount mark, a short product promise and subtle macOS-style depth. A matching README hero image will be optimized for GitHub light and dark themes.

Screenshots must come from the real installed application and contain no credentials, server addresses, local usernames or private mount paths. Demo profiles will use reserved `.example` domains and synthetic data.

Badges are limited to useful trust signals: latest release, macOS, Swift, license and tests. Decorative badge walls, inflated metrics and unverifiable claims are excluded.

## GitHub Discovery Metadata

The repository will receive:

- a keyword-rich description focused on macOS, Finder and remote drives;
- the Culture Digitali website as homepage;
- focused topics such as `macos`, `swift`, `swiftui`, `finder`, `sftp`, `ftp`, `webdav`, `rclone`, `fuse`, `remote-drive`, `file-manager` and `open-source`;
- a custom social preview;
- release and download links placed above the fold.

Topics remain below GitHub's limit and describe the actual project. The copy will naturally include search terms without keyword stuffing.

## Community and Trust

Add `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, issue forms for bugs and feature requests, a pull-request template and a concise roadmap. Existing `LICENSE` and `SECURITY.md` remain authoritative.

Issue templates must instruct users to remove credentials and private host information. Bug reports request macOS version, MontaMac version, protocol, reproduction steps and redacted logs. Pull requests require tests and confirmation that no sensitive data was added.

The community files should raise GitHub's community profile completeness and make participation safe and predictable.

## Content Accuracy

The showcase will not promise guaranteed stars, automatic compatibility with every server or Apple notarization. It will explicitly state that version 2.1.0 is not notarized. Download links point to the official GitHub release, and the published SHA-256 checksum remains visible.

Competitive language will compare workflows, not make unsupported claims about named products.

## Implementation Boundaries

This change updates repository presentation and metadata only. It does not alter mount behavior, credential handling or the application release binary. The public `v2.1.0` package remains unchanged.

## Verification

- Render-check Markdown links and images.
- Confirm all screenshots and documents contain only synthetic data.
- Run the existing secret scan and repository hygiene tests.
- Run `swift test` to ensure documentation changes do not break repository checks.
- Verify repository description, homepage, topics and social preview on GitHub.
- Recheck GitHub's community profile and all release/download links after publication.

## Success Signals

Success is measured by a clear first-screen value proposition, working download flow, complete community metadata, increased repository traffic, stars, release downloads and useful issues over time. No numeric growth guarantee is made because discovery also depends on external promotion and product adoption.
