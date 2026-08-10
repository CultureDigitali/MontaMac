import Foundation
import XCTest

final class ReleaseHardeningTests: XCTestCase {
    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    func testReleaseMetadataIsVersion210() throws {
        let data = try Data(contentsOf: projectRoot.appendingPathComponent("Resources/Info.plist"))
        let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(info["CFBundleShortVersionString"] as? String, "2.1.0")
        XCTAssertEqual(info["CFBundleVersion"] as? String, "4")
    }

    func testBuildScriptsEnableHardenedRuntimeAndOptionalInstallerSigning() throws {
        let appScript = try String(contentsOf: projectRoot.appendingPathComponent("Scripts/build-app.sh"), encoding: .utf8)
        let pkgScript = try String(contentsOf: projectRoot.appendingPathComponent("Scripts/build-pkg.sh"), encoding: .utf8)

        XCTAssertTrue(appScript.contains("--options runtime"))
        XCTAssertTrue(appScript.contains("MONTAMAC_SIGN_IDENTITY"))
        XCTAssertTrue(pkgScript.contains("MONTAMAC_INSTALLER_IDENTITY"))
        XCTAssertTrue(pkgScript.contains("MontaMac-2.1.0.pkg"))
    }
}
