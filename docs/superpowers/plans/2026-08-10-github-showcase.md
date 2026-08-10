# MontaMac GitHub Showcase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `CultureDigitali/MontaMac` into a product-first, bilingual GitHub showcase that remains technically credible and safe for public distribution.

**Architecture:** Keep the root README focused on conversion and discovery, with detailed policies split into dedicated community files. Store public marketing assets under `Assets/GitHub`, validate the repository surface through Swift tests, and apply GitHub-only metadata after the local branch passes every check.

**Tech Stack:** GitHub Flavored Markdown, Swift/XCTest, PNG assets, GitHub CLI, GitHub repository settings.

## Global Constraints

- The primary README language is English with a concise Italian section.
- Keep the existing MontaMac logo as the official identity.
- Screenshots may contain only synthetic `.example` data and no credentials, private hosts, local usernames or real mount paths.
- Show only latest release, macOS, Swift, license and tests badges.
- State explicitly that release `2.1.0` is not notarized with Apple Developer ID.
- Do not change the application binary or mount behavior.
- Do not promise stars, universal compatibility or unsupported competitive claims.

---

### Task 1: Repository showcase contract

**Files:**
- Create: `Tests/MontaMacCoreTests/RepositoryShowcaseTests.swift`

**Interfaces:**
- Consumes: repository files relative to `#filePath`.
- Produces: XCTest coverage for public assets, README calls to action and community files.

- [ ] **Step 1: Write the failing repository-surface tests**

```swift
import Foundation
import XCTest

final class RepositoryShowcaseTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testReadmeContainsProductAndDownloadSurface() throws {
        let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
        for required in [
            "Mount remote storage directly in Finder",
            "releases/latest",
            "Assets/GitHub/montamac-hero.png",
            "## Why MontaMac?",
            "## Quick start",
            "## Italiano",
        ] {
            XCTAssertTrue(readme.contains(required), "README missing: \(required)")
        }
    }

    func testCommunityFilesExist() {
        for path in [
            "CONTRIBUTING.md",
            "CODE_OF_CONDUCT.md",
            "ROADMAP.md",
            ".github/ISSUE_TEMPLATE/bug_report.yml",
            ".github/ISSUE_TEMPLATE/feature_request.yml",
            ".github/ISSUE_TEMPLATE/config.yml",
            ".github/pull_request_template.md",
        ] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path), path)
        }
    }

    func testPublicImagesExistAndAreNonempty() throws {
        for path in [
            "Assets/GitHub/montamac-hero.png",
            "Assets/GitHub/dashboard.png",
            "Assets/GitHub/profiles.png",
            "Assets/GitHub/statistics.png",
            "Assets/GitHub/social-preview.png",
        ] {
            let values = try root.appendingPathComponent(path).resourceValues(forKeys: [.fileSizeKey])
            XCTAssertGreaterThan(values.fileSize ?? 0, 10_000, path)
        }
    }
}
```

- [ ] **Step 2: Run the new suite and verify failure**

Run: `swift test --filter RepositoryShowcaseTests`

Expected: FAIL because the new README surface, community files and images do not exist.

- [ ] **Step 3: Commit the red test**

```bash
git add Tests/MontaMacCoreTests/RepositoryShowcaseTests.swift
git commit -m "test: define GitHub showcase surface"
```

### Task 2: Privacy-safe visual assets

**Files:**
- Create: `Assets/GitHub/montamac-hero.png`
- Create: `Assets/GitHub/social-preview.png`
- Create: `Assets/GitHub/dashboard.png`
- Create: `Assets/GitHub/profiles.png`
- Create: `Assets/GitHub/statistics.png`

**Interfaces:**
- Consumes: `Assets/MontaMac-logo.png`, installed `/Applications/MontaMac.app`, and isolated synthetic application data.
- Produces: five public PNG images referenced by README and GitHub settings.

- [ ] **Step 1: Generate the branded hero and social preview**

Use the image-generation workflow with the official logo as reference and this exact direction:

