import XCTest
@testable import MontaMacCore

final class RcloneJSONLogParserTests: XCTestCase {
    func testFragmentedStatisticsLineProducesOneSnapshot() {
        var parser = RcloneJSONLogParser()
        let first = parser.consume(#"{"level":"notice","stats":{"bytes":4222,"totalBytes":10000,"speed":2111.5,"eta":3,"transferring":[{"name":"video.mov","bytes":4222,"size":10000,"percentage":42,"speed":2111.5,"eta":3}]"#)
        let second = parser.consume("}}\n")

        XCTAssertTrue(first.isEmpty)
        XCTAssertEqual(second, [.statistics(TransferSnapshot(
            bytes: 4_222,
            totalBytes: 10_000,
            speedBytesPerSecond: 2_111.5,
            etaSeconds: 3,
            activeTransfers: 1,
            currentFile: "video.mov"
        ))])
    }

    func testOrdinaryJSONLogReturnsOnlyMessage() {
        var parser = RcloneJSONLogParser()

        XCTAssertEqual(parser.consume(#"{"level":"error","msg":"connection failed"}"# + "\n"), [.log("connection failed")])
    }

    func testMultipleLinesAndPlainFallbackArePreserved() {
        var parser = RcloneJSONLogParser()

        let events = parser.consume(#"{"level":"notice","msg":"ready"}"# + "\nlegacy warning\n")

        XCTAssertEqual(events, [.log("ready"), .log("legacy warning")])
    }

    func testStatisticsExposeOnlyFileBasename() {
        var parser = RcloneJSONLogParser()
        let events = parser.consume(#"{"stats":{"bytes":1,"transferring":[{"name":"private/customer/video.mov"}]}}"# + "\n")

        guard case let .statistics(snapshot) = events.first else { return XCTFail("Missing statistics") }
        XCTAssertEqual(snapshot.currentFile, "video.mov")
    }
}
