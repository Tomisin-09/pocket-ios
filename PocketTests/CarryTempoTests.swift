import SwiftData
import XCTest
@testable import Pocket

/// **The tempo-carry gateway** (ADR 0170): holding the song player's BPM callout lifts the tempo
/// currently on screen and offers it to the metronome or to a new drill.
///
/// The chooser itself is UI and is device-verified (ADR 0163 — nothing in `PocketUITests` can reach
/// the waveform screen from a cold launch). What *is* testable, and is the part that can be silently
/// wrong, is which number leaves the song and what the destination does with it: the callout shows
/// `song.bpm × speed`, so a slowed reading is a different number from the song's own tempo, and
/// picking the wrong one is invisible until someone reads the metronome and finds 200 where they
/// were practising 50. Main-actor: both the model and the engine are `@MainActor`.
@MainActor
final class CarryTempoTests: XCTestCase {

    /// A real (empty) context for the model's signature — nothing is inserted, for the reason
    /// `WaveformPracticeSpeedTests` documents (inserting `Song.sample()`'s graph traps in the host).
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self,
            configurations: .init(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    // MARK: - What leaves the song

    /// The decision the ADR records: the gateway carries **the number on screen**, not the song's
    /// stored tempo. This is the assertion that fails if someone later "tidies" `carryTempo` into
    /// reading `song.bpm` directly — which would look correct at 1× and be wrong everywhere else.
    func testCarriesTheDisplayedTempoNotTheSongsOwn() throws {
        let song = Song.sample()
        song.bpm = 200
        let model = WaveformPracticeModel(song: song, context: try makeContext())
        model.speed = 0.25

        let displayed = try XCTUnwrap(model.displayedBPM)
        XCTAssertEqual(displayed, 50, "the callout reads the effective tempo")

        model.carryTempo(displayed)

        XCTAssertEqual(model.carryingTempo?.bpm, 50,
                       "a 200 BPM song at 0.25× carries 50 — the tempo actually being practised")
        XCTAssertNotEqual(model.carryingTempo?.bpm, song.bpm,
                          "the song's own tempo is deliberately not what leaves")
    }

    func testAtFullSpeedTheTwoTemposAgree() throws {
        let song = Song.sample()
        song.bpm = 128
        let model = WaveformPracticeModel(song: song, context: try makeContext())
        model.speed = 1.0

        model.carryTempo(try XCTUnwrap(model.displayedBPM))

        XCTAssertEqual(model.carryingTempo?.bpm, 128, "at 1× the distinction has nothing to bite on")
    }

    /// The chooser is `.sheet(item:)`-bound, so holding the same tempo twice must be two *different*
    /// items or the second hold does nothing. A `struct` keyed on the BPM would fail this.
    func testHoldingTheSameTempoTwiceMintsAFreshPresentation() throws {
        let song = Song.sample()
        song.bpm = 90
        let model = WaveformPracticeModel(song: song, context: try makeContext())

        model.carryTempo(90)
        let first = try XCTUnwrap(model.carryingTempo?.id)
        model.carryingTempo = nil       // the sheet was dismissed
        model.carryTempo(90)

        XCTAssertNotEqual(model.carryingTempo?.id, first,
                          "identity is minted per hold, so the chooser re-presents on an unchanged tempo")
    }

    // MARK: - The meter that travels with it

    func testSongMeterRecoversItsNamedPreset() throws {
        let song = Song.sample()
        song.beatsPerBar = 3
        song.noteValue = 4
        let model = WaveformPracticeModel(song: song, context: try makeContext())

        XCTAssertEqual(model.songSignature.name, "3/4",
                       "a drill made from a waltz opens on 3/4, not on the 4/4 default")
        XCTAssertEqual(model.songSignature.accentBeats, [0],
                       "the preset's own accents stand — a song stores no accent pattern")
    }

    func testAnUnusualMeterStillTravels() throws {
        let song = Song.sample()
        song.beatsPerBar = 9
        song.noteValue = 8
        let model = WaveformPracticeModel(song: song, context: try makeContext())

        XCTAssertEqual(model.songSignature.beats, 9)
        XCTAssertEqual(model.songSignature.noteValue, 8)
        XCTAssertEqual(model.songSignature.accentBeats, [0],
                       "`forStored` never leaves the accent list empty — beat one is always accented")
    }

    // MARK: - What the metronome does with it

    /// What `MetronomeView.init(initialBPM:)` does, in the one line that carries the behaviour: a
    /// fresh engine, seeded before the first body pass. Reproduced here rather than reached through
    /// the view because a `View`'s `init` isn't callable from a test without a host.
    private func seededEngine(at bpm: Int?) -> StandaloneMetronomeEngine {
        let engine = StandaloneMetronomeEngine()
        if let bpm { engine.setBPM(bpm) }
        return engine
    }

    func testTheMetronomeOpensOnTheCarriedTempo() {
        XCTAssertEqual(seededEngine(at: 132).bpm, 132,
                       "the screen opens on the carried tempo, not on free play's 90")
    }

    func testNoCarriedTempoLeavesFreePlayUnchanged() {
        XCTAssertEqual(seededEngine(at: nil).bpm, StandaloneMetronomeEngine.defaultBPM,
                       "the Home hub's route is untouched by the new seam")
    }

    /// The carried tempo is the first number to reach the metronome from **outside its own
    /// controls**, and the song player's range is not the metronome's: a fast song at 1.5× reads
    /// past 300, a slow one at 0.25× below 30. Routing the seed through `setBPM` is what makes those
    /// land instead of being stored raw — which is why the view seeds that way.
    func testACarriedTempoOutsideTheMetronomesRangeIsClampedNotRejected() {
        let range = StandaloneMetronomeEngine.bpmRange

        XCTAssertEqual(seededEngine(at: 450).bpm, range.upperBound,
                       "a 300 BPM song at 1.5× carries 450 — clamped to the ceiling, still usable")
        XCTAssertEqual(seededEngine(at: 10).bpm, range.lowerBound,
                       "a 40 BPM song at 0.25× carries 10 — clamped to the floor")
    }

    /// Seeding a stopped engine must leave nothing else changed — `setBPM`'s two side effects are
    /// both `transport`-guarded, and this is the assertion that catches it if one stops being.
    func testSeedingDoesNotStartAnything() {
        let engine = seededEngine(at: 132)

        XCTAssertEqual(engine.transport, .stopped, "arriving on a tempo is not arriving playing")
        engine.adjustBPM(by: -2)
        XCTAssertEqual(engine.bpm, 130, "the steppers nudge from the carried tempo, not the default")
    }
}
