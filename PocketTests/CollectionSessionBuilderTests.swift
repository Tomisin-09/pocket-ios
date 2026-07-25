import SwiftData
import XCTest
@testable import Pocket

/// The pure "build a session from a collection" generator (ADR 0118) — the producer behind the
/// filtered-Library banner. Exercised through an in-memory `ModelContainer` (individual inserts, per
/// the project's test-host trap note) so the ADR-0111 links and song loops resolve; the emitted
/// blocks are pure `SessionBlock`s and asserted directly. Covers dedup, budget sizing, order
/// determinism per mode, the play-through cap, and `canBuild`.
final class CollectionSessionBuilderTests: XCTestCase {

    // MARK: canBuild

    func testCanBuildRequiresALinkedExerciseOrLoopSomewhereInTheCollection() throws {
        let context = try makeContext()
        let bare = makeSong("Bare", collections: ["set"], into: context)
        try context.save()
        XCTAssertFalse(CollectionSessionBuilder.canBuild(for: "set", in: [bare]),
                       "a collection whose songs have no links can't build")

        let drill = Exercise(name: "Picking")
        context.insert(drill)
        bare.linkedExercises = [drill]
        try context.save()
        XCTAssertTrue(CollectionSessionBuilder.canBuild(for: "set", in: [bare]),
                      "one linked exercise anywhere in the collection is enough")
    }

    func testCanBuildIgnoresSongsOutsideTheCollection() throws {
        let context = try makeContext()
        let inSet = makeSong("In", collections: ["set"], into: context)
        let other = makeSong("Out", collections: ["other"], into: context)
        let drill = Exercise(name: "Legato")
        context.insert(drill)
        other.linkedExercises = [drill]
        try context.save()
        XCTAssertFalse(CollectionSessionBuilder.canBuild(for: "set", in: [inSet, other]),
                       "a link on a song outside the collection doesn't count")
    }

    // MARK: Dedup

    func testExerciseSharedAcrossSongsIsDedupedByUid() throws {
        let context = try makeContext()
        let songA = makeSong("A", collections: ["set"], into: context)
        let songB = makeSong("B", collections: ["set"], into: context)
        let shared = Exercise(name: "Spider")
        context.insert(shared)
        songA.linkedExercises = [shared]
        songB.linkedExercises = [shared]
        try context.save()

        var generator = SeededGenerator(seed: 1)
        let units = CollectionSessionBuilder.orderedFocusUnits(from: [songA, songB],
                                                               order: .structured, using: &generator)
        XCTAssertEqual(units.filter { $0.ref == PlannerUnitRef(shared.uid, .exercise) }.count, 1,
                       "a drill linked to two songs warms the set up once")
    }

    // MARK: Sizing

    func testFocusBlocksAreSizedToTheLengthBudget() throws {
        let context = try makeContext()
        let song = makeSong("Big", collections: ["set"], into: context)
        // Six 12-minute drills — more than any preset's budget can hold, so sizing must clamp.
        song.linkedExercises = (0..<6).map { Exercise(name: "Drill \($0)") }
        song.linkedExercises.forEach(context.insert)
        try context.save()

        for length in SessionLength.allCases {
            let blocks = CollectionSessionBuilder.sessionBlocks(for: "set", in: [song],
                                                                length: length, order: .structured, seed: 7)
            let focusedMinutes = blocks.filter { $0.kind == .focused }.reduce(0) { $0 + $1.minutes }
            XCTAssertEqual(focusedMinutes, length.minutes,
                           "\(length.displayName) fills exactly its focused budget when units overflow")
            XCTAssertLessThanOrEqual(focusedMinutes, SessionBuilder.maxSessionMinutes,
                                     "never past the 60-minute ceiling")
        }
    }

    // MARK: Order — structured is the deterministic arc

    func testStructuredOrderIsExercisesByNameThenLoopsThenPlay() throws {
        let context = try makeContext()
        let song = makeSong("Song", collections: ["set"], into: context)
        let legato = Exercise(name: "Legato")
        let alt = Exercise(name: "Alt picking")
        [legato, alt].forEach(context.insert)
        song.linkedExercises = [legato, alt]
        addLoop(to: song, name: "Solo", start: 0.8, into: context)
        try context.save()

        // Full budget (60) holds all three focus units (36 min), so nothing is trimmed.
        let blocks = CollectionSessionBuilder.sessionBlocks(for: "set", in: [song],
                                                            length: .full, order: .structured, seed: 3)
        let units = blocks.compactMap { block -> PlannerUnitRef? in
            block.kind == .rest ? nil : block.unit
        }
        let loopUid = try XCTUnwrap(song.loops.first?.uid)
        XCTAssertEqual(units, [
            PlannerUnitRef(alt.uid, .exercise),        // exercises by name: "Alt picking" < "Legato"
            PlannerUnitRef(legato.uid, .exercise),
            PlannerUnitRef(loopUid, .loop),
            PlannerUnitRef(PlannerID.uid(from: song.sourceID), .song)
        ])
    }

