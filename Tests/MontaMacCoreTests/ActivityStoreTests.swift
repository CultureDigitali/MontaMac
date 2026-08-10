import XCTest
@testable import MontaMacCore

final class ActivityStoreTests: XCTestCase {
    func testSummaryCountsTransferredBytesAndFailures() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = root.appendingPathComponent("activity.json")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ActivityStore(fileURL: url)
        let date = Date()
        try store.record(.transfer(connectionID: UUID(), bytes: 2048, at: date))
        try store.record(.failure(connectionID: UUID(), message: "offline", at: date))
        let summary = try store.summary(since: date.addingTimeInterval(-1))
        XCTAssertEqual(summary.transferredBytes, 2048)
        XCTAssertEqual(summary.failureCount, 1)
    }

    func testConsecutiveTransfersForSameConnectionAreCompacted() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = root.appendingPathComponent("activity.json")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ActivityStore(fileURL: url)
        let id = UUID()
        let date = Date()

        try store.record(.transfer(connectionID: id, bytes: 1_024, at: date))
        try store.record(.transfer(connectionID: id, bytes: 2_048, at: date.addingTimeInterval(1)))

        XCTAssertEqual(try store.summary(since: date.addingTimeInterval(-1)).transferredBytes, 3_072)
        XCTAssertEqual(try store.recentEvents().count, 1)
    }
}
