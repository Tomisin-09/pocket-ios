import XCTest
@testable import Pocket

/// Storage for imported song audio (ADR 0148). The filename identity and the retention sweep are
/// pure and pinned here; `adopt` gets real round-trips because "the copy replaces rather than
/// accumulates" is the behaviour that would rot a user's disk silently if it broke.
final class SongFileStoreTests: XCTestCase {

    private var fileManager: TempContainerFileManager!

    override func setUp() {
        super.setUp()
        fileManager = TempContainerFileManager()
    }

    override func tearDown() {
        fileManager.destroy()
        fileManager = nil
        super.tearDown()
    }

    private func makeSourceFile(named name: String, contents: String) throws -> URL {
        try fileManager.makeSourceFile(named: name, contents: contents)
    }

    // MARK: - Filename identity

    func testFileNamePreservesTheSourceExtension() {
        // The decoder picks a parser by extension, so flattening every import to one suffix would
        // break formats `WaveformExtractor` reads today.
        XCTAssertEqual(SongFileStore.fileName(for: "abc", sourceExtension: "m4a"), "abc.m4a")
        XCTAssertEqual(SongFileStore.fileName(for: "abc", sourceExtension: "wav"), "abc.wav")
    }

    func testFileNameWithoutAnExtensionIsTheBareSourceID() {
        XCTAssertEqual(SongFileStore.fileName(for: "abc", sourceExtension: ""), "abc",
                       "an extension-less source keeps its id rather than inventing a format")
    }

    func testFileNameIsDerivedFromSourceIDSoItSurvivesRetitling() {
        // Naming by `sourceID` (not the song title) is what lets a song be renamed, or two songs
        // share a title, without either losing its audio.
        let first = SongFileStore.fileName(for: "id-one", sourceExtension: "m4a")
        let second = SongFileStore.fileName(for: "id-two", sourceExtension: "m4a")
        XCTAssertNotEqual(first, second)
    }

    // MARK: - Adopting a file

    func testAdoptCopiesTheFileAndReportsItPresent() throws {
        let source = try makeSourceFile(named: "picked.m4a", contents: "audio")
        let leaf = try SongFileStore.adopt(contentsOf: source, sourceID: "song-1", fileManager)

        XCTAssertEqual(leaf, "song-1.m4a")
        XCTAssertTrue(SongFileStore.exists(fileName: leaf, fileManager))
        let copied = try Data(contentsOf: SongFileStore.url(for: leaf, fileManager))
        XCTAssertEqual(String(bytes: copied, encoding: .utf8), "audio")
    }

    func testAdoptLeavesTheSourceFileWhereItWas() throws {
        // A copy, never a move: the user's own file stays put in Files/iCloud Drive.
        let source = try makeSourceFile(named: "picked.m4a", contents: "audio")
        _ = try SongFileStore.adopt(contentsOf: source, sourceID: "song-1", fileManager)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testAdoptingTwiceForOneSongReplacesRatherThanFailing() throws {
        // Re-import and (slice 2) relink both land here. `copyItem` throws onto an existing file,
        // so without the explicit remove this would fail — and a song would be stuck on its old
        // audio forever.
        let first = try makeSourceFile(named: "first.m4a", contents: "original")
        let second = try makeSourceFile(named: "second.m4a", contents: "replacement")
        _ = try SongFileStore.adopt(contentsOf: first, sourceID: "song-1", fileManager)
        let leaf = try SongFileStore.adopt(contentsOf: second, sourceID: "song-1", fileManager)

        let copied = try Data(contentsOf: SongFileStore.url(for: leaf, fileManager))
        XCTAssertEqual(String(bytes: copied, encoding: .utf8), "replacement")
        XCTAssertEqual(SongFileStore.filesOnDisk(fileManager).count, 1,
                       "replacing must not leave the previous copy behind")
    }

    func testTwoSongsKeepSeparateCopies() throws {
        let source = try makeSourceFile(named: "picked.m4a", contents: "audio")
        _ = try SongFileStore.adopt(contentsOf: source, sourceID: "song-1", fileManager)
        _ = try SongFileStore.adopt(contentsOf: source, sourceID: "song-2", fileManager)
        XCTAssertEqual(Set(SongFileStore.filesOnDisk(fileManager)), ["song-1.m4a", "song-2.m4a"])
    }

    // MARK: - Deletion and size

    func testDeleteRemovesTheCopyAndIsIdempotent() throws {
        let source = try makeSourceFile(named: "picked.m4a", contents: "audio")
        let leaf = try SongFileStore.adopt(contentsOf: source, sourceID: "song-1", fileManager)

        try SongFileStore.delete(fileName: leaf, fileManager)
        XCTAssertFalse(SongFileStore.exists(fileName: leaf, fileManager))
        XCTAssertNoThrow(try SongFileStore.delete(fileName: leaf, fileManager),
                         "deleting a file that is already gone is not an error")
    }

    func testFileSizeIsNilForAFileThatIsNotThere() {
        XCTAssertNil(SongFileStore.fileSize(fileName: "ghost.m4a", fileManager))
    }

    func testFileSizeReportsTheCopiedBytes() throws {
        let source = try makeSourceFile(named: "picked.m4a", contents: "audio")
        let leaf = try SongFileStore.adopt(contentsOf: source, sourceID: "song-1", fileManager)
        XCTAssertEqual(SongFileStore.fileSize(fileName: leaf, fileManager), 5)
    }

    // MARK: - Retention sweep

    func testOrphanedFilesAreThoseNotReferenced() {
        let onDisk = ["a.m4a", "b.m4a", "c.m4a"]
        XCTAssertEqual(SongFileStore.orphanedFiles(onDisk: onDisk, referenced: ["a.m4a", "c.m4a"]),
                       ["b.m4a"], "only the unreferenced copy is reapable")
    }

    func testNoOrphansWhenEverySongStillReferencesItsCopy() {
        let onDisk = ["a.m4a", "b.m4a"]
        XCTAssertTrue(SongFileStore.orphanedFiles(onDisk: onDisk,
                                                  referenced: ["a.m4a", "b.m4a"]).isEmpty)
    }

    func testReferencedFileMissingFromDiskIsNotAnOrphan() {
        // A song whose copy is missing is a *relink* case, never a deletion case — the sweep only
        // ever proposes deleting real, unreferenced files.
        XCTAssertTrue(SongFileStore.orphanedFiles(onDisk: [], referenced: ["ghost.m4a"]).isEmpty)
    }
}
