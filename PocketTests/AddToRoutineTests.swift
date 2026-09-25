import XCTest
import SwiftData
@testable import Pocket

/// **Add to routine…** from a drill's or loop's own row (ADR 0222), and the pieces it shares with
/// the routine editor's picker: which block a pick makes, where an append lands, and how a take-back
/// closes the gap.
///
/// The mapping and ordering rules run on plain uninserted models. The append and the take-back run
/// against a real in-memory store and are read back through a **second** context, because that is
/// the claim the sheet rests on — the routine editor opens each routine in a fresh `ModelContext`,
/// so an append that only reached the main context would be invisible to it.
final class AddToRoutineTests: XCTestCase {

    // MARK: - Which block a pick makes

    /// Each mode maps to its own pick, and each pick to the block the editor's dedicated factory
    /// makes — so a loop added as ear training from its row is the editor's Ear training block.
    func testEachLoopModeMakesTheBlockItsEditorBucketMakes() {
        let loop = Loop(name: "Riff", start: 0.1, end: 0.2, speed: 1, repeats: 4)
        for mode in LoopRunMode.allCases {
            let block = RoutineUnitPick.loop(loop, as: mode).block(order: 3)
            XCTAssertIdentical(block.loop, loop, "\(mode)")
            XCTAssertEqual(block.loopRunMode, mode)
            XCTAssertEqual(block.order, 3)
        }
        XCTAssertEqual(RoutineUnitPick.loop(loop, as: .trainer).block(order: 0).kind,
                       RoutineItem.item(loop).kind)
        XCTAssertEqual(RoutineUnitPick.loop(loop, as: .ear).block(order: 0).kind,
                       RoutineItem.earLoopItem(loop).kind)
        XCTAssertEqual(RoutineUnitPick.loop(loop, as: .improvise).block(order: 0).kind,
                       RoutineItem.improviseLoopItem(loop).kind)
    }

    /// The three modes are three picks, so one routine can hold all three blocks for one loop.
    func testTheThreeModesOfOneLoopAreDistinctPicks() {
        let loop = Loop(name: "Riff", start: 0.1, end: 0.2, speed: 1, repeats: 4)
        let ids = Set(LoopRunMode.allCases.map { RoutineUnitPick.loop(loop, as: $0).pickID })
        XCTAssertEqual(ids.count, LoopRunMode.allCases.count)
    }

    func testAnExercisePickMakesAnExerciseBlock() {
        let drill = Exercise(name: "Spider")
        let block = RoutineUnitPick.exercise(drill).block(order: 1)
        XCTAssertIdentical(block.exercise, drill)
        XCTAssertNil(block.loop)
        XCTAssertEqual(block.kind, RoutineItem.item(drill).kind)
    }

    // MARK: - "Already in it"

    /// A loop held as ear training is **not** already in a routine as a ramp — the mode is part of
    /// what the block is.
    func testMatchingIsPerUnitAndPerMode() {
        let loop = Loop(name: "Riff", start: 0.1, end: 0.2, speed: 1, repeats: 4)
        let earBlock = RoutineItem.earLoopItem(loop)
        XCTAssertTrue(RoutineUnitPick.earLoop(loop).matches(earBlock))
        XCTAssertFalse(RoutineUnitPick.loop(loop).matches(earBlock))
        XCTAssertFalse(RoutineUnitPick.improviseLoop(loop).matches(earBlock))

        let other = Loop(name: "Other", start: 0.3, end: 0.4, speed: 1, repeats: 4)
        XCTAssertFalse(RoutineUnitPick.earLoop(other).matches(earBlock))

        let drill = Exercise(name: "Spider")
        XCTAssertTrue(RoutineUnitPick.exercise(drill).matches(RoutineItem.item(drill)))
        XCTAssertFalse(RoutineUnitPick.exercise(Exercise(name: "Spider")).matches(RoutineItem.item(drill)),
                       "same name, different drill")
        XCTAssertFalse(RoutineUnitPick.exercise(drill).matches(RoutineItem.rest()))
    }

    // MARK: - What the sheet offers

