import XCTest
@testable import Pocket

/// **The import sheet's rows** (ADR 0290): each picked file waits, is read, and is added or skipped with a
/// reason; the title counts the file being read, then says what happened.
final class SongImportBatchTests: XCTestCase {

    private func batch(_ names: String...) -> SongImportBatch { SongImportBatch(names: names) }

    func testEveryFileWaitsUntilItsTurn() {
        let batch = batch("Binta", "take-3", "Little Wing")
        XCTAssertEqual(batch.files.map(\.state), [.waiting, .waiting, .waiting])
        XCTAssertEqual(batch.files.map(\.name), ["Binta", "take-3", "Little Wing"])
        XCTAssertFalse(batch.isFinished)
        XCTAssertEqual(batch.title, "Importing 1 of 3")
    }

    func testTheTitleCountsTheFileBeingRead() {
        var batch = batch("Binta", "take-3", "Little Wing")
        batch.reading(0)
        XCTAssertEqual(batch.title, "Importing 1 of 3")
        batch.added(0)
        batch.reading(1)
        XCTAssertEqual(batch.title, "Importing 2 of 3")
        XCTAssertEqual(batch.files.map(\.state), [.added, .reading, .waiting])
        batch.added(1)
        batch.reading(2)
        XCTAssertFalse(batch.isFinished, "the last file is still being read")
        XCTAssertEqual(batch.title, "Importing 3 of 3")
    }

    func testAFinishedBatchSaysWhatHappened() {
        var batch = batch("Binta", "take-3", "Little Wing")
        batch.added(0)
        batch.skipped(1, because: WaveformExtractor.ExtractError.emptyFile)
        batch.added(2)
        XCTAssertTrue(batch.isFinished)
        XCTAssertEqual(batch.summary, SongImportSummary(imported: 2, failedNames: ["take-3"]))
        XCTAssertEqual(batch.title, "Some files were skipped")
        XCTAssertEqual(batch.files[1].state, .skipped("There's no audio in it."))
    }

    func testAllAddedReadsAsSongsAdded() {
        var batch = batch("Binta", "take-3")
        batch.added(0)
        batch.added(1)
        XCTAssertEqual(batch.title, "Songs added")
    }

    func testASkippedFileSaysWhetherTryingAgainCouldHelp() {
        XCTAssertEqual(SongImportBatch.reason(for: SongImporter.ImportError.accessDenied),
                       "Red Moon wasn't allowed to open it. Try picking it again.")
        XCTAssertEqual(SongImportBatch.reason(for: WaveformExtractor.ExtractError.emptyFile), "There's no audio in it.")
        XCTAssertEqual(SongImportBatch.reason(for: NSError(domain: "AVFoundation", code: -11_829)),
                       "It couldn't be read. A copy-protected file can't be imported.")
    }

    func testEachRowSaysWhereItsFileIs() {
        XCTAssertEqual([SongImportBatch.State.waiting, .reading, .added, .skipped("There's no audio in it.")]
            .map(SongImportSheet.line),
                       ["Waiting", "Reading the file…", "Added", "There's no audio in it."])
    }

    func testAFileOutsideThePickChangesNothing() {
        var batch = batch("Binta")
        batch.added(3)
        XCTAssertEqual(batch.files.map(\.state), [.waiting])
    }
}
