import XCTest
@testable import Pocket

/// The sweep that finally runs (ADR 0182).
///
/// Both stores have carried a pure `orphanedFiles` since ADR 0069 and ADR 0148, and both were tested
/// — but nothing in the app called either, while `docs/architecture.md` described the retention story
/// as though it did. These tests are about the composition: that it deletes only what nothing points
/// at, that it measures before it deletes, and that it says what it did.
final class OrphanSweepTests: XCTestCase {

    private var fileManager: TempContainerFileManager!

    override func setUpWithError() throws {
        fileManager = TempContainerFileManager()
    }

    override func tearDownWithError() throws {
        fileManager.destroy()
        fileManager = nil
    }

    @discardableResult
    private func writeSong(_ name: String, bytes: Int = 1000) throws -> String {
        try Data(repeating: 0x53, count: bytes).write(to: try SongFileStore.url(for: name, fileManager))
        return name
    }

    @discardableResult
    private func writeTake(_ name: String, bytes: Int = 500) throws -> String {
        try Data(repeating: 0x54, count: bytes).write(to: try RecordingStore.url(for: name, fileManager))
        return name
    }

    private func songsOnDisk() -> Set<String> { Set(SongFileStore.filesOnDisk(fileManager)) }
    private func takesOnDisk() -> Set<String> { Set(RecordingStore.filesOnDisk(fileManager)) }

    // MARK: - What it deletes

    /// The leak this ADR exists for: a song row deleted, its audio left behind forever.
    func testAnUnreferencedSongFileIsRemovedAndCounted() throws {
        let kept = try writeSong("kept.wav", bytes: 2000)
        try writeSong("orphan.wav", bytes: 3000)

        let outcome = OrphanSweep.run(referencedSongFiles: [kept], referencedTakeFiles: [], fileManager)

        XCTAssertEqual(outcome.songFiles, ["orphan.wav"])
        XCTAssertEqual(outcome.bytesFreed, 3000)
        XCTAssertEqual(songsOnDisk(), [kept])
    }

    /// A `.trimtmp.m4a` stranded by a crash mid-trim keeps the `.m4a` suffix on purpose, precisely so
    /// a sweep would catch it — a sweep that until now never ran.
    func testAStrandedTrimTemporaryIsReaped() throws {
        let kept = try writeTake("\(UUID().uuidString).m4a")
        try writeTake("\(UUID().uuidString).trimtmp.m4a", bytes: 4000)

        let outcome = OrphanSweep.run(referencedSongFiles: [], referencedTakeFiles: [kept], fileManager)

        XCTAssertEqual(outcome.takeFiles.count, 1)
        XCTAssertTrue(outcome.takeFiles[0].hasSuffix(".trimtmp.m4a"), outcome.takeFiles[0])
        XCTAssertEqual(takesOnDisk(), [kept])
    }

    /// Both directories in one pass, and the bytes summed across them.
    func testItSweepsBothStoresAndSumsWhatItFreed() throws {
        try writeSong("orphan.wav", bytes: 1500)
        try writeTake("\(UUID().uuidString).m4a", bytes: 2500)

        let outcome = OrphanSweep.run(referencedSongFiles: [], referencedTakeFiles: [], fileManager)

        XCTAssertEqual(outcome.fileCount, 2)
        XCTAssertEqual(outcome.bytesFreed, 4000)
        XCTAssertTrue(songsOnDisk().isEmpty)
        XCTAssertTrue(takesOnDisk().isEmpty)
    }

    // MARK: - What it must never delete

    /// The failure that would matter. A referenced file is a player's audio, and a sweep that removed
    /// one would be destroying the thing the app exists to hold.
    func testNothingReferencedIsEverTouched() throws {
        let song = try writeSong("kept.wav")
        let take = try writeTake("\(UUID().uuidString).m4a")

        let outcome = OrphanSweep.run(referencedSongFiles: [song], referencedTakeFiles: [take],
                                      fileManager)

        XCTAssertTrue(outcome.isEmpty)
        XCTAssertEqual(outcome.bytesFreed, 0)
        XCTAssertEqual(songsOnDisk(), [song])
        XCTAssertEqual(takesOnDisk(), [take])
    }

    /// A take outlives its loop (ADR 0151) and routine blocks record takes now too (ADRs 0179/0180),
    /// so the referenced set has to come from **every** `Recording` row. Passing a set built from one
    /// owner's relationship is how a real recording gets classified as rubbish — this pins that the
    /// sweep deletes exactly what it is told is unreferenced and nothing else.
    func testATakeWhoseOwnerIsGoneSurvivesWhileItsRowDoes() throws {
        let orphanedButKept = try writeTake("\(UUID().uuidString).m4a")

        let outcome = OrphanSweep.run(referencedSongFiles: [],
                                      referencedTakeFiles: [orphanedButKept], fileManager)

        XCTAssertTrue(outcome.isEmpty)
        XCTAssertEqual(takesOnDisk(), [orphanedButKept])
    }

    // MARK: - What it says

    /// Finding nothing is the good answer and has to read as one, or players learn to keep pressing a
    /// button that has nothing to do.
    func testAnEmptySweepReadsAsReassuranceNotFailure() {
        let summary = OrphanSweep.summary(.init())

        XCTAssertTrue(summary.contains("Nothing to reclaim"), summary)
        XCTAssertFalse(summary.lowercased().contains("error"), summary)
    }

    func testTheSummaryCountsFilesAcrossBothStoresAndNamesTheSize() {
        let summary = OrphanSweep.summary(.init(songFiles: ["a.wav"], takeFiles: ["b.m4a"],
                                                bytesFreed: 5_000_000))

        XCTAssertTrue(summary.contains("2 stray files"), summary)
        XCTAssertTrue(summary.contains(StorageUsage.formatted(bytes: 5_000_000)), summary)
    }

    func testOneStrayFileIsNotCalledOneStrayFiles() {
        XCTAssertTrue(OrphanSweep.summary(.init(songFiles: ["a.wav"], bytesFreed: 1))
            .contains("1 stray file,"))
    }
}
