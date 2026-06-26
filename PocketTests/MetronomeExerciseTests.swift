import XCTest
import SwiftData
@testable import Pocket

/// `MetronomeExercise` model logic (ADR 0043, slice 2). The `@Model` is exercised as a
/// plain in-memory object for the computed accessors and enum round-trips; a real
/// in-memory `ModelContainer` is used once to prove the new model joins the schema
/// (the additive migration) without wiping the store.
final class MetronomeExerciseTests: XCTestCase {

    // MARK: - Defaults

    func testDefaultsAreSensible() {
        let exercise = MetronomeExercise()
        XCTAssertEqual(exercise.currentTempo, 80)
        XCTAssertEqual(exercise.targetTempo, 120)
        XCTAssertEqual(exercise.beatsPerBar, 4)
        XCTAssertEqual(exercise.noteValue, 4)
        XCTAssertEqual(exercise.accentBeats, [0])
        XCTAssertEqual(exercise.subdivision, .none)
        XCTAssertEqual(exercise.automatorIntervalUnit, .bars)
        XCTAssertFalse(exercise.automatorEnabled)
        XCTAssertNil(exercise.automatorCeiling)
    }

    func testEachExerciseGetsAUniqueUID() {
        XCTAssertNotEqual(MetronomeExercise().uid, MetronomeExercise().uid)
    }

    // MARK: - String-backed enum round-trips

    func testSubdivisionRoundTripsThroughStringBacking() {
        let exercise = MetronomeExercise()
        exercise.subdivision = .triplets
        XCTAssertEqual(exercise.subdivisionRaw, "triplets")
        XCTAssertEqual(exercise.subdivision, .triplets)
        XCTAssertEqual(exercise.subdivision.ticksPerBeat, 3)
    }

    func testSubdivisionFallsBackToNoneOnUnknownRaw() {
        let exercise = MetronomeExercise()
        exercise.subdivisionRaw = "not-a-subdivision"
        XCTAssertEqual(exercise.subdivision, .none)
    }

    func testIntervalUnitRoundTripsThroughStringBacking() {
        let exercise = MetronomeExercise()
        exercise.automatorIntervalUnit = .seconds
        XCTAssertEqual(exercise.automatorIntervalUnitRaw, "seconds")
        XCTAssertEqual(exercise.automatorIntervalUnit, .seconds)
    }

    func testIntervalUnitFallsBackToBarsOnUnknownRaw() {
        let exercise = MetronomeExercise()
        exercise.automatorIntervalUnitRaw = "fortnights"
        XCTAssertEqual(exercise.automatorIntervalUnit, .bars)
    }

    // MARK: - Computed accessors

    func testResolvedCeilingDefaultsToTargetTempo() {
        let exercise = MetronomeExercise(targetTempo: 140)
        XCTAssertEqual(exercise.resolvedAutomatorCeiling, 140)
    }

    func testResolvedCeilingUsesExplicitCeilingWhenSet() {
        let exercise = MetronomeExercise(targetTempo: 140, automatorCeiling: 160)
        XCTAssertEqual(exercise.resolvedAutomatorCeiling, 160)
    }

    func testTempoMarkingDerivesFromCurrentTempo() {
        XCTAssertEqual(MetronomeExercise(currentTempo: 90).tempoMarking, .andante)
        XCTAssertEqual(MetronomeExercise(currentTempo: 140).tempoMarking, .allegro)
    }

    func testTempoGapIsRemainingClimb() {
        XCTAssertEqual(MetronomeExercise(currentTempo: 100, targetTempo: 130).tempoGap, 30)
    }

    func testTempoGapClampsToZeroAtOrPastTarget() {
        XCTAssertEqual(MetronomeExercise(currentTempo: 130, targetTempo: 120).tempoGap, 0)
    }

    func testTimeSignatureLabel() {
        XCTAssertEqual(MetronomeExercise(beatsPerBar: 6, noteValue: 8).timeSignatureLabel, "6/8")
    }

    // MARK: - Schema / persistence (additive migration)

    func testExercisePersistsAndFetchesInItsOwnStore() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, MetronomeExercise.self,
            configurations: config)
        let context = ModelContext(container)

        let spider = MetronomeExercise(name: "Spider", currentTempo: 100, targetTempo: 160,
                                       subdivision: .sixteenths,
                                       automatorIntervalUnit: .seconds, tags: ["picking"])
        context.insert(spider)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MetronomeExercise>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Spider")
        XCTAssertEqual(fetched.first?.subdivision, .sixteenths)
        XCTAssertEqual(fetched.first?.automatorIntervalUnit, .seconds)
        XCTAssertEqual(fetched.first?.tags, ["picking"])
        XCTAssertEqual(fetched.first?.resolvedAutomatorCeiling, 160)
    }

    /// The new model shares a container with the existing `Song` graph without
    /// disturbing it — the additive-migration guarantee (ADR 0011/0012).
    func testCoexistsWithSongGraphInOneContainer() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, MetronomeExercise.self,
            configurations: config)
        let context = ModelContext(container)

        context.insert(Song(title: "Song", duration: 100,
                            ref: SongRef(id: "x", source: .localFile, bookmark: nil)))
        context.insert(MetronomeExercise(name: "Alternating picking"))
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Song>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MetronomeExercise>()).count, 1)
    }
}
