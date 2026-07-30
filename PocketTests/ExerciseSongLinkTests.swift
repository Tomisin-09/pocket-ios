import SwiftData
import XCTest
@testable import Pocket

/// The direct `Exercise` ↔ `Song` repertoire edge (ADR 0111) — the store's first many-to-many.
/// Exercised through a real in-memory `ModelContainer` (not plain `@Model` objects) because the
/// point under test is the *join*: that the inverse populates both ways and that deletes nullify
/// membership without cascading to the counterpart. Mirrors `RoutineModelTests`' schema-join tests.
final class ExerciseSongLinkTests: XCTestCase {

    func testLinkPopulatesBothSidesOfTheInverse() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Alternating picking")
        let song = makeSong("Cliffs of Dover")
        drill.linkedSongs = [song]
        context.insert(drill)
        context.insert(song)
        try context.save()

        // Setting one side populates the inverse automatically.
        let fetchedSong = try XCTUnwrap(context.fetch(FetchDescriptor<Song>()).first)
        XCTAssertEqual(fetchedSong.linkedExercises.map(\.name), ["Alternating picking"])
        let fetchedDrill = try XCTUnwrap(context.fetch(FetchDescriptor<Exercise>()).first)
        XCTAssertEqual(fetchedDrill.linkedSongs.map(\.title), ["Cliffs of Dover"])
    }

    func testManyToManyLinksMultipleSongsAndExercises() throws {
        let context = try makeContext()
        let picking = Exercise(name: "Picking")
        let legato = Exercise(name: "Legato")
        let songA = makeSong("Song A")
        let songB = makeSong("Song B")
        picking.linkedSongs = [songA, songB]
        legato.linkedSongs = [songA]
        [picking, legato].forEach(context.insert)
        [songA, songB].forEach(context.insert)
        try context.save()

        // Song A is served by both drills; Song B only by picking — a true many-to-many.
        let a = try fetchSong("Song A", in: context)
        XCTAssertEqual(Set(a.linkedExercises.map(\.name)), ["Picking", "Legato"])
        let b = try fetchSong("Song B", in: context)
        XCTAssertEqual(b.linkedExercises.map(\.name), ["Picking"])
    }

    /// The **creation-sheet** ordering (ADR 0111 follow-up): the songs come from a `@Query`, so they
    /// are already stored, while the drill is brand new. Both hosts therefore `insert` the exercise
    /// *first* and assign `linkedSongs` after — the reverse of the tests above, which link two
    /// not-yet-inserted objects. Pins that the inverse still populates in this direction, since a
    /// silent no-op here would look exactly like "the picker didn't save".
    func testAttachingStoredSongsAfterInsertingTheExerciseLinksBothWays() throws {
        let context = try makeContext()
        let song = makeSong("Little Wing")
        context.insert(song)
        try context.save()

        let drill = Exercise(name: "Thumb-over changes")
        context.insert(drill)
        drill.linkedSongs = [song]
        try context.save()

        let fetchedDrill = try XCTUnwrap(context.fetch(FetchDescriptor<Exercise>()).first)
        XCTAssertEqual(fetchedDrill.linkedSongs.map(\.title), ["Little Wing"])
        let fetchedSong = try fetchSong("Little Wing", in: context)
        XCTAssertEqual(fetchedSong.linkedExercises.map(\.name), ["Thumb-over changes"])
    }

    func testDeletingASongNullifiesTheEdgeNotTheExercise() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        let song = makeSong("Doomed")
        drill.linkedSongs = [song]
        context.insert(drill)
        context.insert(song)
        try context.save()

        context.delete(song)
        try context.save()

        let drills = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(drills.count, 1, "the exercise survives its linked song's deletion")
        XCTAssertTrue(drills.first?.linkedSongs.isEmpty == true, "the edge is nullified, not cascaded")
    }

    func testDeletingAnExerciseNullifiesTheEdgeNotTheSong() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        let song = makeSong("Doomed")
        song.linkedExercises = [drill]
        context.insert(drill)
        context.insert(song)
        try context.save()

        context.delete(drill)
        try context.save()

        let songs = try context.fetch(FetchDescriptor<Song>())
        XCTAssertEqual(songs.count, 1, "the song survives its linked exercise's deletion")
        XCTAssertTrue(songs.first?.linkedExercises.isEmpty == true, "the edge is nullified, not cascaded")
    }

    // MARK: - Helpers

    private func makeSong(_ title: String) -> Song {
        Song(title: title, duration: 100, ref: SongRef(id: title, source: .localFile, bookmark: nil))
    }

    private func fetchSong(_ title: String, in context: ModelContext) throws -> Song {
        let all = try context.fetch(FetchDescriptor<Song>())
        return try XCTUnwrap(all.first { $0.title == title })
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, configurations: config)
        return ModelContext(container)
    }
}
