import Foundation
import XCTest
@testable import MontaMacCore

final class CacheUsageServiceTests: XCTestCase {
    func testSnapshotReturnsTotalAndPerProfileUsage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let first = UUID()
        let second = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent(first.uuidString), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(second.uuidString), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 1_024).write(to: root.appendingPathComponent(first.uuidString).appendingPathComponent("one.bin"))
        try Data(repeating: 2, count: 2_048).write(to: root.appendingPathComponent(second.uuidString).appendingPathComponent("two.bin"))

        let snapshot = try CacheUsageService().snapshot(cacheRoot: root, profileIDs: [first, second])

        XCTAssertGreaterThanOrEqual(snapshot.bytesByProfile[first] ?? 0, 1_024)
        XCTAssertGreaterThanOrEqual(snapshot.bytesByProfile[second] ?? 0, 2_048)
        XCTAssertEqual(snapshot.totalBytes, snapshot.bytesByProfile.values.reduce(0, +))
        XCTAssertGreaterThan(snapshot.availableDiskBytes, 0)
    }

    func testClearRefusesMountedProfileAndPreservesItsCache() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = UUID()
        let profileCache = root.appendingPathComponent(profileID.uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: profileCache, withIntermediateDirectories: true)
        try Data("pending".utf8).write(to: profileCache.appendingPathComponent("pending.bin"))

        XCTAssertThrowsError(try CacheUsageService().clear(profileID: profileID, cacheRoot: root, isMounted: true)) {
            XCTAssertEqual($0 as? CacheUsageError, .profileMounted)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: profileCache.path))
    }

    func testClearRemovesOnlyExactProfileDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let profileID = UUID()
        let siblingID = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent(profileID.uuidString), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(siblingID.uuidString), withIntermediateDirectories: true)

        try CacheUsageService().clear(profileID: profileID, cacheRoot: root, isMounted: false)

        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(profileID.uuidString).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(siblingID.uuidString).path))
    }
}
