import XCTest
@testable import Pocket

/// `RoutineSessionPlayer` selection logic (ADR 0071 R4b): the Done screen's "Up next" skips rests,
/// and auto-start no longer special-cases the first block. Exercised on plain in-memory `@Model`
/// objects (no context insert — the models are only read), like `RoutineModelTests`.
@MainActor
final class RoutineSessionPlayerTests: XCTestCase {

    private func routine(_ items: [RoutineItem]) -> Routine {
        let routine = Routine()
        routine.items = items
        return routine
    }

    // MARK: - nextUnitStage skips rests

    func testNextUnitStageSkipsRestToTheNextUnit() {
        let first = Exercise(name: "First")
        let second = Exercise(name: "Second")
        let player = RoutineSessionPlayer(routine: routine([
            .item(first, order: 0), .rest(order: 1), .item(second, order: 2)
        ]))
        // From block 0, the immediate next stage is the rest at 1 — the unit lookup skips it.
        XCTAssertEqual(player.nextUnitStage(after: 0)?.title, "Second")
    }

    func testNextUnitStageIsNilWhenOnlyRestsRemain() {
        let only = Exercise(name: "Only")
        let player = RoutineSessionPlayer(routine: routine([
            .item(only, order: 0), .rest(order: 1)
        ]))
        XCTAssertNil(player.nextUnitStage(after: 0))
    }

    func testNextUnitStageIsNilPastTheEnd() {
        let solo = Exercise(name: "Solo")
        let player = RoutineSessionPlayer(routine: routine([.item(solo, order: 0)]))
        XCTAssertNil(player.nextUnitStage(after: 0))
    }

    func testNextUnitStageSkipsMultipleConsecutiveRests() {
        let start = Exercise(name: "Start")
        let end = Exercise(name: "End")
        let player = RoutineSessionPlayer(routine: routine([
            .item(start, order: 0), .rest(order: 1), .rest(order: 2), .item(end, order: 3)
        ]))
        XCTAssertEqual(player.nextUnitStage(after: 0)?.title, "End")
    }

    // MARK: - Auto-start no longer excludes the first block (ADR 0071 R4b)

    func testAutoStartTreatsEveryBlockAlike() {
        let one = Exercise(name: "One")
        let two = Exercise(name: "Two")
        let player = RoutineSessionPlayer(routine: routine([
            .item(one, order: 0), .item(two, order: 1)
        ]))
        // Whatever the setting resolves to, the first block gets the same answer as the rest — the
        // old "first unit always waits" exception is gone.
        XCTAssertEqual(player.shouldAutoStart(at: 0), player.shouldAutoStart(at: 1))
    }
}
