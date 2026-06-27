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
        }
    }

    // MARK: - Seed-once guard

    func testSeedIfNeededInsertsTheSetOnceThenIsIdempotent() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Exercise.self, configurations: config)
        let context = ModelContext(container)
        let defaults = try freshDefaults()

        PracticePresets.seedIfNeeded(into: context, defaults: defaults)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 6)

        // A second call must not duplicate — the flag is set.
        PracticePresets.seedIfNeeded(into: context, defaults: defaults)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 6)
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
