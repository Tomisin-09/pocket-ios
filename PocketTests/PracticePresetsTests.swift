import SwiftData
import XCTest
@testable import Pocket

/// Covers the curated starter exercises (ADR 0046, Phase A): the pure builder produces the shipped
/// set with tempos derived through the single creation path, and the seeder runs **once, ever** so
/// deleted presets never return.
final class PracticePresetsTests: XCTestCase {

    // MARK: - Pure builder

    func testMakeExercisesProducesTheShippedSet() {
        let exercises = PracticePresets.makeExercises()
        XCTAssertEqual(exercises.count, 6)
        XCTAssertEqual(exercises.map(\.name),
                       ["Spider Walk", "Alternate Picking", "Chord Changes",
                        "Scale Runs", "String Skipping", "Legato"])
    }

    func testEachPresetIsCommandAnchoredWithDerivedTempos() {
        for (spec, exercise) in zip(PracticePresets.specs, PracticePresets.makeExercises()) {
            XCTAssertTrue(exercise.hasMeasuredCommand, "\(spec.name) should ship with a command")
            XCTAssertEqual(exercise.command, spec.command)
            // Working is the warm-up floor below command; reach derives via TempoStretch — exactly
            // as a user-created drill would (the single creation path).
            XCTAssertLessThanOrEqual(exercise.workingTempo, spec.command)
            XCTAssertEqual(exercise.targetTempo, TempoStretch.targetBPM(forCommand: spec.command))
            XCTAssertEqual(exercise.subdivision, spec.subdivision)
            XCTAssertEqual(exercise.tags, spec.tags)
            XCTAssertFalse(exercise.notes.isEmpty, "\(spec.name) should ship with a how-to note")
            XCTAssertEqual(exercise.template, spec.template, "\(spec.name) should carry its template")
        }
    }

    func testEveryPresetShipsWithACuratedTemplate() {
        let all = PracticePresets.makeExercises()
            + PracticePresets.makeExercises(PracticePresets.templateSpecs)
            + PracticePresets.makeExercises(PracticePresets.fretboardSpecs)
            + PracticePresets.makeExercises(PracticePresets.scaleSpecs)
            + PracticePresets.makeExercises(PracticePresets.arpeggioSpecs)
            + PracticePresets.makeExercises(PracticePresets.chordSpecs)
            + PracticePresets.makeExercises(PracticePresets.syncopatedMuteSpecs)
            + PracticePresets.makeExercises(PracticePresets.strumChordsSpecs)
        for exercise in all {
            XCTAssertNotEqual(exercise.template, .basic,
                              "\(exercise.name) should ship with a specific (non-basic) template")
        }
    }

    // MARK: - Template batch (ADR 0065 T9)

    func testTemplateSpecsShipAStrummingPatternExercise() {
        let exercises = PracticePresets.makeExercises(PracticePresets.templateSpecs)
        XCTAssertEqual(exercises.count, 1)
        let strumming = try? XCTUnwrap(exercises.first)
        XCTAssertEqual(strumming?.kind, .strumming)
        XCTAssertEqual(strumming?.strumPattern, .folk)
        // Still command-anchored like every other preset (the single creation path).
        XCTAssertTrue(strumming?.hasMeasuredCommand ?? false)
    }

    // MARK: - Fretboard batch (ADR 0065 build 2)

    func testFretboardSpecsShipAGeneratedRunExercise() {
        let exercises = PracticePresets.makeExercises(PracticePresets.fretboardSpecs)
        XCTAssertEqual(exercises.count, 1)
        let fretboard = try? XCTUnwrap(exercises.first)
        XCTAssertEqual(fretboard?.kind, .fretboard)
        // Ships the generated chromatic warm-up recipe, and the run screen sees its expanded drill.
        XCTAssertEqual(fretboard?.fretboardContent, .run(.chromaticWarmup))
        XCTAssertEqual(fretboard?.fretboardDrill, FretboardRun.chromaticWarmup.expanded())
        XCTAssertTrue(fretboard?.hasMeasuredCommand ?? false)
    }

    // MARK: - Scale library batch (ADR 0065 build 2, Slice 2)

    func testScaleSpecsShipAScaleRunExercise() {
        let exercises = PracticePresets.makeExercises(PracticePresets.scaleSpecs)
        XCTAssertEqual(exercises.count, 1)
        let scale = try? XCTUnwrap(exercises.first)
        XCTAssertEqual(scale?.kind, .fretboard)
        XCTAssertEqual(scale?.fretboardContent, .scale(.aMinorPentatonic))
        XCTAssertEqual(scale?.fretboardDrill, ScaleRun.aMinorPentatonic.expanded())
        XCTAssertTrue(scale?.hasMeasuredCommand ?? false)
    }

    // MARK: - Arpeggio library batch (ADR 0065 build 2, Slice 3)

