import Foundation
import XCTest
@testable import MontaMacCore

final class DirectorySizeServiceTests: XCTestCase {
    func testAllocatedBytesCountsNestedRegularFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = root.appendingPathComponent("nested")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 1_024).write(to: root.appendingPathComponent("a.bin"))
        try Data(repeating: 0x42, count: 2_048).write(to: nested.appendingPathComponent("b.bin"))

        let bytes = try DirectorySizeService().allocatedBytes(at: root)

        XCTAssertGreaterThanOrEqual(bytes, 3_072)
    }

    func testAllocatedBytesReturnsZeroForMissingDirectory() throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        XCTAssertEqual(try DirectorySizeService().allocatedBytes(at: missing), 0)
    }
}