```text
Create a premium open-source macOS product banner for MontaMac. Preserve the supplied official blue drive logo exactly as the brand focal point. Dark navy-to-cobalt solid gradient, subtle macOS glass depth, restrained cyan glow, ample negative space, no device mockup, no third-party logos. Add crisp text: “MontaMac” and “Remote drives. Native on your Mac.” Wide 2:1 composition, professional developer-tool aesthetic, accessible contrast, no tiny text.
```

Export `montamac-hero.png` at 1600x800 and `social-preview.png` at 1280x640 with a solid background and file size below 1 MB for the social preview.

- [ ] **Step 2: Prepare an isolated demo profile store**

Create a temporary `CFFIXED_USER_HOME` using `mktemp -d`. Under `Library/Application Support/MontaMac`, write three synthetic connections named `Creative Studio`, `Secure Archive` and `Team WebDAV`, using `sftp.example.com`, `ftp.example.com` and `dav.example.com`, username `demo`, mount paths inside the temporary home, and no password fields. Create a few small dummy files beneath the `Creative Studio` mount path.

- [ ] **Step 3: Launch the existing release in isolated demo mode**

Run the existing executable with `CFFIXED_USER_HOME` pointing to the temporary home. Set `hasSeenOnboarding=true` for bundle `local.montamac.app`. Do not read, move or change the real `~/Library/Application Support/MontaMac` directory.

- [ ] **Step 4: Capture three real application views**

Capture the dashboard, filtered profile manager and `Creative Studio` detail after refreshing local statistics. Crop each image to the app window and save them as `dashboard.png`, `profiles.png` and `statistics.png`. Confirm visually that no real username, private path, credential or server appears.

- [ ] **Step 5: Validate images and clean the isolated demo**

Run:

```bash
sips -g pixelWidth -g pixelHeight Assets/GitHub/*.png
find Assets/GitHub -type f -size +5M -print
```

Expected: all images have valid dimensions; `social-preview.png` is exactly 1280x640 and below 1 MB; no file exceeds 5 MB. Stop the isolated demo process and delete only its resolved temporary directory.

- [ ] **Step 6: Commit the visual assets**

```bash
git add Assets/GitHub
git commit -m "docs: add MontaMac showcase visuals"
```

### Task 3: Product-first bilingual README

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: the official `v2.1.0` release URL and `Assets/GitHub/*.png`.
- Produces: the GitHub landing page and its download, documentation and star calls to action.

- [ ] **Step 1: Replace the README with the approved information architecture**

Write an English-first README containing:

- centered hero image, concise promise and five essential badges;
- `Download latest`, `Quick start` and `Star MontaMac` links above the fold;
- `Why MontaMac?`, real screenshots, feature matrix and protocol support;
- a short manual-mount versus MontaMac workflow comparison;
- three-step installation with SHA-256 verification;
- security, privacy and non-notarization disclosure;
- languages, roadmap, contributing, support, credits and license;
- concise `## Italiano` product, download and installation summary.

Use only repository-relative image and document links. Link downloads to `https://github.com/CultureDigitali/MontaMac/releases/latest` so future releases require no README change.

- [ ] **Step 2: Run the focused showcase tests**

Run: `swift test --filter RepositoryShowcaseTests.testReadmeContainsProductAndDownloadSurface`

Expected: PASS.

- [ ] **Step 3: Check links and sensitive strings locally**

Run:

```bash
rg -n '/Users/|RAI DRIVE|beneventocalcio|D549-016F|password\s*[:=]|token\s*[:=]' README.md Assets/GitHub || true
rg -o '\]\(([^)]+)\)' README.md
```

Expected: no sensitive match; every relative file target exists.

- [ ] **Step 4: Commit the landing page**

```bash
git add README.md
git commit -m "docs: redesign GitHub landing page"
```

### Task 4: Community and contribution surface

**Files:**
- Create: `CONTRIBUTING.md`
- Create: `CODE_OF_CONDUCT.md`
- Create: `ROADMAP.md`
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Create: `.github/ISSUE_TEMPLATE/feature_request.yml`
- Create: `.github/ISSUE_TEMPLATE/config.yml`
- Create: `.github/pull_request_template.md`

**Interfaces:**
- Consumes: existing `SECURITY.md`, `LICENSE`, `Package.swift` and build scripts.
- Produces: GitHub-recognized contribution guidance, issue forms and PR checklist.

