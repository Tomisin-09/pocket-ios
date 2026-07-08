import XCTest
import SwiftData
@testable import Pocket

/// `Routine` / `RoutineItem` model logic (ADR 0066, slice 1). Computed accessors,
/// factories, ordering and the orphan rule are exercised on plain in-memory `@Model`
/// objects; a real in-memory `ModelContainer` is used once to prove the models join the
/// schema (additive migration) and that the **nullify** delete rule (R5) holds — a
/// deleted unit clears the reference without deleting the routine.
final class RoutineModelTests: XCTestCase {

    // MARK: - Defaults / identity

    func testRoutineDefaults() {
        let routine = Routine()
        XCTAssertEqual(routine.name, "")
        XCTAssertTrue(routine.items.isEmpty)
        XCTAssertNotEqual(Routine().uid, Routine().uid)
    }

    func testItemDefaultsToAnInertRest() {
        let item = RoutineItem()
        XCTAssertEqual(item.kind, .rest)
        XCTAssertEqual(item.order, 0)
        XCTAssertFalse(item.hasResolvableUnit)
        XCTAssertNotEqual(RoutineItem().uid, RoutineItem().uid)
    }

    // MARK: - String-backed enum round-trip

    func testKindRoundTripsThroughRawAndFoldsGarbageToRest() {
        let item = RoutineItem()
        item.kind = .focused
        XCTAssertEqual(item.kindRaw, "focused")
        item.kindRaw = "not-a-kind"
        XCTAssertEqual(item.kind, .rest)
    }

    // MARK: - Factories keep the "exactly one unit" invariant

    func testExerciseFactorySetsOnlyTheExercise() {
        let drill = Exercise(name: "Spider")
        let item = RoutineItem.item(drill, order: 2)
        XCTAssertEqual(item.kind, .focused)
        XCTAssertEqual(item.order, 2)
        XCTAssertIdentical(item.exercise, drill)
        XCTAssertNil(item.loop)
        XCTAssertNil(item.song)
        XCTAssertTrue(item.hasResolvableUnit)
        XCTAssertFalse(item.isOrphaned)
    }

    func testSongFactoryDefaultsToAPlayRunThrough() {
        let song = Song(title: "Red Moon", duration: 200,
                        ref: SongRef(id: "x", source: .localFile, bookmark: nil))
        let item = RoutineItem.item(song)
        XCTAssertEqual(item.kind, .play)
        XCTAssertIdentical(item.song, song)
        XCTAssertNil(item.exercise)
    }

    func testRestFactoryCarriesNoUnitAndIsNeverOrphaned() {
        let item = RoutineItem.rest(order: 4)
        XCTAssertEqual(item.kind, .rest)
        XCTAssertEqual(item.order, 4)
        XCTAssertFalse(item.hasResolvableUnit)
        XCTAssertFalse(item.isOrphaned)
    }

    func testUnitBlockWithoutAUnitReadsAsOrphaned() {
        let item = RoutineItem(kind: .focused)
        XCTAssertFalse(item.hasResolvableUnit)
        XCTAssertTrue(item.isOrphaned)
    }

    // MARK: - Ordering (ADR 0066 R2 — explicit order, not array order)

    func testOrderedSortsByExplicitOrder() {
        let items = [RoutineItem(order: 2), RoutineItem(order: 0), RoutineItem(order: 1)]
        XCTAssertEqual(RoutineItem.ordered(items).map(\.order), [0, 1, 2])
    }

    func testOrderedTieBreakIsStableByUID() {
        let first = RoutineItem(order: 1)
        let second = RoutineItem(order: 1)
        let expected = [first, second].sorted { $0.uid.uuidString < $1.uid.uuidString }
        XCTAssertEqual(RoutineItem.ordered([second, first]).map(\.uid), expected.map(\.uid))
    }

    // MARK: - Schema join + nullify delete rule (ADR 0066 R5, additive migration)

    func testRoutinePersistsWithItemsInOneContainer() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        let routine = Routine(name: "Morning")
        routine.items = [RoutineItem.item(drill, order: 0)]
        context.insert(drill)
        context.insert(routine)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Routine>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.orderedItems.count, 1)
        XCTAssertEqual(fetched.first?.orderedItems.first?.exercise?.name, "Spider")
    }

    /// Deleting a referenced unit **nullifies** the block's link and leaves the routine
    /// (and its item) intact — the block simply becomes orphaned and is skipped.
    func testDeletingAReferencedExerciseNullifiesTheBlockNotTheRoutine() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        let routine = Routine(name: "Morning")
        routine.items = [RoutineItem.item(drill, order: 0)]
        context.insert(drill)
        context.insert(routine)
        try context.save()

        context.delete(drill)
        try context.save()

        let items = try context.fetch(FetchDescriptor<RoutineItem>())
        XCTAssertEqual(items.count, 1, "the routine item survives its unit's deletion")
        XCTAssertNil(items.first?.exercise, "the link is nullified, not cascaded")
        XCTAssertTrue(items.first?.isOrphaned == true)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Routine>()).first?.items.count, 1)
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, configurations: config)
        return ModelContext(container)
    }
}
