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
///
/// **No `setUp`/`tearDown`, deliberately.** `SongDeletion.perform` is `@MainActor` — it reads a
/// `@Model` — so this class must be too, and XCTest's `setUpWithError`/`tearDownWithError` overrides
/// are **nonisolated**. Touching a main-actor stored property from one compiles on Xcode 26.5 and
/// fails CI's Xcode 16 with "main actor-isolated property can not be mutated from a nonisolated
/// context". Every other `@MainActor` suite here builds its fixtures inside the test methods for the
/// same reason; `withContainer` keeps that from meaning four copies of the same `defer`.
@MainActor
final class SongDeletionTests: XCTestCase {

    /// Run `body` against a throwaway container that is destroyed however it exits.
    private func withContainer(_ body: (TempContainerFileManager) throws -> Void) rethrows {
        let fileManager = TempContainerFileManager()
        defer { fileManager.destroy() }
        try body(fileManager)
    }

    private func makeSong(audioFileName: String?, sourceID: String = "song-1") -> Song {
        Song(title: "Sample", artist: "Jack Trader", duration: 100, amplitudes: [],
             ref: SongRef(id: sourceID, source: .localFile, bookmark: nil),
             audioFileName: audioFileName)
    }

    private func writeCopy(_ name: String, _ fileManager: FileManager) throws {
        try Data(repeating: 0x53, count: 2048).write(to: try SongFileStore.url(for: name, fileManager))
    }

    /// The leak, stated as a test.
    func testDeletingASongRemovesItsOwnedCopy() throws {
        try withContainer { fileManager in
            try writeCopy("song-1.wav", fileManager)
            XCTAssertTrue(SongFileStore.exists(fileName: "song-1.wav", fileManager))

            SongDeletion.perform(makeSong(audioFileName: "song-1.wav"), fileManager) {}

            XCTAssertFalse(SongFileStore.exists(fileName: "song-1.wav", fileManager),
                           "a deleted song must not leave its audio behind")
            XCTAssertTrue(SongFileStore.filesOnDisk(fileManager).isEmpty)
        }
    }

    /// One song's delete must not reach another's copy.
    func testOnlyTheDeletedSongsCopyIsRemoved() throws {
        try withContainer { fileManager in
            try writeCopy("song-1.wav", fileManager)
            try writeCopy("song-2.wav", fileManager)

            SongDeletion.perform(makeSong(audioFileName: "song-1.wav"), fileManager) {}

            XCTAssertEqual(SongFileStore.filesOnDisk(fileManager), ["song-2.wav"])
        }
    }

    /// The row delete is the point of the operation; the file is a side effect. It must run whatever
    /// happens to the audio — including for a pre-ADR-0148 song that never had a copy.
    func testTheRowIsDeletedEvenWhenThereIsNoAudioToRemove() {
        withContainer { fileManager in
            var deletedRow = false

            SongDeletion.perform(makeSong(audioFileName: nil), fileManager) { deletedRow = true }

            XCTAssertTrue(deletedRow)
        }
    }

    /// A copy already gone — swept, purged, or removed by a restore — is not an error, and must not
    /// strand the row.
    func testAnAlreadyMissingCopyStillDeletesTheRow() {
        withContainer { fileManager in
            var deletedRow = false

            SongDeletion.perform(makeSong(audioFileName: "ghost.wav"), fileManager) { deletedRow = true }

            XCTAssertTrue(deletedRow)
        }
    }
}
