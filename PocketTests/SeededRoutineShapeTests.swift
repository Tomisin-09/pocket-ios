import SwiftData
import XCTest
@testable import Pocket

/// The shapes `PracticeHistorySeed+Authored` writes, pinned (ADR 0165, Phase 5).
///
/// **Why a seed gets a test at all.** It is DEBUG-only fixture code that ships to nobody, which is
/// exactly the argument for not testing it — and exactly why it needs this. Its whole output is
/// *photographs*: a seed that writes one block where it meant to write two produces a figure that is
/// wrong in the manual and correct-looking in every check the shoot runs, because the run asserts
/// what screen it is on and never what the store holds. The first shoot of `routines/library` showed
/// `1 block` on a routine this code appends a rest to, and there was no cheaper way to find out
/// which of the two was lying than to ask the model directly.
///
/// **The first version of this file passed while the seed was wrong, and the reason is the lesson.**
/// The first shoot filed a `Blues, week three` row reading `1 block` for a routine the seed gives an
/// exercise, a rest and a loop. These tests agreed with the seed because they *created the exercises
/// themselves*, by the names the seed asked for — so they proved the resolution logic and assumed
/// away the only question that mattered: whether a fresh install actually holds a drill by that
/// name. It does not. `Scale Runs` is in `PracticePresets.allSpecs` and not in the six of
/// `firstRunSlugs`, the lookup returned nil, and a `guard … else { continue }` dropped the block in
/// silence.
///
/// A fixture that supplies its own preconditions cannot test a claim about the world. So
/// `testSeededRoutinesNameOnlyDrillsAFreshInstallHas` reads `firstRunSlugs` instead of inventing
/// drills, and it is the one here that would have failed.
///
/// In-memory container with individual inserts, per the project's test-host trap note.
final class SeededRoutineShapeTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, LongTermGoal.self, configurations: config)
        return ModelContext(container)
    }

    /// A drill carrying its **frozen slug**, which is what the seed resolves on.
    @discardableResult
    private func drill(slug: String, into context: ModelContext) -> Exercise {
        let spec = PracticePresets.allSpecs.first { $0.slug == slug }
        let exercise = Exercise(name: spec?.name ?? slug)
        exercise.presetSlug = slug
        context.insert(exercise)
        return exercise
    }

    /// **The test that would have caught it.** Every slug the routine seed names has to be one a
    /// fresh install actually seeds — not merely one that exists in the catalog. Reads
    /// `firstRunSlugs` rather than restating it, so retiring a spec from the first-run six fails
    /// here instead of in a photograph.
    func testSeededRoutinesNameOnlyDrillsAFreshInstallHas() {
        let named = ["spider-walk", "alternate-picking", "a-minor-pentatonic"]
        for slug in named {
            XCTAssertTrue(PracticePresets.firstRunSlugs.contains(slug),
                          "the routine seed names '\(slug)', which a fresh install does not seed — "
                          + "the block is dropped silently and the figure is wrong")
        }
    }

    @MainActor
    func testSeededRoutinesCarryTheBlocksAndRestsTheyClaim() throws {
        let context = try makeContext()
        for spec in PracticePresets.firstRunSpecs {
            let exercise = Exercise(name: spec.name)
            exercise.presetSlug = spec.slug
            context.insert(exercise)
        }
        let song = Song(title: "Any Song", duration: 100,
                        ref: SongRef(id: "any-song", source: .localFile, bookmark: nil))
        context.insert(song)
        let loop = Loop(name: "Solo", start: 0.1, end: 0.4, speed: 1, repeats: 1)
        loop.song = song
        context.insert(loop)
        try context.save()

        PracticeHistorySeed.seedRoutines(exercises: try context.fetch(FetchDescriptor<Exercise>()),
                                         loops: try context.fetch(FetchDescriptor<Loop>()),
                                         into: context)
        try context.save()

        let routines = try context.fetch(FetchDescriptor<Routine>())
        XCTAssertEqual(routines.count, 2, "both seeded routines should land")

        let evening = try XCTUnwrap(routines.first { $0.name == "Evening technique" })
        XCTAssertEqual(evening.items.filter(\.kind.carriesUnit).count, 2)
        XCTAssertEqual(evening.items.filter { !$0.kind.carriesUnit }.count, 0,
                       "a routine asking for no loop gets no rest either")

        // The one the shoot disagreed with. A rest and a loop block, so the row reads
        // "2 blocks · 1 rest" — the only non-preset routine that exercises the rests half of it.
        let blues = try XCTUnwrap(routines.first { $0.name == "Blues, week three" })
        XCTAssertEqual(blues.items.filter(\.kind.carriesUnit).count, 2,
                       "one exercise and one loop")
        XCTAssertEqual(blues.items.filter { !$0.kind.carriesUnit }.count, 1,
                       "the rest between them")
    }

    /// The guard that stops the seed topping up a library that already holds these names — a second
    /// launch must not produce six routines where the figure was composed around three.
    @MainActor
    func testSeedingTwiceLeavesTheLibraryAlone() throws {
        let context = try makeContext()
        for slug in PracticePresets.firstRunSlugs { drill(slug: slug, into: context) }
        try context.save()

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        PracticeHistorySeed.seedRoutines(exercises: exercises, loops: [], into: context)
        try context.save()
        let after = try context.fetchCount(FetchDescriptor<Routine>())

        PracticeHistorySeed.seedRoutines(exercises: exercises, loops: [], into: context)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Routine>()), after,
                       "a second pass must not duplicate the seeded routines")
    }

    /// Both long-term goals land, ranked contiguously from zero, with the Path-B one pointing at its
    /// song — the shape `reference/long-term-goals` is a photograph of.
    @MainActor
    func testSeededGoalsAreRankedAndOneTargetsItsSong() throws {
        let context = try makeContext()
        // Titled from `Song.sample()` rather than by hand. `seedLongTermGoals` finds its target
        // song by matching that title, so a fixture inventing its own would agree with the seed
        // no matter what the demo song is actually called — and the rename that desyncs them
        // would leave the goal with no target and this test still green. Deriving it here is
        // what makes the assertion below a claim about the app instead of about itself.
        let song = Song(title: Song.sample().title, duration: 100,
                        ref: SongRef(id: "demo-song", source: .localFile, bookmark: nil))
        context.insert(song)
        try context.save()

        PracticeHistorySeed.seedLongTermGoals(songs: try context.fetch(FetchDescriptor<Song>()),
                                              into: context)
        try context.save()

        let goals = try context.fetch(FetchDescriptor<LongTermGoal>()).sorted { $0.order < $1.order }
        XCTAssertEqual(goals.map(\.order), [0, 1], "ranks are contiguous from zero")
        XCTAssertNil(goals[0].targetSong, "rank 1 is the skills-only shape")
        XCTAssertEqual(goals[1].targetSong?.title, Song.sample().title,
                       "the seed's title lookup has drifted from the demo song")
        // Every id resolves, or the row's skill count is quietly one short in the photograph.
        for goal in goals {
            XCTAssertFalse(goal.skillIDs.isEmpty)
            for id in goal.skillIDs {
                XCTAssertNotNil(TechniqueTaxonomy.info(id), "unknown skill id '\(id)' in the seed")
            }
        }
    }
}