    func testAdjacentFocusBlocksAreRestPunctuated() throws {
        let context = try makeContext()
        let song = makeSong("Rests", collections: ["set"], into: context)
        let one = Exercise(name: "A")
        let two = Exercise(name: "B")
        [one, two].forEach(context.insert)
        song.linkedExercises = [one, two]
        try context.save()

        let blocks = CollectionSessionBuilder.sessionBlocks(for: "set", in: [song],
                                                            length: .full, order: .structured, seed: 1)
        // exercise, rest, exercise, play — a rest threads the two adjacent focus blocks.
        XCTAssertEqual(blocks.map(\.kind), [.focused, .rest, .focused, .play])
    }

    // MARK: Order — shuffled is seeded / deterministic

    func testShuffledIsDeterministicForAGivenSeed() throws {
        let context = try makeContext()
        let song = makeSong("Shuf", collections: ["set"], into: context)
        song.linkedExercises = (0..<4).map { Exercise(name: "Drill \($0)") }
        song.linkedExercises.forEach(context.insert)
        addLoop(to: song, name: "Riff", start: 0.2, into: context)
        try context.save()

        let first = CollectionSessionBuilder.sessionBlocks(for: "set", in: [song],
                                                           length: .full, order: .shuffled, seed: 42)
        let again = CollectionSessionBuilder.sessionBlocks(for: "set", in: [song],
                                                           length: .full, order: .shuffled, seed: 42)
        XCTAssertEqual(first, again, "same seed → identical session (pure, testable)")
    }

    // MARK: Play-through cap

    func testPlayThroughsAreCappedByLength() throws {
        let context = try makeContext()
        // Five songs each with a drill, so play-throughs would otherwise number five.
        let songs = (0..<5).map { index -> Song in
            let song = makeSong("Song \(index)", collections: ["set"], into: context)
            let drill = Exercise(name: "Drill \(index)")
            context.insert(drill)
            song.linkedExercises = [drill]
            return song
        }
        try context.save()

        for length in SessionLength.allCases {
            let blocks = CollectionSessionBuilder.sessionBlocks(for: "set", in: songs,
                                                                length: length, order: .structured, seed: 5)
            let plays = blocks.filter { $0.kind == .play }.count
            XCTAssertLessThanOrEqual(plays, CollectionSessionBuilder.playThroughCap(for: length),
                                     "\(length.displayName) caps trailing play-throughs")
        }
    }

    func testBlocksMaterialiseIntoOrderedRoutineItems() throws {
        let context = try makeContext()
        let song = makeSong("Doomed", collections: ["set"], into: context)
        let drill = Exercise(name: "Spider")
        context.insert(drill)
        song.linkedExercises = [drill]
        addLoop(to: song, name: "Riff", start: 0.3, into: context)
        try context.save()

        let blocks = CollectionSessionBuilder.sessionBlocks(for: "set", in: [song],
                                                            length: .full, order: .structured, seed: 1)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let loops = try context.fetch(FetchDescriptor<Loop>())
        let allSongs = try context.fetch(FetchDescriptor<Song>())
        let routine = PracticePlanner.materialise(
            blocks, name: CollectionSessionBuilder.defaultName(for: "set"),
            exercises: exercises, loops: loops, songs: allSongs, into: context)

        // exercise, loop, play → 3 unit-bearing items (rests carry no unit and aren't materialised
        // between non-adjacent focus blocks here).
        let unitItems = routine.orderedItems.filter { $0.kind != .rest }
        XCTAssertEqual(unitItems.count, 3)
        XCTAssertEqual(routine.name, "set session")
    }

    // MARK: - Helpers

    private func makeSong(_ title: String, collections: [String], into context: ModelContext) -> Song {
        let song = Song(title: title, duration: 180,
                        ref: SongRef(id: title, source: .localFile, bookmark: nil))
        song.collections = collections
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
