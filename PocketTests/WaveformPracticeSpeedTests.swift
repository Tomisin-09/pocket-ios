import SwiftData
import XCTest
@testable import Pocket

/// Song-level resume tempo (ADR 0044): the practice model resumes the full song at its
/// last-practiced speed and keeps the invariant "no loop armed ⇒ `speed` is the song's tempo"
/// — banking the song's speed when a loop arms, restoring it when the last loop disarms, so a
/// loop's speed never leaks into `song.lastPracticedSpeed`. Runs on the main actor (the model
/// is `@MainActor`); no audio is started.
@MainActor
final class WaveformPracticeSpeedTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self,
            configurations: .init(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    func testEntryResumesSongTempo() throws {
        let context = try makeContext()
        let song = Song.sample()
        song.lastPracticedSpeed = 0.8
        context.insert(song)

        let model = WaveformPracticeModel(song: song, context: context)
        XCTAssertEqual(model.speed, 0.8, accuracy: 1e-9, "opens at the song's last-practiced tempo")
    }

    func testFreshSongOpensAtFullTempo() throws {
        let context = try makeContext()
        let song = Song.sample()                 // never practised → nil → 1×
        context.insert(song)

        let model = WaveformPracticeModel(song: song, context: context)
        XCTAssertEqual(model.speed, 1.0, accuracy: 1e-9)
    }

    func testArmingLoopBanksSongTempoAndDisarmRestoresIt() throws {
        let context = try makeContext()
        let song = Song.sample()
        context.insert(song)
        let model = WaveformPracticeModel(song: song, context: context)
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
