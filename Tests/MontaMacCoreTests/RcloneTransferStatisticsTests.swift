import XCTest
@testable import MontaMacCore

final class RcloneTransferStatisticsTests: XCTestCase {
    func testParserReadsIECAndByteTotals() {
        XCTAssertEqual(
            RcloneTransferStatisticsParser.totalBytes(
                from: "Transferred: 1.500 MiB / 2 MiB, 75%, 1 MiB/s, ETA 1s"
            ),
            1_572_864
        )
        XCTAssertEqual(
            RcloneTransferStatisticsParser.totalBytes(
                from: "Transferred: 800 B / 800 B, 100%, 0 B/s, ETA -"
            ),
            800
        )
    }

    func testParserRejectsUnrelatedAndMalformedLines() {
        XCTAssertNil(RcloneTransferStatisticsParser.totalBytes(from: "Drive montato correttamente."))
        XCTAssertNil(RcloneTransferStatisticsParser.totalBytes(from: "Transferred: nope MiB / 2 MiB"))
    }

    func testTrackerReturnsOnlyPositiveDeltasAndHandlesReset() {
        var tracker = TransferProgressTracker()

        XCTAssertEqual(tracker.consume(totalBytes: 1_000), 1_000)
        XCTAssertEqual(tracker.consume(totalBytes: 1_000), 0)
        XCTAssertEqual(tracker.consume(totalBytes: 1_500), 500)
        XCTAssertEqual(tracker.consume(totalBytes: 200), 200)

        tracker.reset()
        XCTAssertEqual(tracker.consume(totalBytes: 50), 50)
    }
}
