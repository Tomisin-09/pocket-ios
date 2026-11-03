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

    // MARK: - Open on create (Slice 2)

    func testLoneCleanImportOpensOnCreate() {
        XCTAssertTrue(SongImportSummary(imported: 1, failedNames: []).isSingleCleanImport)
    }

    func testBatchDoesNotOpenOnCreate() {
        XCTAssertFalse(SongImportSummary(imported: 2, failedNames: []).isSingleCleanImport)
    }

    /// One song in, one file skipped: the summary alert has something to say, so nothing opens.
    func testSingleImportWithSkippedFileDoesNotOpen() {
        XCTAssertFalse(SongImportSummary(imported: 1, failedNames: ["broken"]).isSingleCleanImport)
    }

    func testNothingImportedDoesNotOpen() {
        XCTAssertFalse(SongImportSummary(imported: 0, failedNames: []).isSingleCleanImport)
        XCTAssertFalse(SongImportSummary(imported: 0, failedNames: ["broken"]).isSingleCleanImport)
    }

    // MARK: - The import card (item 5a, 2026-11-03)

    /// The card names the file it's on, and counts it: the second of five is "2 of 5", not "1 of 5".
    func testTheCardNamesTheFileAndCountsTheOneInProgress() {
        let progress = SongImportProgress(completed: 1, total: 5, current: "Binta")
        XCTAssertEqual(progress.headline, "Importing “Binta”")
        XCTAssertEqual(progress.position, "2 of 5")
    }

    /// One file never says "1 of 1", and a file with no name yet says "Importing…".
    func testOneFileHasNoPositionAndNoNameFallsBack() {
        XCTAssertNil(SongImportProgress(completed: 0, total: 1, current: "Binta").position)
        XCTAssertEqual(SongImportProgress(completed: 0, total: 1).headline, "Importing…")
    }

    /// After the last file, before the card goes, the position stays on the last file.
    func testThePositionNeverRunsPastTheTotal() {
        XCTAssertEqual(SongImportProgress(completed: 3, total: 3, current: "Last").position, "3 of 3")
    }
}
