import XCTest
@testable import Pocket

final class SongImportSummaryTests: XCTestCase {

    func testEmptyPickIsNotReportable() {
        let summary = SongImportSummary(imported: 0, failedNames: [])
        XCTAssertFalse(summary.isReportable)
    }

    func testCleanImportConfirmsSuccess() {
        let summary = SongImportSummary(imported: 3, failedNames: [])
        XCTAssertTrue(summary.isReportable)
        XCTAssertEqual(summary.title, "Songs added")
        XCTAssertEqual(summary.message, "Imported 3 songs.")
    }

    func testCleanImportSingularSong() {
        let summary = SongImportSummary(imported: 1, failedNames: [])
        XCTAssertEqual(summary.message, "Imported 1 song.")
    }

    func testAllFailedListsNamesWithoutImportedCount() {
        let summary = SongImportSummary(imported: 0, failedNames: ["Little Wing", "take 3"])
        XCTAssertEqual(summary.title, "Some files were skipped")
        XCTAssertEqual(summary.message, "2 files couldn’t be read: Little Wing, take 3.")
    }

    func testSingleFailureIsSingular() {
        let summary = SongImportSummary(imported: 0, failedNames: ["broken"])
        XCTAssertEqual(summary.message, "1 file couldn’t be read: broken.")
    }

    func testPartialImportReportsBothCounts() {
        let summary = SongImportSummary(imported: 4, failedNames: ["broken"])
        XCTAssertEqual(summary.title, "Some files were skipped")
        XCTAssertEqual(summary.message, "Imported 4 songs. 1 file couldn’t be read: broken.")
    }

    func testPartialImportSingularSong() {
        let summary = SongImportSummary(imported: 1, failedNames: ["a", "b"])
        XCTAssertEqual(summary.message, "Imported 1 song. 2 files couldn’t be read: a, b.")
    }
}
