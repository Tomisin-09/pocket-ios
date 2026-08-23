import XCTest
@testable import Pocket

/// Deleting a song takes its audio with it (ADR 0182).
///
/// The app's only song-delete path was a bare `context.delete(song)` for four months, so every song
/// a player removed left its full-size copy in the container forever. That is an **absence**, and an
/// absence passes every build and every existing test — which is why the rule now lives somewhere it
/// can be neutralised and watched to fail.
///
/// The song is left **uninserted** and the row delete is injected as a closure, so this exercises the
/// real file work without a `ModelContainer` (inserting traps in the XCTest host).
@MainActor
final class SongDeletionTests: XCTestCase {

    private var fileManager: TempContainerFileManager!

    override func setUpWithError() throws {
        fileManager = TempContainerFileManager()
    }

    override func tearDownWithError() throws {
        fileManager.destroy()
        fileManager = nil
    }

    private func makeSong(audioFileName: String?, sourceID: String = "song-1") -> Song {
        Song(title: "Sample", artist: "Jack Trader", duration: 100, amplitudes: [],
             ref: SongRef(id: sourceID, source: .localFile, bookmark: nil),
             audioFileName: audioFileName)
    }

    private func writeCopy(_ name: String) throws {
        try Data(repeating: 0x53, count: 2048).write(to: try SongFileStore.url(for: name, fileManager))
    }

    /// The leak, stated as a test.
    func testDeletingASongRemovesItsOwnedCopy() throws {
        try writeCopy("song-1.wav")
        XCTAssertTrue(SongFileStore.exists(fileName: "song-1.wav", fileManager))

        SongDeletion.perform(makeSong(audioFileName: "song-1.wav"), fileManager) {}

        XCTAssertFalse(SongFileStore.exists(fileName: "song-1.wav", fileManager),
                       "a deleted song must not leave its audio behind")
        XCTAssertTrue(SongFileStore.filesOnDisk(fileManager).isEmpty)
    }

    /// One song's delete must not reach another's copy.
    func testOnlyTheDeletedSongsCopyIsRemoved() throws {
        try writeCopy("song-1.wav")
        try writeCopy("song-2.wav")

        SongDeletion.perform(makeSong(audioFileName: "song-1.wav"), fileManager) {}

        XCTAssertEqual(SongFileStore.filesOnDisk(fileManager), ["song-2.wav"])
    }

    /// The row delete is the point of the operation; the file is a side effect. It must run whatever
    /// happens to the audio — including for a pre-ADR-0148 song that never had a copy.
    func testTheRowIsDeletedEvenWhenThereIsNoAudioToRemove() {
        var deletedRow = false

        SongDeletion.perform(makeSong(audioFileName: nil), fileManager) { deletedRow = true }

        XCTAssertTrue(deletedRow)
    }

    /// A copy already gone — swept, purged, or removed by a restore — is not an error, and must not
    /// strand the row.
    func testAnAlreadyMissingCopyStillDeletesTheRow() {
        var deletedRow = false

        SongDeletion.perform(makeSong(audioFileName: "ghost.wav"), fileManager) { deletedRow = true }

        XCTAssertTrue(deletedRow)
    }
}
