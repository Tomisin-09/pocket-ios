import XCTest
import SwiftData
@testable import Pocket

/// `Exercise` model logic (ADR 0043, slice 2). The `@Model` is exercised as a
/// plain in-memory object for the computed accessors and enum round-trips; a real
/// in-memory `ModelContainer` is used once to prove the new model joins the schema
/// (the additive migration) without wiping the store.
final class ExerciseTests: XCTestCase {

    // MARK: - Defaults

    func testDefaultsAreSensible() {
        let exercise = Exercise()
        XCTAssertEqual(exercise.currentTempo, 80)
        XCTAssertEqual(exercise.targetTempo, 120)
        XCTAssertEqual(exercise.beatsPerBar, 4)
        XCTAssertEqual(exercise.noteValue, 4)
        XCTAssertEqual(exercise.accentBeats, [0])
        XCTAssertEqual(exercise.subdivision, .none)
        XCTAssertEqual(exercise.rampIntervalUnit, .bars)
        XCTAssertEqual(exercise.dwellIntervals, 4)
        XCTAssertTrue(exercise.includeBackoff)
    }

    func testEachExerciseGetsAUniqueUID() {
        XCTAssertNotEqual(Exercise().uid, Exercise().uid)
    }

    // MARK: - String-backed enum round-trips

    func testSubdivisionRoundTripsThroughStringBacking() {
        let exercise = Exercise()
        exercise.subdivision = .triplets
        XCTAssertEqual(exercise.subdivisionRaw, "triplets")
        XCTAssertEqual(exercise.subdivision, .triplets)
        XCTAssertEqual(exercise.subdivision.ticksPerBeat, 3)
    }

    func testSubdivisionFallsBackToNoneOnUnknownRaw() {
        let exercise = Exercise()
        exercise.subdivisionRaw = "not-a-subdivision"
        XCTAssertEqual(exercise.subdivision, .none)
    }

    func testIntervalUnitRoundTripsThroughStringBacking() {
        let exercise = Exercise()
        exercise.rampIntervalUnit = .seconds
        XCTAssertEqual(exercise.rampIntervalUnitRaw, "seconds")
        XCTAssertEqual(exercise.rampIntervalUnit, .seconds)
    }

    func testIntervalUnitFallsBackToBarsOnUnknownRaw() {
        let exercise = Exercise()
        exercise.rampIntervalUnitRaw = "fortnights"
        XCTAssertEqual(exercise.rampIntervalUnit, .bars)
    }

    // MARK: - Computed accessors

    func testTempoMarkingDerivesFromCurrentTempo() {
        XCTAssertEqual(Exercise(currentTempo: 90).tempoMarking, .andante)
        XCTAssertEqual(Exercise(currentTempo: 140).tempoMarking, .allegro)
    }

    func testTempoGapIsRemainingClimb() {
        XCTAssertEqual(Exercise(currentTempo: 100, targetTempo: 130).tempoGap, 30)
    }

    func testTempoGapClampsToZeroAtOrPastTarget() {
        XCTAssertEqual(Exercise(currentTempo: 130, targetTempo: 120).tempoGap, 0)
    }

    func testTimeSignatureLabel() {
        XCTAssertEqual(Exercise(beatsPerBar: 6, noteValue: 8).timeSignatureLabel, "6/8")
    }

    // MARK: - Creation factory (ADR 0046/0052)

    func testCommandAnchoredCarriesTheChosenMeter() {
        // The create sheet's time-signature picker must reach the stored model (ADR 0052),
        // so the run metronome's accents + count-in length honor it.
        let exercise = Exercise.commandAnchored(name: "Waltz drill", command: 100,
                                                beatsPerBar: 3, noteValue: 4)
        XCTAssertEqual(exercise.beatsPerBar, 3)
        XCTAssertEqual(exercise.noteValue, 4)
        XCTAssertEqual(exercise.timeSignatureLabel, "3/4")
    }