- [ ] **Step 1: Add contribution and conduct documents**

`CONTRIBUTING.md` must include local setup, `swift test`, branch naming, focused commits, localization requirements, security disclosure routing and a prohibition on real credentials or private hosts. `CODE_OF_CONDUCT.md` must define respectful behavior, enforcement at `info@culturedigitali.eu`, confidentiality and proportionate consequences.

- [ ] **Step 2: Add a realistic roadmap**

`ROADMAP.md` must distinguish `Now`, `Next` and `Exploring`. Put notarized distribution and stronger installer UX in `Next`; place additional protocols and automatic updates in `Exploring`; make clear that exploratory items are not commitments.

- [ ] **Step 3: Add GitHub issue forms**

The bug form must require MontaMac version, macOS version, protocol, reproduction steps, expected behavior and redacted logs. The feature form must request problem, proposed outcome and alternatives. Both forms must require confirmation that secrets and private server data were removed. Disable blank issues in `config.yml` and link security reports to `SECURITY.md` through the repository URL.

- [ ] **Step 4: Add the pull-request template**

Require a summary, motivation, screenshots for UI changes, `swift test` confirmation, localization coverage, release impact and a checkbox confirming no secrets or private host data.

- [ ] **Step 5: Run community-file tests**

Run: `swift test --filter RepositoryShowcaseTests.testCommunityFilesExist`

Expected: PASS.

- [ ] **Step 6: Commit the community surface**

```bash
git add CONTRIBUTING.md CODE_OF_CONDUCT.md ROADMAP.md .github
git commit -m "docs: add community contribution paths"
```

### Task 5: GitHub metadata and publication

**Files:**
- Modify remotely: repository description, homepage, topics and social preview.
- Publish: branch `agent/github-showcase` through a reviewed pull request to `main`.

**Interfaces:**
- Consumes: verified local branch and `Assets/GitHub/social-preview.png`.
- Produces: discoverable public GitHub metadata and the updated default-branch landing page.

- [ ] **Step 1: Run the full local verification**

Run:

```bash
swift test
git diff main...HEAD --check
git grep -n -I -E '(-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|/Users/[A-Za-z0-9._-]+|RAI DRIVE|beneventocalcio)' main..HEAD || true
```

Expected: all tests pass, no diff errors and no sensitive match.

- [ ] **Step 2: Apply repository metadata**

Run:

```bash
gh repo edit CultureDigitali/MontaMac \
  --description "Native open-source macOS app to mount FTP, SFTP and WebDAV remote drives directly in Finder." \
  --homepage "https://culturedigitali.eu/" \
  --add-topic macos --add-topic swift --add-topic swiftui --add-topic finder \
  --add-topic sftp --add-topic ftp --add-topic webdav --add-topic rclone \
  --add-topic fuse --add-topic remote-drive --add-topic file-manager --add-topic open-source
```

- [ ] **Step 3: Upload the social preview**

Open repository settings and upload `Assets/GitHub/social-preview.png` under Social preview. Confirm the displayed crop contains the full logo and both text lines.

- [ ] **Step 4: Push and open the pull request**

```bash
git push -u origin agent/github-showcase
gh pr create --base main --head agent/github-showcase --title "Turn MontaMac into a GitHub product showcase" --body-file /tmp/montamac-github-showcase-pr.md
```

The PR body must summarize the landing-page redesign, public visuals, metadata, community files, privacy scan and test results.

- [ ] **Step 5: Verify the PR and merge**

Confirm the rendered README, every image and every link on GitHub. Merge with squash only after checks pass:

```bash
gh pr merge --squash --delete-branch
git switch main
git pull --ff-only
```

- [ ] **Step 6: Verify the live repository**

Run:

```bash
gh repo view CultureDigitali/MontaMac --json description,homepageUrl,repositoryTopics,defaultBranchRef,url
gh api repos/CultureDigitali/MontaMac/community/profile
gh release view v2.1.0 --json url,assets
git status -sb
```

Expected: metadata is populated, community health files are detected, release assets remain unchanged, and local `main` matches `origin/main`.