    func testArpeggioSpecsShipAnArpeggioRunExercise() {
        let exercises = PracticePresets.makeExercises(PracticePresets.arpeggioSpecs)
        XCTAssertEqual(exercises.count, 1)
        let arpeggio = try? XCTUnwrap(exercises.first)
        XCTAssertEqual(arpeggio?.template, .arpeggios)
        XCTAssertEqual(arpeggio?.kind, .fretboard)
        XCTAssertEqual(arpeggio?.fretboardContent, .arpeggio(.aMinorSeventh))
        XCTAssertEqual(arpeggio?.fretboardDrill, ArpeggioRun.aMinorSeventh.expanded())
        XCTAssertTrue(arpeggio?.hasMeasuredCommand ?? false)
    }

    // MARK: - Chords batch (ADR 0065, Chords template)

    func testChordSpecsShipAChordProgressionExercise() {
        let exercises = PracticePresets.makeExercises(PracticePresets.chordSpecs)
        XCTAssertEqual(exercises.count, 1)
        let chords = try? XCTUnwrap(exercises.first)
        XCTAssertEqual(chords?.template, .chords)
        XCTAssertEqual(chords?.kind, .chords)
        XCTAssertEqual(chords?.chordProgression, .gMajorPop)
        XCTAssertTrue(chords?.hasMeasuredCommand ?? false)
    }

    // MARK: - Accent/mute strumming batch (ADR 0065, strumming slice 2)

    func testSyncopatedMuteSpecsShipAnAccentMuteStrummingExercise() {
        let exercises = PracticePresets.makeExercises(PracticePresets.syncopatedMuteSpecs)
        XCTAssertEqual(exercises.count, 1)
        let strumming = try? XCTUnwrap(exercises.first)
        XCTAssertEqual(strumming?.kind, .strumming)
        XCTAssertEqual(strumming?.strumPattern, .syncopatedMute)
        XCTAssertTrue(strumming?.hasMeasuredCommand ?? false)
    }

    // MARK: - Strum & chords batch (ADR 0065, strum↔chord composition)

    func testStrumChordsSpecsShipAStrumChordSheetExercise() {
        let exercises = PracticePresets.makeExercises(PracticePresets.strumChordsSpecs)
        XCTAssertEqual(exercises.count, 1)
        let strumChords = try? XCTUnwrap(exercises.first)
        XCTAssertEqual(strumChords?.template, .strumChords)
        XCTAssertEqual(strumChords?.kind, .strumChords)
        XCTAssertEqual(strumChords?.strumChordSheet, .popGroove)
        XCTAssertTrue(strumChords?.hasMeasuredCommand ?? false)
    }

    // MARK: - Seed-once guard

    func testSeedIfNeededInsertsBothBatchesOnceThenIsIdempotent() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Exercise.self, configurations: config)
        let context = ModelContext(container)
        let defaults = try freshDefaults()

        let total = PracticePresets.specs.count + PracticePresets.templateSpecs.count
            + PracticePresets.fretboardSpecs.count + PracticePresets.scaleSpecs.count
            + PracticePresets.arpeggioSpecs.count + PracticePresets.chordSpecs.count
            + PracticePresets.syncopatedMuteSpecs.count + PracticePresets.strumChordsSpecs.count
            + PracticePresets.scaleLayoutSpecs.count
        PracticePresets.seedIfNeeded(into: context, defaults: defaults)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, total)

        // A second call must not duplicate — both flags are set.
        PracticePresets.seedIfNeeded(into: context, defaults: defaults)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, total)
    }

    /// An existing user who already has the v1 set (its flag set) still gains the later template
    /// batches (v2 strumming, v3 fretboard) on the next launch — the additive-upgrade guarantee (T9).
    func testLaterBatchesSeedForAnExistingV1User() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Exercise.self, configurations: config)
        let context = ModelContext(container)
        let defaults = try freshDefaults()

        // Simulate a user who seeded v1 before templates existed.
        defaults.set(true, forKey: PracticePresets.seededDefaultsKey)

        PracticePresets.seedIfNeeded(into: context, defaults: defaults)
        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.count,
                       PracticePresets.templateSpecs.count + PracticePresets.fretboardSpecs.count
                       + PracticePresets.scaleSpecs.count + PracticePresets.arpeggioSpecs.count
                       + PracticePresets.chordSpecs.count + PracticePresets.syncopatedMuteSpecs.count
                       + PracticePresets.strumChordsSpecs.count + PracticePresets.scaleLayoutSpecs.count)
        // All newer batches arrive (fetch order isn't insertion order, so check the set).
        XCTAssertEqual(Set(fetched.map(\.kind)), [.strumming, .fretboard, .chords, .strumChords])
    }

    func testDeletedPresetsDoNotReturnOnNextSeed() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Exercise.self, configurations: config)
        let context = ModelContext(container)
        let defaults = try freshDefaults()

        PracticePresets.seedIfNeeded(into: context, defaults: defaults)
        // The user clears every preset…
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) { context.delete(exercise) }
        try context.save()

        // …and the next launch must leave the space empty, not re-seed.
        PracticePresets.seedIfNeeded(into: context, defaults: defaults)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 0)
    }

    /// A throwaway `UserDefaults` suite so the seed flag never touches the real domain.
    private func freshDefaults() throws -> UserDefaults {
        let name = "PracticePresetsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
