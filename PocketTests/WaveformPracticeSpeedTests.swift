import SwiftData
import XCTest
@testable import Pocket

/// Song-level resume tempo, **end-to-end through the model** (ADR 0044): the practice model
/// resumes the full song at its last-practiced speed on entry, banks the song's speed when a
/// loop arms, and restores it when the last loop disarms (the `SongTempoTransition` decision is
/// unit-tested separately). These exercise only in-memory property logic — the `@Model`
/// objects are used as plain objects (à la `SongTests`) and **not** inserted into the store:
/// `WaveformPracticeModel` needs a `ModelContext` for its signature but never saves here, and
/// inserting `Song.sample()`'s relationship graph into a fresh in-memory container traps inside
/// SwiftData in the test host. Main-actor: the model is `@MainActor`.
@MainActor
final class WaveformPracticeSpeedTests: XCTestCase {

    /// A real (empty) context for the model's signature — nothing is inserted into it.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self,
            configurations: .init(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    func testEntryResumesSongTempo() throws {
        let song = Song.sample()
        song.lastPracticedSpeed = 0.8

        let model = WaveformPracticeModel(song: song, context: try makeContext())
        XCTAssertEqual(model.speed, 0.8, accuracy: 1e-9, "opens at the song's last-practiced tempo")
    }

    func testFreshSongOpensAtFullTempo() throws {
        let song = Song.sample()                 // never practised → nil → 1×
        let model = WaveformPracticeModel(song: song, context: try makeContext())
        XCTAssertEqual(model.speed, 1.0, accuracy: 1e-9)
    }

    func testArmingLoopBanksSongTempoAndDisarmRestoresIt() throws {
        let song = Song.sample()
        let model = WaveformPracticeModel(song: song, context: try makeContext())
        let loop = try XCTUnwrap(song.loopsByStart.first)

        model.speed = 0.7                        // slow the full song
        model.activeLoopID = loop.uid            // arm → bank the song's tempo
        XCTAssertEqual(song.lastPracticedSpeed ?? -1, 0.7, accuracy: 1e-9,
                       "song speed banked at the moment a loop arms")

        model.speed = 0.5                        // slow the loop (doesn't touch the song's tempo)
        model.activeLoopID = nil                 // disarm → restore the song's tempo
        XCTAssertEqual(model.speed, 0.7, accuracy: 1e-9, "full song returns to its own tempo")
        XCTAssertEqual(loop.lastPracticedSpeed ?? -1, 0.5, accuracy: 1e-9,
                       "outgoing loop still banks its own speed (ADR 0040)")
        XCTAssertEqual(song.lastPracticedSpeed ?? -1, 0.7, accuracy: 1e-9,
                       "the loop's speed never leaks into the song's resume tempo")
    }
}
