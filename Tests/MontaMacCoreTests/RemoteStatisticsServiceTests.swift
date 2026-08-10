import XCTest
@testable import MontaMacCore

final class RemoteStatisticsServiceTests: XCTestCase {
    func testSizeParserExtractsBytesAndFileCount() throws {
        let stats = try RemoteStatisticsService.parseSizeOutput("Total objects: 42\nTotal size: 1.500 GiB\n")
        XCTAssertEqual(stats.fileCount, 42)
        XCTAssertEqual(stats.totalBytes, 1_610_612_736)
    }

    func testMountedFolderScanCountsFilesAndBytes() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 7, count: 12).write(to: directory.appendingPathComponent("sample.bin"))
        let stats = try await RemoteStatisticsService().scanMountedFolder(at: directory)
        XCTAssertEqual(stats.fileCount, 1)
        XCTAssertEqual(stats.totalBytes, 12)
    }
}
