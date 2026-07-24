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
            + PracticePresets.makeExercises(PracticePresets.scaleLayoutSpecs)
            + PracticePresets.makeExercises(PracticePresets.strumExpansionSpecs)
            + PracticePresets.makeExercises(PracticePresets.scaleSequenceSpecs)
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

    // MARK: - Strumming expansion batch (pocket-170)

    func testStrumExpansionSpecsShipThreeStrummingExercises() {
        let exercises = PracticePresets.makeExercises(PracticePresets.strumExpansionSpecs)
        XCTAssertEqual(exercises.count, 3)
        for exercise in exercises {
            XCTAssertEqual(exercise.kind, .strumming)
            XCTAssertTrue(exercise.hasMeasuredCommand)
        }
        // Each ships its distinct curated pattern, in order.
        XCTAssertEqual(exercises.map(\.strumPattern),
                       [.downUpEighths, .offbeatUps, .boomChick])
    }

    // MARK: - Scale sequencing batch (pocket-173, ADR 0108)

    func testScaleSequenceSpecsShipASequencedScaleRun() {
        let exercises = PracticePresets.makeExercises(PracticePresets.scaleSequenceSpecs)
        XCTAssertEqual(exercises.count, 1)
        let scale = try? XCTUnwrap(exercises.first)
        XCTAssertEqual(scale?.kind, .fretboard)
        XCTAssertEqual(scale?.fretboardContent, .scale(.gMajorInThirds))
        XCTAssertEqual(scale?.fretboardContent?.scaleValue?.sequencePattern, .thirds)
        XCTAssertTrue(scale?.hasMeasuredCommand ?? false)
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
            + PracticePresets.scaleLayoutSpecs.count + PracticePresets.strumExpansionSpecs.count
            + PracticePresets.scaleSequenceSpecs.count
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
                       + PracticePresets.strumChordsSpecs.count + PracticePresets.scaleLayoutSpecs.count
                       + PracticePresets.strumExpansionSpecs.count
                       + PracticePresets.scaleSequenceSpecs.count)
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

    // MARK: - Preset provenance / slugs (ADR 0112)

    func testEveryPresetShipsWithANonEmptySlug() {
        for spec in PracticePresets.allSpecs {
            XCTAssertFalse(spec.slug.isEmpty, "\(spec.name) must ship with a slug")
        }
    }

    func testPresetSlugsAreUnique() {
        let slugs = PracticePresets.allSpecs.map(\.slug)
        XCTAssertEqual(Set(slugs).count, slugs.count, "preset slugs must be unique")
    }

    func testMakeExercisesStampsProvenanceSlug() {
        for (spec, exercise) in zip(PracticePresets.allSpecs,
                                    PracticePresets.makeExercises(PracticePresets.allSpecs)) {
            XCTAssertEqual(exercise.presetSlug, spec.slug, "\(spec.name) should carry its slug")
        }
    }

    /// Every free-taste slug the paywall relies on must actually be a shipped preset — guards the
    /// `AccessPolicy.freeTasteSlugs` ↔ `PracticePresets` contract so a rename can't silently orphan
    /// a freebie.
    func testEveryFreeTasteSlugIsAShippedPreset() {
        let shipped = Set(PracticePresets.allSpecs.map(\.slug))
        for slug in AccessPolicy.freeTasteSlugs {
            XCTAssertTrue(shipped.contains(slug), "free-taste slug \(slug) has no shipped preset")
        }
    }

    // MARK: - Provenance matcher + backfill

    func testSlugMatcherFindsAPresetByNameAndTemplate() {
        XCTAssertEqual(PracticePresets.slug(forName: "A Minor Pentatonic", template: .scales),
                       "a-minor-pentatonic")
        XCTAssertEqual(PracticePresets.slug(forName: "Legato", template: .legato), "legato")
    }

    func testSlugMatcherRejectsUnknownOrMismatchedTemplate() {
        XCTAssertNil(PracticePresets.slug(forName: "My Own Drill", template: .scales))
        // Right name, wrong template ⇒ no match (guards against a coincidental collision).
        XCTAssertNil(PracticePresets.slug(forName: "Legato", template: .scales))
    }

    /// The one-time backfill re-stamps presets that were seeded before the slug field existed:
    /// seed, wipe the slugs to simulate an old install, then backfill and confirm they return.
    func testBackfillReStampsSlugsForAPreSlugInstall() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Exercise.self, configurations: config)
        let context = ModelContext(container)
        let defaults = try freshDefaults()

        PracticePresets.seedIfNeeded(into: context, defaults: defaults)
        // Simulate a store seeded before provenance existed: clear every slug.
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) { exercise.presetSlug = nil }
        try context.save()

        PracticePresets.backfillPresetSlugsIfNeeded(into: context, defaults: defaults)

        let stamped = try context.fetch(FetchDescriptor<Exercise>())
            .filter { $0.presetSlug != nil }
        // Every seeded preset name is unique + matches a spec, so all should be re-stamped.
        XCTAssertEqual(stamped.count, PracticePresets.makeExercises(PracticePresets.allSpecs).count)
        let pentatonic = try context.fetch(FetchDescriptor<Exercise>())
            .first { $0.name == "A Minor Pentatonic" }
        XCTAssertEqual(pentatonic?.presetSlug, "a-minor-pentatonic")
    }

    func testBackfillLeavesUserAuthoredDrillsUntouched() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Exercise.self, configurations: config)
        let context = ModelContext(container)
        let defaults = try freshDefaults()

        let mine = Exercise(name: "My Own Drill", template: .scales)
        context.insert(mine)
        try context.save()

        PracticePresets.backfillPresetSlugsIfNeeded(into: context, defaults: defaults)
        XCTAssertNil(mine.presetSlug, "a user-authored drill must never be stamped as a preset")
    }

    func testBackfillRunsAtMostOnce() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Exercise.self, configurations: config)
        let context = ModelContext(container)
        let defaults = try freshDefaults()

        PracticePresets.backfillPresetSlugsIfNeeded(into: context, defaults: defaults)
        // A preset seeded *after* the backfill already ran (slug wiped) must NOT be re-stamped,
        // because the guard flag is set — proving the backfill is one-shot.
        let late = Exercise(name: "Legato", template: .legato)
        late.presetSlug = nil
        context.insert(late)
        try context.save()

        PracticePresets.backfillPresetSlugsIfNeeded(into: context, defaults: defaults)
        XCTAssertNil(late.presetSlug, "backfill must not run a second time")
    }

    /// A throwaway `UserDefaults` suite so the seed flag never touches the real domain.
    private func freshDefaults() throws -> UserDefaults {
        let name = "PracticePresetsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
