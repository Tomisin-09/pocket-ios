import SwiftData
import XCTest
@testable import Pocket

/// `ReferenceLink` (ADR 0167): the four typed owners, the **cascade** delete rule that is the
/// opposite of notes and takes, and the ordering discipline. The cascade tests run against a real
/// in-memory `ModelContainer` because a delete rule is a schema fact — asserting it on plain
/// `@Model` objects would test nothing.
final class ReferenceLinkTests: XCTestCase {

    // MARK: - Derived reads

    func testKindRoundTripsThroughItsStringBacking() {
        let link = ReferenceLink(kind: .image)
        XCTAssertEqual(link.kindRaw, "image")
        XCTAssertEqual(link.kind, .image)
        link.kind = .link
        XCTAssertEqual(link.kindRaw, "link")
    }

    /// A store written by a newer build must stay openable by an older one, so an unknown kind
    /// reads as a plain link rather than trapping.
    func testUnknownKindReadsAsLink() {
        let link = ReferenceLink()
        link.kindRaw = "hologram"
        XCTAssertEqual(link.kind, .link)
    }

    func testDisplayTitlePrefersTheTypedTitle() {
        let link = ReferenceLink(title: "CAGED part 2", urlString: "https://youtube.com/watch?v=x")
        XCTAssertEqual(link.displayTitle, "CAGED part 2")
    }

    /// Saving without naming it is allowed on purpose — the row falls back to the site, because a
    /// link with no name is still a place.
    func testDisplayTitleFallsBackToTheHost() {
        let link = ReferenceLink(title: "   ", urlString: "https://www.youtube.com/watch?v=x")
        XCTAssertEqual(link.displayTitle, "youtube.com")
    }

    func testDisplayTitleFallsBackToTheRawStringWhenThereIsNoHost() {
        let link = ReferenceLink(title: "", urlString: "not a url")
        XCTAssertEqual(link.displayTitle, "not a url")
    }

    // MARK: - Ordering

    func testOrderedSortsByOrderThenUID() {
        let first = ReferenceLink(order: 0)
        let second = ReferenceLink(order: 1)
        let third = ReferenceLink(order: 2)
        XCTAssertEqual(ReferenceLink.ordered([third, first, second]).map(\.order), [0, 1, 2])
    }

    /// Ties must resolve the same way on every read, or a list jitters between renders.
    func testOrderedIsStableAcrossReadsWhenOrdersCollide() {
        let links = (0..<5).map { _ in ReferenceLink(order: 0) }
        let once = ReferenceLink.ordered(links).map(\.uid)
        let again = ReferenceLink.ordered(links.reversed()).map(\.uid)
        XCTAssertEqual(once, again)
    }

    func testRenumberClosesTheHoleLeftByADelete() {
        let kept = [ReferenceLink(order: 0), ReferenceLink(order: 2), ReferenceLink(order: 5)]
        ReferenceLink.renumber(kept)
        XCTAssertEqual(ReferenceLink.ordered(kept).map(\.order), [0, 1, 2])
    }

    func testNextOrderLandsAfterTheHighestExisting() {
        XCTAssertEqual(ReferenceLink.nextOrder(after: []), 0)
        XCTAssertEqual(ReferenceLink.nextOrder(after: [ReferenceLink(order: 0),
                                                       ReferenceLink(order: 4)]), 5)
    }

    // MARK: - Owners

    func testEachOwnerMakesALinkPointedAtItself() {
        let exercise = Exercise(name: "Spider")
        let routine = Routine(name: "Morning warm-up")
        XCTAssertIdentical(exercise.makeReference().exercise, exercise)
        XCTAssertNil(exercise.makeReference().routine)
        XCTAssertIdentical(routine.makeReference().routine, routine)
        XCTAssertNil(routine.makeReference().exercise)
    }

    // MARK: - The gate, at the one place that writes

