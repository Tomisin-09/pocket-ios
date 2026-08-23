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

    // MARK: - Loop block mode → stage kind (ADR 0104 Slice 2)

    func testLoopBlockModeMapsToTheMatchingStageKind() {
        let loop = Loop(name: "Riff", start: 0.1, end: 0.2, speed: 1, repeats: 4)
        let earLoop = Loop(name: "Lick", start: 0.3, end: 0.4, speed: 1, repeats: 4)
        let player = RoutineSessionPlayer(routine: routine([
            .item(loop, order: 0), .earLoopItem(earLoop, order: 1)
        ]))
        // A standard loop block runs the trainer; an ear-mode block resolves to `.earLoop` so the
        // player embeds the ears-only surface — both from the same `Loop` unit.
        XCTAssertEqual(player.stages.map(\.kind), [.loop, .earLoop])
        XCTAssertIdentical(player.stages[1].loop, earLoop)   // `loop` accessor covers both modes
    }

    // MARK: - A block marked to record (ADR 0179)

    func testRecordsTakeReachesTheStageAndDefaultsOff() {
        let marked = Exercise(name: "Marked")
        let plain = Exercise(name: "Plain")
        let markedItem = RoutineItem.item(marked, order: 0)
        markedItem.recordsTake = true
        let player = RoutineSessionPlayer(routine: routine([markedItem, .item(plain, order: 1)]))
        XCTAssertEqual(player.stages.map(\.recordsTake), [true, false])
    }

    /// **Every loop mode honours the flag** (ADR 0180 D1), reversing ADR 0179's trainer-only rule.
    /// Ear and improvise blocks could always record from their own screens (ADR 0069 amendment §2),
    /// but only by remembering to arm mid-session; the flag arms them in advance. The block-list
    /// badge reads the same rule, so a badge never disagrees with what the block does.
    func testEveryLoopModeCarriesTheRecordFlag() {
        let trainer = Loop(name: "Riff", start: 0.1, end: 0.2, speed: 1, repeats: 4)
        let ear = Loop(name: "Lick", start: 0.3, end: 0.4, speed: 1, repeats: 4)
        let jam = Loop(name: "Vamp", start: 0.5, end: 0.6, speed: 1, repeats: 4)
        let items = [RoutineItem.item(trainer, order: 0),
                     RoutineItem.earLoopItem(ear, order: 1),
                     RoutineItem.improviseLoopItem(jam, order: 2)]
        for item in items { item.recordsTake = true }
        let player = RoutineSessionPlayer(routine: routine(items))
        XCTAssertEqual(player.stages.map(\.kind), [.loop, .earLoop, .improviseLoop])
        XCTAssertEqual(player.stages.map(\.recordsTake), [true, true, true])
    }

    /// A **freeform** exercise runs `FreeformRunView`, which records with a live start/stop button
    /// and has no armed state to pre-set (ADR 0180 D2). Its preview never offers the switch, so the
    /// only way to reach this is a flag set while the exercise was ramped and left behind by a
    /// template change — and a stage that carried it would badge a block that records nothing.
    func testAFreeformExerciseBlockDropsTheRecordFlag() {
        let ramped = Exercise(name: "Alt picking")
        let freeform = Exercise(name: "Noodling", template: .freeform)
        let items = [RoutineItem.item(ramped, order: 0), RoutineItem.item(freeform, order: 1)]
        for item in items { item.recordsTake = true }
        let player = RoutineSessionPlayer(routine: routine(items))
        XCTAssertEqual(player.stages.map(\.recordsTake), [true, false])
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

    // MARK: - Reps (ADR 0076)

    /// A block set to run twice stays the current block across the first natural completion, then
    /// rolls to the next on the last rep — `advance()` is rep-aware.
    func testMultiRepBlockRepeatsBeforeAdvancing() {
        let drill = Exercise(name: "Alt picking")
        let next = Exercise(name: "Legato")
        let first = RoutineItem.item(drill, order: 0); first.reps = 2
        let player = RoutineSessionPlayer(routine: routine([first, .item(next, order: 1)]))

        XCTAssertEqual(player.currentRep, 1)
        XCTAssertTrue(player.hasMoreReps)
        XCTAssertEqual(player.repLabel, "Rep 1 of 2")
        XCTAssertEqual(player.current?.title, "Alt picking")

        player.advance()                              // rep 1 → 2, same block
        XCTAssertEqual(player.currentRep, 2)
        XCTAssertFalse(player.hasMoreReps)
        XCTAssertEqual(player.current?.title, "Alt picking")

        player.advance()                              // last rep → next block
        XCTAssertEqual(player.current?.title, "Legato")
        XCTAssertEqual(player.currentRep, 1)
    }

    /// Skip abandons the remaining reps and jumps to the next block, unlike `advance()`.
    func testSkipBypassesRemainingReps() {
        let drill = Exercise(name: "Spider")
        let next = Exercise(name: "Scales")
        let first = RoutineItem.item(drill, order: 0); first.reps = 3
        let player = RoutineSessionPlayer(routine: routine([first, .item(next, order: 1)]))

        player.skip()                                 // from rep 1 → straight to the next block
        XCTAssertEqual(player.current?.title, "Scales")
        XCTAssertEqual(player.currentRep, 1)
    }

    /// The block progress label counts blocks, not reps, so a repeated block never inflates "N of M".
    func testProgressLabelUnaffectedByReps() {
        let drill = Exercise(name: "Warm-up")
        let item = RoutineItem.item(drill, order: 0); item.reps = 3
        let player = RoutineSessionPlayer(routine: routine([item, .rest(order: 1)]))
        XCTAssertEqual(player.progressLabel, "1 of 2")
        player.advance()
        XCTAssertEqual(player.progressLabel, "1 of 2")   // still the same block, rep 2
    }
}
