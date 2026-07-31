import SwiftData
import XCTest
@testable import Pocket

/// A generated block's allotted minutes surviving into the routine it materialises into (ADR 0129).
///
/// Before this, `PracticePlanner.item(for:)` read a block's `unit` and `kind` and silently dropped its
/// `minutes` — so the block model computed a 15-minute block's share three ways and then threw the
/// answer away at the persistence boundary, leaving the run with no idea what slot it was filling.
/// Exercised through an in-memory container with individual inserts, per the project's test-host trap
/// note.
final class PlannedMinutesTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, configurations: config)
        return ModelContext(container)
    }

    private func drill(_ name: String, into context: ModelContext) -> Exercise {
        let exercise = Exercise(name: name)
        context.insert(exercise)
        return exercise
    }

    func testFocusedBlocksCarryTheirAllottedMinutesIntoTheRoutine() throws {
        let context = try makeContext()
        let first = drill("Spider", into: context)
        let second = drill("Legato", into: context)
        try context.save()

        let blocks: [SessionBlock] = [
            .focus(PlannerUnitRef(first.uid, .exercise), minutes: 5, microRestEvery: 2),
            .focus(PlannerUnitRef(second.uid, .exercise), minutes: 7, microRestEvery: 2)
        ]
        let routine = PracticePlanner.materialise(blocks, name: "Session",
                                                  exercises: try context.fetch(FetchDescriptor<Exercise>()),
                                                  loops: [], songs: [], into: context)

        XCTAssertEqual(routine.orderedItems.map(\.plannedMinutes), [5, 7])
    }

    func testUnbudgetedBookEndsAndRestsCarryNoPlannedMinutes() throws {
        let context = try makeContext()
        let warm = drill("Warm", into: context)
        let focus = drill("Focus", into: context)
        try context.save()

        let blocks: [SessionBlock] = [
            .warmUp(PlannerUnitRef(warm.uid, .exercise), minutes: 5),
            .focus(PlannerUnitRef(focus.uid, .exercise), minutes: 5, microRestEvery: 2),
            .rest(minutes: 3)
        ]
        let routine = PracticePlanner.materialise(blocks, name: "Session",
                                                  exercises: try context.fetch(FetchDescriptor<Exercise>()),
                                                  loops: [], songs: [], into: context)

        // R1 — warm-up and play run as long as the player likes, so pinning them to a nominal figure
        // would contradict the rule the planner is built on. Only focused work is budgeted.
        XCTAssertEqual(routine.orderedItems.map(\.plannedMinutes), [nil, 5, nil])
    }

    func testAHandAuthoredRoutineHasNoPlannedMinutes() throws {
        let context = try makeContext()
        let exercise = drill("Hand-made", into: context)
        let item = RoutineItem.item(exercise, order: 0)
        context.insert(item)
        try context.save()

        // Optional with no declaration default — pre-existing items migrate to `nil` and keep running
        // at whatever length their own recipe implies.
        XCTAssertNil(item.plannedMinutes)
    }

    @MainActor
    func testARoutineEstimatePricesTheRunThatWillActuallyPlay() throws {
        let context = try makeContext()
        let first = drill("Spider", into: context)
        let second = drill("Legato", into: context)
        try context.save()

        let blocks: [SessionBlock] = [
            .focus(PlannerUnitRef(first.uid, .exercise), minutes: 5, microRestEvery: 2),
            .focus(PlannerUnitRef(second.uid, .exercise), minutes: 5, microRestEvery: 2)
        ]
        let routine = PracticePlanner.materialise(blocks, name: "Session",
                                                  exercises: try context.fetch(FetchDescriptor<Exercise>()),
                                                  loops: [], songs: [], into: context)

        // Three numbers, all different, and the estimate must be the third. The drill's own ramp is
        // 2 minutes; the block *asked* for 5; the fit will only stretch the authored dwell 2.5×, so
        // what plays is 3. Reading the allotment back as fact would over-promise by two minutes a
        // block — the failure mode that made the preview and the run disagree on device.
        XCTAssertEqual(PracticePlanner.estimatedMinutes(for: first), 2)
        XCTAssertEqual(PracticePlanner.estimatedMinutes(for: first, plannedMinutes: 5), 3)
        XCTAssertEqual(PracticePlanner.estimatedMinutes(forRoutine: routine), 6)
    }

    @MainActor
    func testAnAllottedSlotTheFitCanReachIsReportedAsAsked() throws {
        let context = try makeContext()
        let exercise = drill("Spider", into: context)
        try context.save()

        // 3 minutes is inside the 2.5× bound for a default 4-interval dwell, so the plan and the
        // performance agree exactly — the clamp only speaks up when the ask is out of reach.
        XCTAssertEqual(PracticePlanner.estimatedMinutes(for: exercise, plannedMinutes: 3), 3)
    }

    @MainActor
    func testAHandAuthoredRoutineStillEstimatesFromItsUnits() throws {
        let context = try makeContext()
        let exercise = drill("Hand-made", into: context)
        let routine = Routine(name: "Mine")
        let item = RoutineItem.item(exercise, order: 0)
        context.insert(routine)
        context.insert(item)
        item.routine = routine
        try context.save()

        XCTAssertEqual(PracticePlanner.estimatedMinutes(forRoutine: routine),
                       PracticePlanner.estimatedMinutes(for: exercise))
    }

    func testAFittedRampFillsThePlannedSlot() {
        // The end of the chain: a three-minute slot really does buy ~three minutes of ramp, by
        // stretching the dwell rather than the climb.
        let exercise = Exercise(currentTempo: 80)
        let fitted = SessionEstimate.fitted(exercise.ramp, toMinutes: 3,
                                            beatsPerBar: exercise.beatsPerBar)
        XCTAssertEqual(SessionEstimate.minutes(forRamp: fitted, beatsPerBar: exercise.beatsPerBar), 3)
        XCTAssertGreaterThan(fitted.dwellIntervals, exercise.ramp.dwellIntervals)
        // The staircase either side of the dwell is untouched.
        XCTAssertEqual(fitted.plateaus.map(\.bpm), exercise.ramp.plateaus.map(\.bpm))
    }

    /// The device-pass finding: an authored 4-interval dwell given a 5-minute block was stretched to
    /// ~19 intervals — five times the recipe, and enough to crush the staircase's other bars.
    func testTheFitCannotRunAwayWithTheAuthoredDwell() {
        let exercise = Exercise(currentTempo: 80)
        let fitted = SessionEstimate.fitted(exercise.ramp, toMinutes: 5,
                                            beatsPerBar: exercise.beatsPerBar)
        XCTAssertEqual(exercise.ramp.dwellIntervals, 4)
        XCTAssertEqual(fitted.dwellIntervals, 10)   // 2.5 × 4, not the 19 the raw arithmetic wanted
    }
}
