import XCTest
@testable import Pocket

/// Loop command-anchored progression (ADR 0046, Phase B): the `Loop` ×-tempo accessors and the
/// percent-mapped `CommandRamp` builder. Pure value math, no engine/UI — the percent rounding and
/// plateau shaping are exactly the tempo logic that breaks silently (AGENTS.md). `Loop` is built
/// **uninserted** (never `context.insert` in the test host — that SIGTRAPs; property logic reads
/// fine off a bare `@Model`).
final class LoopCommandRampTests: XCTestCase {

    private func makeLoop(speed: Double, command: Double?) -> Loop {
        let loop = Loop(name: "Solo", start: 0.1, end: 0.3, speed: speed, repeats: 0)
        loop.commandTempo = command
        return loop
    }

    // MARK: - Loop accessors

    func testCommandFallsBackToSpeedWhenUnmeasured() {
        let loop = makeLoop(speed: 0.70, command: nil)
        XCTAssertFalse(loop.hasMeasuredCommand)
        XCTAssertEqual(loop.command, 0.70, accuracy: 1e-9)
    }

    func testCommandUsesMeasuredValueWhenSet() {
        let loop = makeLoop(speed: 0.70, command: 0.85)
        XCTAssertTrue(loop.hasMeasuredCommand)
        XCTAssertEqual(loop.command, 0.85, accuracy: 1e-9)
    }

    func testDerivedTargetSpeedReachesPastCommand() {
        let loop = makeLoop(speed: 0.70, command: 0.85)
        // 0.85 × 1.06 = 0.901; +0.051 within [0.02, 0.10].
        XCTAssertEqual(loop.derivedTargetSpeed, 0.901, accuracy: 1e-9)
    }

    func testPromoteCommandSetsMeasuredCommand() {
        let loop = makeLoop(speed: 0.70, command: nil)
        loop.promoteCommand(to: 0.90)
        XCTAssertTrue(loop.hasMeasuredCommand)
        XCTAssertEqual(loop.commandTempo ?? -1, 0.90, accuracy: 1e-9)
    }

    // MARK: - × → percent mapping

    func testPercentRoundsToNearestWhole() {
        XCTAssertEqual(LoopCommandRamp.percent(0.85), 85)
        XCTAssertEqual(LoopCommandRamp.percent(0.704), 70)   // 70.4 → 70
        XCTAssertEqual(LoopCommandRamp.percent(0.706), 71)   // 70.6 → 71
        XCTAssertEqual(LoopCommandRamp.percent(1.0), 100)
    }

    func testPercentNeverNegative() {
        XCTAssertEqual(LoopCommandRamp.percent(-0.5), 0)
    }

    // MARK: - Ramp builder

    func testRampMapsTemposToPercentAndPasses() {
        let ramp = LoopCommandRamp.make(working: 0.70, command: 0.85, target: 0.91)
        XCTAssertEqual(ramp.working, 70)
        XCTAssertEqual(ramp.command, 85)
        XCTAssertEqual(ramp.target, 91)
        // Intervals are loop passes — the ramp reuses `.bars`, fed by the engine's loopIteration —
        // and one pass is one interval, so every hold is a number of passes (ADR 0221 D8).
        XCTAssertEqual(ramp.unit, .bars)
        XCTAssertEqual(ramp.intervalCount, 1)
    }

    func testOnePassARungAdvancesThePlateauEachPass() {
        // Each non-dwell rung holds one pass by default, so the warm-up floor holds for pass 0 and
        // the next plateau begins at pass 1.
        let ramp = LoopCommandRamp.make(working: 0.70, command: 0.85, target: 0.91,
                                        shape: RunShape(includeBackoff: false, warmupSteps: 1))
        XCTAssertEqual(ramp.currentPlateauIndex(elapsedBars: 0, elapsedSeconds: 0), 0)
        XCTAssertEqual(ramp.currentPlateauIndex(elapsedBars: 1, elapsedSeconds: 0), 1)
    }

    func testRampStaircaseClimbsWarmupThroughDwellToReach() {
        // working 70, command 85, one intermediate warm-up step → ~77 between them.
        let ramp = LoopCommandRamp.make(working: 0.70, command: 0.85, target: 0.91,
                                        shape: RunShape(includeBackoff: false, warmupSteps: 1,
                                                        dwell: 4))
        let bpms = ramp.plateaus.map(\.bpm)
        XCTAssertEqual(bpms.first, 70, "starts at the warm-up floor")
        XCTAssertTrue(bpms.contains(85), "dwells at command")
        XCTAssertEqual(bpms.last, 91, "summits at the reach")
        // The command plateau is the wide one (the dwell).
        let dwell = ramp.plateaus.first { $0.bpm == 85 }
        XCTAssertEqual(dwell?.intervals, 4)
    }

    func testRampAddsBackoffTailBelowCommand() {
        let ramp = LoopCommandRamp.make(working: 0.70, command: 0.85, target: 0.91)
        // command 85, target 91 → reach +6, so backoff −6 → 79, floored at working 70.
        XCTAssertEqual(ramp.plateaus.last?.bpm, 79)
    }

    func testBackoffOverrideConvertsSpeedToPercentTail() {
        // A pinned 0.76× floor lands the tail at 76% — replacing the derived 79.
        let ramp = LoopCommandRamp.make(working: 0.70, command: 0.85, target: 0.91,
                                        backoffOverride: 0.76)
        XCTAssertEqual(ramp.plateaus.last?.bpm, 76)
    }

    func testBackoffOverrideIgnoredWhenBackoffIsOff() {
        let ramp = LoopCommandRamp.make(working: 0.70, command: 0.85, target: 0.91,
                                        shape: RunShape(includeBackoff: false), backoffOverride: 0.76)
        XCTAssertEqual(ramp.plateaus.last?.bpm, 91)   // ends at the summit, no tail
    }

    func testLoopRampHonoursBackoffToggleAndOverride() {
        let loop = makeLoop(speed: 0.70, command: 0.85)
        loop.includeBackoff = false
        // Off ⇒ the ramp ends at the summit (the reach), no tail below command.
        XCTAssertEqual(loop.ramp.plateaus.last?.bpm, LoopCommandRamp.percent(loop.targetSpeed))
        loop.includeBackoff = true
        loop.backoffSpeedOverride = 0.72
        XCTAssertEqual(loop.ramp.plateaus.last?.bpm, 72)   // pinned floor, in percent
    }

    func testRampBuiltFromLoopMatchesExplicitTempos() {
        let loop = makeLoop(speed: 0.70, command: 0.85)
        loop.rampWarmupSteps = 1
        let explicit = LoopCommandRamp.make(working: 0.70, command: 0.85,
                                            target: loop.derivedTargetSpeed,
                                            shape: RunShape(warmupSteps: 1))
        XCTAssertEqual(loop.ramp, explicit)
    }

    func testRampFinishesAfterAllPassesElapse() {
        let ramp = LoopCommandRamp.make(working: 0.70, command: 0.85, target: 0.91)
        let total = ramp.completionInterval ?? 0
        XCTAssertGreaterThan(total, 0)
        XCTAssertFalse(ramp.isFinished(elapsedBars: total - 1, elapsedSeconds: 0))
        XCTAssertTrue(ramp.isFinished(elapsedBars: total, elapsedSeconds: 0))
    }
}
