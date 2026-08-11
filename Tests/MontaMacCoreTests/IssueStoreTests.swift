import XCTest
@testable import MontaMacCore

final class IssueStoreTests: XCTestCase {
    private var root: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        fileURL = root.appendingPathComponent("issues.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testRepeatedIssueIsCoalescedAndCounted() throws {
        let store = IssueStore(fileURL: fileURL)
        let profileID = UUID()
        let issue = AppIssue(code: .mountInterrupted, profileID: profileID, arguments: ["9"], severity: .warning)

        try store.record(issue)
        try store.record(issue)

        let saved = try store.recent(limit: 100)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].occurrenceCount, 2)
        XCTAssertEqual(saved[0].profileID, profileID)
    }

    func testIssueHistoryKeepsOnlyLatestHundred() throws {
        let store = IssueStore(fileURL: fileURL)

        for index in 0..<110 {
            try store.record(AppIssue(code: .updateCheckFailed, arguments: ["\(index)"], severity: .error))
        }

        let saved = try store.recent(limit: 200)
        XCTAssertEqual(saved.count, 100)
        XCTAssertEqual(saved.last?.arguments, ["109"])
    }
}