    func testAddRefusesADisallowedSchemeAndInsertsNothing() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)

        XCTAssertNil(ReferenceLinkStore.add(title: "Nope", url: "javascript:alert(1)",
                                            to: exercise, in: context))
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<ReferenceLink>()).isEmpty)
    }

    func testAddStoresTheNormalisedURLNotTheRawString() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)

        let link = try XCTUnwrap(ReferenceLinkStore.add(title: "  Lesson  ",
                                                        url: "  youtube.com/watch?v=x ",
                                                        to: exercise, in: context))
        try context.save()
        XCTAssertEqual(link.urlString, "https://youtube.com/watch?v=x")
        XCTAssertEqual(link.title, "Lesson")
    }

    func testAddAppendsInOrder() throws {
        let context = try makeContext()
        let routine = Routine(name: "Week 3")
        context.insert(routine)

        for index in 0..<3 {
            ReferenceLinkStore.add(title: "Link \(index)", url: "https://example.com/\(index)",
                                   to: routine, in: context)
        }
        try context.save()
        XCTAssertEqual(routine.referencesInOrder.map(\.title), ["Link 0", "Link 1", "Link 2"])
        XCTAssertEqual(routine.referencesInOrder.map(\.order), [0, 1, 2])
    }

    /// A rejected edit must leave the link exactly as it was, not half-apply the new title.
    func testUpdateLeavesTheLinkUntouchedWhenTheURLIsRefused() {
        let link = ReferenceLink(title: "Original", urlString: "https://example.com/a")
        XCTAssertFalse(ReferenceLinkStore.update(link, title: "Changed", url: "mailto:x@y.com"))
        XCTAssertEqual(link.title, "Original")
        XCTAssertEqual(link.urlString, "https://example.com/a")
    }

    func testDeleteRenumbersTheSurvivors() throws {
        let context = try makeContext()
        let song = makeSong("Little Wing")
        context.insert(song)
        for index in 0..<4 {
            ReferenceLinkStore.add(title: "Link \(index)", url: "https://example.com/\(index)",
                                   to: song, in: context)
        }
        try context.save()

        let doomed = song.referencesInOrder[1]
        ReferenceLinkStore.delete([doomed], from: song, in: context)
        try context.save()
        XCTAssertEqual(song.referencesInOrder.map(\.title), ["Link 0", "Link 2", "Link 3"])
        XCTAssertEqual(song.referencesInOrder.map(\.order), [0, 1, 2])
    }

    func testMoveRenumbersIntoTheNewOrder() throws {
        let context = try makeContext()
        let routine = Routine(name: "Week 3")
        context.insert(routine)
        for index in 0..<3 {
            ReferenceLinkStore.add(title: "Link \(index)", url: "https://example.com/\(index)",
                                   to: routine, in: context)
        }
        try context.save()

        ReferenceLinkStore.move(from: IndexSet(integer: 2), to: 0, in: routine)
        XCTAssertEqual(routine.referencesInOrder.map(\.title), ["Link 2", "Link 0", "Link 1"])
        XCTAssertEqual(routine.referencesInOrder.map(\.order), [0, 1, 2])
    }

    // MARK: - The cascade (⚠ the opposite of ADR 0151's nullify)

    func testDeletingAnExerciseDeletesItsReferences() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)
        ReferenceLinkStore.add(title: "Lesson", url: "https://example.com/a",
                               to: exercise, in: context)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReferenceLink>()).count, 1)

        context.delete(exercise)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<ReferenceLink>()).isEmpty)
    }

    func testDeletingARoutineDeletesItsReferences() throws {
        let context = try makeContext()
        let routine = Routine(name: "Week 3")
        context.insert(routine)
        ReferenceLinkStore.add(title: "Course", url: "https://example.com/course",
                               to: routine, in: context)
        try context.save()

        context.delete(routine)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<ReferenceLink>()).isEmpty)
    }

    /// A song cascades to its loops already; a loop's own references must go with it rather than
    /// surviving as orphans pointing at a region nobody can play.
    func testDeletingASongDeletesBothItsOwnAndItsLoopsReferences() throws {
        let context = try makeContext()
        let song = makeSong("Little Wing")
        let loop = Loop(name: "Verse riff", start: 0.1, end: 0.2, speed: 1.0, repeats: 4)
        loop.song = song
        context.insert(song)
        context.insert(loop)
        ReferenceLinkStore.add(title: "Transcription", url: "https://example.com/song",
                               to: song, in: context)
        ReferenceLinkStore.add(title: "That lick, slowed", url: "https://example.com/loop",
                               to: loop, in: context)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReferenceLink>()).count, 2)

        context.delete(song)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<ReferenceLink>()).isEmpty)
    }

    // MARK: - Helpers

    private func makeSong(_ title: String) -> Song {
        Song(title: title, duration: 180,
             ref: SongRef(id: title, source: .localFile, bookmark: nil))
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, ReferenceLink.self, configurations: config)
        return ModelContext(container)
    }
}
