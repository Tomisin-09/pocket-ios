import SwiftData
import XCTest
@testable import Pocket

/// The pure "build a routine for this song" generator (ADR 0111) — the producer behind the
/// SongDetailsSheet action. Exercised through an in-memory `ModelContainer` (individual inserts, per
/// the project's test-host trap note) so the ADR-0111 relationship and the song's loops resolve; the
/// blocks themselves are pure `SessionBlock`s and asserted directly.
final class SongRoutineBuilderTests: XCTestCase {

    func testCanBuildRequiresAtLeastOneExerciseOrLoop() throws {
        let context = try makeContext()
        let song = makeSong("Bare", into: context)
        try context.save()
        XCTAssertFalse(SongRoutineBuilder.canBuild(for: song), "no exercises and no loops → cannot build")

        let drill = Exercise(name: "Picking")
        context.insert(drill)
        song.linkedExercises = [drill]
        try context.save()
        XCTAssertTrue(SongRoutineBuilder.canBuild(for: song), "a linked exercise is enough")
    }

    func testCanBuildOnLoopsAloneWithNoLinkedExercises() throws {
        let context = try makeContext()
        let song = makeSong("Loopy", into: context)
        addLoop(to: song, name: "Chorus", start: 0.5, into: context)
        try context.save()
        XCTAssertTrue(SongRoutineBuilder.canBuild(for: song), "loops alone can build a routine")
    }

    func testBlocksAreExercisesThenLoopsThenPlay() throws {
        let context = try makeContext()
        let song = makeSong("Cliffs", into: context)
        // Insert exercises out of alphabetical order to prove the builder sorts them by name.
        let legato = Exercise(name: "Legato")
        let alt = Exercise(name: "Alt picking")
        [legato, alt].forEach(context.insert)
        song.linkedExercises = [legato, alt]
        // Insert loops out of start order to prove the builder sorts them by start.
        addLoop(to: song, name: "Solo", start: 0.8, into: context)
        addLoop(to: song, name: "Intro", start: 0.1, into: context)
        try context.save()

        let blocks = SongRoutineBuilder.sessionBlocks(for: song)
        XCTAssertEqual(blocks.count, 5, "2 exercises + 2 loops + 1 play")

        // Exercises first, sorted by name; every exercise/loop is a focused block.
        XCTAssertEqual(blocks[0].kind, .focused)
        XCTAssertEqual(blocks[0].unit, PlannerUnitRef(alt.uid, .exercise))
        XCTAssertEqual(blocks[1].unit, PlannerUnitRef(legato.uid, .exercise))

        // Then loops, sorted by start.
        XCTAssertEqual(blocks[2].kind, .focused)
        XCTAssertEqual(blocks[2].unit?.kind, .loop)
        XCTAssertEqual(blocks[3].unit?.kind, .loop)
        XCTAssertEqual(song.loopsByStart.map(\.uid), [blocks[2].unit?.uid, blocks[3].unit?.uid].compactMap { $0 })

        // The play-through trails, referencing the song by its planner id.
        XCTAssertEqual(blocks[4].kind, .play)
        XCTAssertEqual(blocks[4].unit, PlannerUnitRef(PlannerID.uid(from: song.sourceID), .song))
    }

    func testBlocksResolveToRoutineItemsInOrderViaMaterialise() throws {
        let context = try makeContext()
        let song = makeSong("Doomed", into: context)
        let drill = Exercise(name: "Spider")
        context.insert(drill)
        song.linkedExercises = [drill]
        addLoop(to: song, name: "Riff", start: 0.3, into: context)
        try context.save()

        // The whole point: the blocks feed the existing materialiser and become real ordered items.
        let blocks = SongRoutineBuilder.sessionBlocks(for: song)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let loops = try context.fetch(FetchDescriptor<Loop>())
        let songs = try context.fetch(FetchDescriptor<Song>())
        let routine = PracticePlanner.materialise(blocks, name: SongRoutineBuilder.defaultName(for: song),
                                                  exercises: exercises, loops: loops, songs: songs,
                                                  into: context)

        let items = routine.orderedItems
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].exercise?.name, "Spider")
        XCTAssertNotNil(items[1].loop)
        XCTAssertEqual(items[2].song?.title, "Doomed")
        XCTAssertEqual(routine.name, "Doomed practice")
    }

    // MARK: - Helpers

    private func makeSong(_ title: String, into context: ModelContext) -> Song {
        let song = Song(title: title, duration: 180,
                        ref: SongRef(id: title, source: .localFile, bookmark: nil))
        context.insert(song)
        return song
    }

    private func addLoop(to song: Song, name: String, start: Double, into context: ModelContext) {
        let loop = Loop(name: name, start: start, end: min(1, start + 0.1), speed: 1, repeats: 1)
        context.insert(loop)
        loop.song = song
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, configurations: config)
        return ModelContext(container)
    }
}
