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
