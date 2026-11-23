import XCTest
@testable import Pocket

/// **Practice as triads** (ADR 0313 D9): what the New exercise form opens on when a progression in *My
/// progressions* is practised as triads. The button and the menu item both make their seed here, so this
/// is what they agree on. That the form shows it filled in is `PracticeAsTriadsUITests`. Models are left
/// uninserted, as `SavedProgressionTests` leaves them.
final class PracticeAsTriadsTests: XCTestCase {

    private let verse = [ProgressionStep(9, .minor), ProgressionStep(5), ProgressionStep(0), ProgressionStep(7, .dom7)]

    /// An Arpeggios exercise on guitar, named for the progression, generating Triads with the progression
    /// copied in, in the key it was written in, and D10's defaults for everything else.
    func testItOpensOnTheProgressionInItsKeyWithD10sDefaults() throws {
        let seed = try XCTUnwrap(NewExerciseSeed.practiceAsTriads(name: "Verse changes", steps: verse, tonic: 7))
        XCTAssertEqual(seed.template, .arpeggios)
        XCTAssertEqual(seed.instrument, .guitar, "Triads is guitar only (D2)")
        XCTAssertEqual(seed.name, "Verse changes as triads")

        let run = seed.triads
        XCTAssertEqual(run.source, .progression)
        XCTAssertEqual(run.progression, TriadRun.Progression(name: "Verse changes", steps: verse))
        XCTAssertEqual(run.playedProgression?.steps, verse, "the run plays the progression, not the key's seven")
        XCTAssertEqual(run.tonic, 7, "in the key it was written in")

        let starter = TriadRun.starter
        XCTAssertEqual(run.strings, starter.strings)
        XCTAssertEqual(run.placement, .stayInFrets)
        XCTAssertEqual(run.fretRange, 3...7)
        XCTAssertEqual(run.playAs, .broken)
        XCTAssertEqual(run.notesPerBeat, 2, "eighths")
        XCTAssertFalse(run.roundTrip)
    }

    /// The copy is the chords as they are now, bars and all: editing the progression later leaves the
    /// exercise alone (D5), which the copy being a value is what buys.
    func testTheCopyKeepsEachChordsBars() throws {
        var steps = verse
        steps[1].bars = 2
        let seed = try XCTUnwrap(NewExerciseSeed.practiceAsTriads(name: "Verse", steps: steps, tonic: 0))
        XCTAssertEqual(seed.triads.progression?.steps.map(\.bars), [1, 2, 1, 1])
    }

    /// A progression that opens on its minor tonic reads minor (D5), and the run's own key follows, so
    /// switching *Chords* to the key's seven stays in that key.
    func testAMinorProgressionKeepsItsReadingForTheKeysSeven() throws {
        let minor = [ProgressionStep(0, .minor), ProgressionStep(8), ProgressionStep(3), ProgressionStep(10)]
        var run = try XCTUnwrap(NewExerciseSeed.practiceAsTriads(name: "Aeolian", steps: minor, tonic: 9)).triads
        XCTAssertTrue(run.readsAsMinor)
        XCTAssertEqual(run.keyName(preference: .sharps), "A minor")
        run.source = .keysSeven
        XCTAssertEqual(run.keyName(preference: .sharps), "A minor", "the key's seven should be A minor's")
    }

    /// A progression saved before the key was stored has none: it opens where the builder would, in G.
    func testNoStoredKeyOpensInTheBuildersKey() throws {
        let seed = try XCTUnwrap(NewExerciseSeed.practiceAsTriads(name: "Old", steps: verse, tonic: nil))
        XCTAssertEqual(seed.triads.tonic, ProgressionDraft.defaultTonic)
    }

    /// No chord a triad plays, no seed: the button stays, disabled, rather than open a board that never
    /// lights. One power chord among others is fine; it rests for its length (D5).
    func testOnlyPowerChordsOrNoChordsMakeNoSeed() {
        XCTAssertNil(NewExerciseSeed.practiceAsTriads(name: "Empty", steps: [], tonic: 0))
        let riff = [ProgressionStep(4, .fifth), ProgressionStep(9, .fifth), ProgressionStep(2, .fifth)]
        XCTAssertNil(NewExerciseSeed.practiceAsTriads(name: "Riff", steps: riff, tonic: 4))
        XCTAssertNotNil(NewExerciseSeed.practiceAsTriads(name: "Riff", steps: riff + [ProgressionStep(0)], tonic: 4))
    }

    /// What the seed opens on actually plays: the progression expands to lit notes in frets 3 to 7.
    func testTheSeededRunPlaysInsideItsRange() throws {
        let run = try XCTUnwrap(NewExerciseSeed.practiceAsTriads(name: "Loop", steps: verse, tonic: 7)).triads
        let drill = run.expanded(beatsPerBar: 4)
        let lit = drill.notes.compactMap { $0 }
        XCTAssertFalse(lit.isEmpty, "the seeded run lit nothing")
        XCTAssertTrue(lit.allSatisfy { (3...7).contains($0.fret) }, "a note left frets 3 to 7")
    }

    func testTheTitleTrimsAndNeverComesOutNameless() {
        XCTAssertEqual(NewExerciseSeed.practiceAsTriadsTitle(for: "  Bridge  "), "Bridge as triads")
        XCTAssertEqual(NewExerciseSeed.practiceAsTriadsTitle(for: " "), "Progression as triads")
        let seed = NewExerciseSeed.practiceAsTriads(name: "  Bridge ", steps: verse, tonic: 0)
        XCTAssertEqual(seed?.triads.progression?.name, "Bridge", "the menu names it as the list does")
    }

    /// The menu item reads the progression as saved: its name, chords and key.
    func testASavedProgressionSeedsFromWhatWasSaved() throws {
        let saved = SavedProgression(ProgressionDraft(name: "Verse changes", tonic: 2, steps: verse))
        let seed = try XCTUnwrap(saved.practiceAsTriadsSeed)
        XCTAssertEqual(seed.name, "Verse changes as triads")
        XCTAssertEqual(seed.triads.tonic, 2)
        XCTAssertEqual(seed.triads.progression?.steps, verse)
    }
}
