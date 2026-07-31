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
    func testARoutineEstimatePrefersThePlanOverTheUnitsOwnLength() throws {
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

        // Each default drill's own ramp estimates 2 minutes, but the run is fitted to the 5 the block
        // allotted — so re-deriving from the unit would under-report a generated session by more than
        // half. 5 + 5.
        XCTAssertEqual(PracticePlanner.estimatedMinutes(for: first), 2)
        XCTAssertEqual(PracticePlanner.estimatedMinutes(forRoutine: routine), 10)
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
        // The end of the chain: a five-minute slot really does buy ~five minutes of ramp, by stretching
        // the dwell rather than the climb.
        let exercise = Exercise(currentTempo: 80)
        let fitted = SessionEstimate.fitted(exercise.ramp, toMinutes: 5,
                                            beatsPerBar: exercise.beatsPerBar)
        XCTAssertEqual(SessionEstimate.minutes(forRamp: fitted, beatsPerBar: exercise.beatsPerBar), 5)
        XCTAssertGreaterThan(fitted.dwellIntervals, exercise.ramp.dwellIntervals)
        // The staircase either side of the dwell is untouched.
        XCTAssertEqual(fitted.plateaus.map(\.bpm), exercise.ramp.plateaus.map(\.bpm))
    }
}
