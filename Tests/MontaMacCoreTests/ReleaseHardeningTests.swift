import Foundation
import XCTest

final class ReleaseHardeningTests: XCTestCase {
    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    func testReleaseMetadataIsVersion220() throws {
        let data = try Data(contentsOf: projectRoot.appendingPathComponent("Resources/Info.plist"))
        let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(info["CFBundleShortVersionString"] as? String, "2.2.0")
        XCTAssertEqual(info["CFBundleVersion"] as? String, "6")
    }

    func testBuildScriptsEnableHardenedRuntimeAndOptionalInstallerSigning() throws {
        let appScript = try String(contentsOf: projectRoot.appendingPathComponent("Scripts/build-app.sh"), encoding: .utf8)
        let pkgScript = try String(contentsOf: projectRoot.appendingPathComponent("Scripts/build-pkg.sh"), encoding: .utf8)

        XCTAssertTrue(appScript.contains("--options runtime"))
        XCTAssertTrue(appScript.contains("MONTAMAC_SIGN_IDENTITY"))
        XCTAssertTrue(pkgScript.contains("MONTAMAC_INSTALLER_IDENTITY"))
        XCTAssertTrue(pkgScript.contains("APP_VERSION"))
        XCTAssertTrue(appScript.contains("MONTAMAC_RELEASE_BUILD"))
        XCTAssertTrue(appScript.contains("MONTAMAC_SPARKLE_PUBLIC_KEY"))
        XCTAssertTrue(pkgScript.contains("MONTAMAC_RELEASE_BUILD"))
    }

    func testReleaseWorkflowRequiresSigningNotarizationAndAppcast() throws {
        let workflow = try String(contentsOf: projectRoot.appendingPathComponent(".github/workflows/release.yml"), encoding: .utf8)

        XCTAssertTrue(workflow.contains("notarytool submit"))
        XCTAssertTrue(workflow.contains("stapler staple"))
        XCTAssertTrue(workflow.contains("generate_appcast"))
        XCTAssertTrue(workflow.contains("SPARKLE_PRIVATE_KEY"))
        XCTAssertTrue(workflow.contains("gh release create"))
    }
}