    func testCommandAnchoredDefaultsToFourFour() {
        let exercise = Exercise.commandAnchored(name: "Plain", command: 90)
        XCTAssertEqual(exercise.beatsPerBar, 4)
        XCTAssertEqual(exercise.noteValue, 4)
    }

    // MARK: - Training ramp (ADR 0046 — the run(ramp:) seam)

    func testRampMapsTheSavedRecipe() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100,
                                rampStepBPM: 8, rampIntervalCount: 4,
                                rampIntervalUnit: .bars, dwellIntervals: 6, includeBackoff: false)
        let ramp = exercise.ramp
        XCTAssertEqual(ramp.working, 70)
        XCTAssertEqual(ramp.command, 100)
        XCTAssertEqual(ramp.target, TempoStretch.targetBPM(forCommand: 100))
        XCTAssertEqual(ramp.stepBPM, 8)
        XCTAssertEqual(ramp.intervalCount, 4)
        XCTAssertEqual(ramp.unit, .bars)
        // dwell + backoff now come from native storage, not a fixed routine shape.
        XCTAssertEqual(ramp.dwellIntervals, 6)
        XCTAssertFalse(ramp.includeBackoff)
    }

    func testRampCarriesReachAndBackoffSteps() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100,
                                rampReachSteps: 2, rampBackoffSteps: 3)
        XCTAssertEqual(exercise.ramp.reachSteps, 2)
        XCTAssertEqual(exercise.ramp.backoffSteps, 3)
    }

    func testRampDefaultsToNoReachOrBackoffSteps() {
        let ramp = Exercise(currentTempo: 70, commandTempo: 100).ramp
        XCTAssertEqual(ramp.reachSteps, 0)
        XCTAssertEqual(ramp.backoffSteps, 0)
    }

    /// An un-promoted exercise (no measured command) still produces a usable ramp: command
    /// falls back to the working tempo, so the routine reads as a flat hold-and-stretch.
    func testRampFallsBackToWorkingWhenUnpromoted() {
        let exercise = Exercise(currentTempo: 90)   // commandTempo nil
        let ramp = exercise.ramp
        XCTAssertEqual(ramp.working, 90)
        XCTAssertEqual(ramp.command, 90)
        XCTAssertEqual(ramp.target, TempoStretch.targetBPM(forCommand: 90))
    }

    /// Step, interval, and dwell are clamped to at least 1 so the ramp always advances and the
    /// plateau math never divides by zero.
    func testRampClampsStepAndIntervalToAtLeastOne() {
        let exercise = Exercise(rampStepBPM: 0, rampIntervalCount: 0, dwellIntervals: 0)
        XCTAssertEqual(exercise.ramp.stepBPM, 1)
        XCTAssertEqual(exercise.ramp.intervalCount, 1)
        XCTAssertEqual(exercise.ramp.dwellIntervals, 1)
    }

    // MARK: - Schema / persistence (additive migration)

    func testExercisePersistsAndFetchesInItsOwnStore() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            configurations: config)
        let context = ModelContext(container)

        let spider = Exercise(name: "Spider", currentTempo: 100, targetTempo: 160,
                                       subdivision: .sixteenths,
                                       rampIntervalUnit: .seconds, tags: ["picking"])
        context.insert(spider)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Spider")
        XCTAssertEqual(fetched.first?.subdivision, .sixteenths)
        XCTAssertEqual(fetched.first?.rampIntervalUnit, .seconds)
        XCTAssertEqual(fetched.first?.tags, ["picking"])
        XCTAssertEqual(fetched.first?.targetTempo, 160)
    }

    /// The new model shares a container with the existing `Song` graph without
    /// disturbing it — the additive-migration guarantee (ADR 0011/0012).
    func testCoexistsWithSongGraphInOneContainer() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            configurations: config)
        let context = ModelContext(container)

        context.insert(Song(title: "Song", duration: 100,
                            ref: SongRef(id: "x", source: .localFile, bookmark: nil)))
        context.insert(Exercise(name: "Alternating picking"))
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Song>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 1)
    }
}