    /// The sheet's choices are the modes the loop qualifies for, in menu order — the same list its
    /// row buttons come from — and a loop that qualifies for none gets no request at all.
    func testALoopIsOfferedExactlyTheModesItQualifiesFor() {
        let song = Song(title: "Slow Bend", duration: 200,
                        ref: SongRef(id: "x", source: .localFile, bookmark: nil))
        let loop = Loop(name: "Riff", start: 0.1, end: 0.2, speed: 1, repeats: 4)
        loop.song = song

        XCTAssertEqual(labels(AddToRoutineRequest.loop(loop, named: "Riff")), ["Ear"],
                       "unmeasured and unflagged: ear training only")

        loop.commandTempo = 0.8
        loop.isBackingTrack = true
        XCTAssertEqual(labels(AddToRoutineRequest.loop(loop, named: "Riff")),
                       ["Practice", "Ear", "Improv"])

        // Unmeasured, with no audio to hear: no mode qualifies. (A *measured* songless loop still
        // qualifies for the trainer — its gate is the command tempo alone, `LoopModeAccess`.)
        let songless = Loop(name: "Stray", start: 0.1, end: 0.2, speed: 1, repeats: 4)
        XCTAssertNil(AddToRoutineRequest.loop(songless, named: "Stray"),
                     "no mode to run, so no Add to routine…")
    }

    func testADrillIsOfferedOneBlock() {
        let request = AddToRoutineRequest.exercise(Exercise(name: "Spider"), named: "Spider")
        XCTAssertEqual(request.choices.count, 1)
        XCTAssertEqual(request.unitName, "Spider")
    }

    // MARK: - Ordering

    /// One past the highest `order`, never the count — a routine that has lost a block has a gap.
    func testNextOrderIsOnePastTheHighestOrderNotTheCount() {
        let routine = Routine()
        XCTAssertEqual(routine.nextOrder, 0)
        routine.items = [RoutineItem(order: 0), RoutineItem(order: 5), RoutineItem(order: 2)]
        XCTAssertEqual(routine.nextOrder, 6)
    }

    func testRenumberingClosesGapsAndKeepsPlayOrder() {
        let first = RoutineItem(order: 1), second = RoutineItem(order: 4), third = RoutineItem(order: 9)
        let routine = Routine()
        routine.items = [third, first, second]
        routine.renumberItems()
        XCTAssertEqual([first.order, second.order, third.order], [0, 1, 2])
    }

    func testBlockSummaryCountsBlocksAndRestsSeparately() {
        let routine = Routine()
        XCTAssertEqual(routine.blockSummary, "Empty")
        routine.items = [RoutineItem.item(Exercise(name: "A"))]
        XCTAssertEqual(routine.blockSummary, "1 block")
        routine.items += [RoutineItem.item(Exercise(name: "B")), RoutineItem.rest()]
        XCTAssertEqual(routine.blockSummary, "2 blocks · 1 rest")
    }

    // MARK: - Append and take back, through the store

    /// The block lands **last**, and a fresh context — the routine editor's — sees it.
    func testAnAppendLandsLastAndIsVisibleToAFreshContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let drill = Exercise(name: "Spider")
        let routine = Routine(name: "Morning")
        routine.items = [RoutineItem.item(drill, order: 0), RoutineItem.rest(order: 3)]
        context.insert(drill)
        context.insert(routine)
        try context.save()

        let added = routine.append(.exercise(drill), in: context)
        try context.save()
        XCTAssertEqual(added.order, 4)

        let editor = ModelContext(container)
        let fetched = try XCTUnwrap(try editor.fetch(FetchDescriptor<Routine>()).first)
        XCTAssertEqual(fetched.orderedItems.count, 3)
        XCTAssertEqual(fetched.orderedItems.last?.uid, added.uid)
        XCTAssertEqual(fetched.orderedItems.last?.exercise?.name, "Spider",
                       "the same drill twice is a legitimate routine (ADR 0127)")
    }

    /// Taking a block back removes **that** block — not an earlier copy of the same drill — and
    /// closes the gap it leaves.
    func testTakingBackRemovesOnlyThatBlockAndRenumbers() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let drill = Exercise(name: "Spider")
        let routine = Routine(name: "Morning")
        let earlier = RoutineItem.item(drill, order: 0)
        routine.items = [earlier]
        context.insert(drill)
        context.insert(routine)
        try context.save()

        let added = routine.append(.exercise(drill), in: context)
        let after = routine.append(.exercise(Exercise(name: "Legato")), in: context)
        try context.save()

        XCTAssertTrue(routine.removeItem(added.uid, in: context))
        try context.save()
        XCTAssertFalse(routine.removeItem(added.uid, in: context), "already gone")

        let fetched = try XCTUnwrap(try ModelContext(container).fetch(FetchDescriptor<Routine>()).first)
        XCTAssertEqual(fetched.orderedItems.map(\.uid), [earlier.uid, after.uid])
        XCTAssertEqual(fetched.orderedItems.map(\.order), [0, 1])
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<RoutineItem>()).count, 2,
                       "the block is deleted, not just unlinked")
    }

    // MARK: - Helpers

    private func labels(_ request: AddToRoutineRequest?) -> [String]? {
        request?.choices.map(\.label)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
