import XCTest
@testable import Pocket

/// Pure command-anchored ramp math (ADR 0045): the uneven staircase warm-up → dwell at
/// command → summit → backoff. Exercised as a plain value — no engine/UI — because the
/// plateau/elapsed mapping is exactly the logic that breaks silently (AGENTS.md).
final class CommandRampTests: XCTestCase {

    private func ramp(working: Int = 80, command: Int = 100, target: Int = 106,
                      step: Int = 5, interval: Int = 4, unit: MetronomeIntervalUnit = .bars,
                      dwell: Int = 4, backoff: Bool = true) -> CommandRamp {
        CommandRamp(working: working, command: command, target: target, stepBPM: step,
                    intervalCount: interval, unit: unit, dwellIntervals: dwell,
                    includeBackoff: backoff)
    }

    func testPlateauSequenceWarmupDwellSummitBackoff() {
        // 80→100 by 5 ⇒ warm-up 80,85,90,95; dwell 100; summit 106; backoff 94 (100−6).
        let plateaus = ramp().plateaus
        XCTAssertEqual(plateaus.map(\.bpm), [80, 85, 90, 95, 100, 106, 94])
        XCTAssertEqual(plateaus.map(\.intervals), [1, 1, 1, 1, 4, 1, 1])
    }

    func testCommandPlateauHoldsTheDwell() {
        XCTAssertEqual(ramp(dwell: 6).plateaus.first { $0.bpm == 100 }?.intervals, 6)
    }

    func testStartsAtWorkingAndClimbs() {
        let cmd = ramp()
        XCTAssertEqual(cmd.bpm(elapsedBars: 0, elapsedSeconds: 0), 80)   // interval 0 → working
        XCTAssertEqual(cmd.bpm(elapsedBars: 4, elapsedSeconds: 0), 85)   // interval 1
        XCTAssertEqual(cmd.bpm(elapsedBars: 12, elapsedSeconds: 0), 95)  // interval 3
    }

    func testDwellsAtCommandAcrossItsIntervals() {
        let cmd = ramp()   // warm-up = 4 intervals (0..3), command spans intervals 4,5,6,7
        XCTAssertEqual(cmd.bpm(elapsedBars: 16, elapsedSeconds: 0), 100)  // interval 4
        XCTAssertEqual(cmd.bpm(elapsedBars: 28, elapsedSeconds: 0), 100)  // interval 7 (still dwell)
    }

    func testSummitsThenBacksOff() {
        let cmd = ramp()   // intervals: warm-up 0-3, dwell 4-7, summit 8, backoff 9
        XCTAssertEqual(cmd.bpm(elapsedBars: 32, elapsedSeconds: 0), 106)  // interval 8 summit
        XCTAssertEqual(cmd.bpm(elapsedBars: 36, elapsedSeconds: 0), 94)   // interval 9 backoff
        XCTAssertEqual(cmd.bpm(elapsedBars: 999, elapsedSeconds: 0), 94)  // holds at backoff
    }

    func testBackoffCanBeOmitted() {
        XCTAssertFalse(ramp(backoff: false).plateaus.contains { $0.bpm == 94 })
    }

    func testNoSummitWhenTargetNotAboveCommand() {
        let cmd = ramp(command: 100, target: 100)
        XCTAssertFalse(cmd.plateaus.contains { $0.bpm > 100 })
    }

    func testCompletionInterval() {
        // 7 plateaus, intervals [1,1,1,1,4,1,1] = 10 total × 4 bars/interval = 40 bars.
        XCTAssertEqual(ramp().completionInterval, 40)
        XCTAssertTrue(ramp().isFinished(elapsedBars: 40, elapsedSeconds: 0))
        XCTAssertFalse(ramp().isFinished(elapsedBars: 39, elapsedSeconds: 0))
    }

    func testSecondsUnitUsesElapsedSeconds() {
        let cmd = ramp(interval: 30, unit: .seconds)
        XCTAssertEqual(cmd.bpm(elapsedBars: 999, elapsedSeconds: 0), 80)    // 0s → working
        XCTAssertEqual(cmd.bpm(elapsedBars: 0, elapsedSeconds: 30), 85)     // 1 interval
    }

    func testWorkingAtOrAboveCommandSkipsWarmup() {
        let cmd = ramp(working: 100, command: 100)
        XCTAssertEqual(cmd.plateaus.first?.bpm, 100)   // no warm-up steps below command
    }

    // MARK: - Intermediate warm-up steps (Training Mode granularity)

    func testWarmupStepPlacesTheRequestedIntermediateStops() {
        // 70→96, 1 intermediate stop ⇒ step 13 ⇒ plateaus 70, 83 (intermediate), 96.
        let step = CommandRamp.warmupStepBPM(working: 70, command: 96, intermediateSteps: 1)
        XCTAssertEqual(step, 13)
        // backoff off so the < command filter isolates the warm-up climb (the tail is also below).
        let warmups = ramp(working: 70, command: 96, target: 102, step: step, backoff: false)
            .plateaus.filter { $0.bpm < 96 }
        XCTAssertEqual(warmups.map(\.bpm), [70, 83])   // floor + one intermediate stop
    }

    func testWarmupStepZeroJumpsStraightToCommand() {
        // 0 intermediate stops ⇒ step spans the whole climb ⇒ no plateau between floor and command.
        let step = CommandRamp.warmupStepBPM(working: 70, command: 96, intermediateSteps: 0)
        let warmups = ramp(working: 70, command: 96, target: 102, step: step, backoff: false)
            .plateaus.filter { $0.bpm < 96 }
        XCTAssertEqual(warmups.map(\.bpm), [70])
    }

    func testWarmupStepNeverZeroEvenWithNoClimb() {
        XCTAssertEqual(CommandRamp.warmupStepBPM(working: 100, command: 100, intermediateSteps: 3), 1)
    }

    func testIntermediateStepsIsTheInverseOfWarmupStep() {
        for steps in 0...6 {
            let step = CommandRamp.warmupStepBPM(working: 72, command: 132, intermediateSteps: steps)
            XCTAssertEqual(CommandRamp.intermediateSteps(working: 72, command: 132, stepBPM: step),
                           steps, "round-trip must hold for \(steps) intermediate steps")
        }
    }

    func testIntermediateStepsZeroWhenNoClimb() {
        XCTAssertEqual(CommandRamp.intermediateSteps(working: 100, command: 100, stepBPM: 5), 0)
    }
}
