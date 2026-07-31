import SwiftData
import XCTest
@testable import Pocket

/// A block declining the session's fit (ADR 0130).
///
/// ADR 0129 made a generated block fit its exercise's or loop's ramp to the minutes the session
/// allotted it, and the device pass bounded that fit — but it stayed *silent and unconditional*. The
/// opt-out has to hold three properties at once, and each of them is easy to break silently: the
/// allotment must **survive** a decline (so the toggle can come back), the decline must reach **every**
/// consumer (an estimate that disagrees with the run is the ADR 0129 bug again), and the routine's
/// estimate must **re-flow**, so the cost of declining shows on the same screen as the choice.
final class BlockLengthOverrideTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, configurations: config)
        return ModelContext(container)
    }

    /// A block allotted `minutes` by a generated session, wired into a routine.
    private func block(_ exercise: Exercise, minutes: Int?,
                       in routine: Routine, into context: ModelContext) -> RoutineItem {
        let item = RoutineItem.item(exercise, order: 0)
        context.insert(item)
        item.routine = routine
        item.plannedMinutes = minutes
        return item
    }

    // MARK: - The rule itself

    func testABlockAcceptsTheFitByDefault() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)
        let routine = Routine(name: "Session")
        context.insert(routine)
        let item = block(exercise, minutes: 5, in: routine, into: context)
        try context.save()

        // The declaration default — every routine saved before ADR 0130 migrates to "accepts the fit",
        // so nothing about ADR 0129's behaviour moves until someone deliberately declines.
        XCTAssertFalse(item.usesAuthoredLength)
        XCTAssertEqual(item.effectivePlannedMinutes, 5)
    }

    func testDecliningKeepsTheAllotmentButStopsItGoverning() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)
        let routine = Routine(name: "Session")
        context.insert(routine)
        let item = block(exercise, minutes: 5, in: routine, into: context)
        try context.save()

        item.usesAuthoredLength = true
        XCTAssertNil(item.effectivePlannedMinutes)
        // The point of a flag rather than a cleared `plannedMinutes`: the allotment is the only record
        // of what the session asked for, so clearing it would make the toggle a one-way door and leave
        // the block preview unable to name both numbers.
        XCTAssertEqual(item.plannedMinutes, 5)

        item.usesAuthoredLength = false
        XCTAssertEqual(item.effectivePlannedMinutes, 5)
    }

    func testAHandAuthoredBlockHasNothingToDecline() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Hand-made")
        context.insert(exercise)
        let routine = Routine(name: "Mine")
        context.insert(routine)
        let item = block(exercise, minutes: nil, in: routine, into: context)
        try context.save()

        // No allotment either way — declining a block that was never fitted changes nothing.
        XCTAssertNil(item.effectivePlannedMinutes)
        item.usesAuthoredLength = true
        XCTAssertNil(item.effectivePlannedMinutes)
    }

    // MARK: - The estimate re-flows (ADR 0130 §3)

    @MainActor
    func testADeclinedBlockIsPricedAsItsAuthoredRecipe() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)
        let routine = Routine(name: "Session")
        context.insert(routine)
        let item = block(exercise, minutes: 5, in: routine, into: context)
        try context.save()

        // Three numbers again (as in `PlannedMinutesTests`): the drill's own ramp is 2 minutes, the
        // block asked for 5, and the bounded fit delivers 3.
        let authored = PracticePlanner.estimatedMinutes(for: exercise)
        XCTAssertEqual(authored, 2)
        XCTAssertEqual(PracticePlanner.estimatedMinutes(forRoutine: routine), 3)

        item.usesAuthoredLength = true
        // Declining hands back the minute the fit had added — visibly, on the routine's own readout,
        // which is what makes the opt-out compatible with the preset's promise instead of a hole in it.
        XCTAssertEqual(PracticePlanner.estimatedMinutes(forRoutine: routine), authored)
    }

    @MainActor
    func testADeclinedLoopBlockIsPricedAsItsAuthoredRecipe() throws {
        let context = try makeContext()
        let loop = Loop(name: "Chorus lick", start: 0.1, end: 0.2, speed: 0.8, repeats: 3)
        loop.song = Song(title: "Test", duration: 120,
                         ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        context.insert(loop)
        let routine = Routine(name: "Session")
        context.insert(routine)
        let item = RoutineItem.item(loop, order: 0)
        context.insert(item)
        item.routine = routine
        item.plannedMinutes = 9
        try context.save()

        let authored = PracticePlanner.estimatedMinutes(for: loop, mode: .trainer,
                                                        plannedMinutes: nil)
        // Loops are first-class in the block model (ADR 0129 as amended), so the opt-out has to reach
        // them too — the estimator that prices them is a different one (percent units, not BPM).
        XCTAssertNotEqual(PracticePlanner.estimatedMinutes(forRoutine: routine), authored)
        item.usesAuthoredLength = true
        XCTAssertEqual(PracticePlanner.estimatedMinutes(forRoutine: routine), authored)
    }

    // MARK: - The run agrees with the estimate

    @MainActor
    func testTheSessionPlayerRunsADeclinedBlockAsAuthored() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)
        let routine = Routine(name: "Session")
        context.insert(routine)
        let item = block(exercise, minutes: 5, in: routine, into: context)
        try context.save()

        XCTAssertEqual(RoutineSessionPlayer(routine: routine).stages.first?.plannedMinutes, 5)

        item.usesAuthoredLength = true
        // The stage carries no allotment at all, so `ExerciseRunView.routine` skips the fit entirely
        // and hands the engine the stored recipe — the same ramp the preview drew.
        XCTAssertNil(RoutineSessionPlayer(routine: routine).stages.first?.plannedMinutes)
    }
}
