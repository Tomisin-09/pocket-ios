import XCTest
@testable import Pocket

/// Pure command-anchored ramp math (ADR 0045): the uneven staircase warm-up → dwell at
/// command → summit → backoff. Exercised as a plain value — no engine/UI — because the
/// plateau/elapsed mapping is exactly the logic that breaks silently (AGENTS.md).
final class CommandRampTests: XCTestCase {

    /// 80 → 100 with 3 intermediate warm-up stops ⇒ warm-up 80, 85, 90, 95 — the shape the old
    /// 5-BPM stride drew here, so every expectation below survived the move to a count.
    private func ramp(working: Int = 80, command: Int = 100, target: Int = 106,
                      warmup: Int = 3, interval: Int = 4, unit: MetronomeIntervalUnit = .bars,
                      dwell: Int = 4, backoff: Bool = true) -> CommandRamp {
        CommandRamp(working: working, command: command, target: target, warmupSteps: warmup,
                    intervalCount: interval, unit: unit, dwellIntervals: dwell,
                    includeBackoff: backoff)
    }

    func testPlateauSequenceWarmupDwellSummitBackoff() {
        // 80→100 in 4 rungs ⇒ warm-up 80,85,90,95; dwell 100; summit 106; backoff 94 (100−6).
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

    // MARK: - Warm-up by count (ADR 0221 D4)

    func testWarmupPlacesTheRequestedIntermediateStops() {
        // 70→96, 1 intermediate stop ⇒ the floor and one stop midway (83), then command.
        let warmups = ramp(working: 70, command: 96, target: 102, warmup: 1, backoff: false)
            .plateaus.filter { $0.bpm < 96 }
        XCTAssertEqual(warmups.map(\.bpm), [70, 83])
    }

    func testZeroWarmupStepsIsTheFloorAloneThenCommand() {
        let warmups = ramp(working: 70, command: 96, target: 102, warmup: 0, backoff: false)
            .plateaus.filter { $0.bpm < 96 }
        XCTAssertEqual(warmups.map(\.bpm), [70])
    }

    /// Context §4 of ADR 0221, pinned: at 51 → 61 the stride walk played **four** rungs for a setting
    /// of 2 and **ten** for a setting of 6. By count, the rungs are the setting plus the floor.
    func testTheStrideBugIsGone() {
        func warmups(_ steps: Int) -> [Int] {
            ramp(working: 51, command: 61, target: 65, warmup: steps, backoff: false)
                .plateaus.map(\.bpm).filter { $0 < 61 }
        }
        XCTAssertEqual(warmups(2), [51, 54, 58])
        XCTAssertEqual(warmups(6).count, 7)
        XCTAssertEqual(warmups(6), [51, 52, 54, 55, 57, 58, 60])
    }

    func testRungCountsMatchTheSettingAcrossSpans() {
        for (working, command) in [(51, 61), (70, 96), (40, 180), (88, 90)] {
            for steps in 0...6 {
                let drawn = ramp(working: working, command: command, target: command + 5,
                                 warmup: steps, backoff: false)
                    .plateaus.filter { $0.bpm < command }
                let expected = CommandRamp.rungs(steps: steps, from: working, to: command)
                XCTAssertEqual(drawn.count, expected, "\(working)→\(command) at \(steps)")
                XCTAssertEqual(Set(drawn.map(\.bpm)).count, drawn.count, "a rung repeated a tempo")
            }
        }
    }

    /// Seven rungs over a 3-BPM gap would repeat tempos, so the count is capped at the gap (D4).
    func testRungsNeverExceedTheGapOrSeven() {
        XCTAssertEqual(CommandRamp.rungs(steps: 6, from: 58, to: 61), 3)
        XCTAssertEqual(CommandRamp.rungs(steps: 6, from: 40, to: 180), 7)
        XCTAssertEqual(CommandRamp.rungs(steps: 20, from: 40, to: 180), 7)
        XCTAssertEqual(CommandRamp.rungs(steps: 0, from: 60, to: 60), 1)
        XCTAssertEqual(CommandRamp.rungs(steps: 3, from: 120, to: 100), 4)   // descending too
        let warmups = ramp(working: 58, command: 61, target: 65, warmup: 6, backoff: false)
            .plateaus.map(\.bpm).filter { $0 < 61 }
        XCTAssertEqual(warmups, [58, 59, 60])
    }

    /// The one-time seed from a stored stride (D4) — the inverse of the stride the run screen stored
    /// before ADR 0221, so an exercise shows the setting it showed before.
    func testIntermediateStepsIsTheInverseOfWarmupStep() {
        for steps in 0...6 {
            let step = Self.storedStride(working: 72, command: 132, intermediateSteps: steps)
            XCTAssertEqual(CommandRamp.intermediateSteps(working: 72, command: 132, stepBPM: step),
                           steps, "round-trip must hold for \(steps) intermediate steps")
        }
    }

    /// The stride the run screen wrote to `rampStepBPM` before ADR 0221 D4 — the average spacing of
    /// `intermediateSteps` stops. The app no longer computes it (`warmupStepBPM` went with the last
    /// panel that captioned by it, in step 2); it's kept here because stores still hold its output.
    private static func storedStride(working: Int, command: Int, intermediateSteps: Int) -> Int {
        let span = command - working
        guard span > 0 else { return 1 }
        return max(1, Int((Double(span) / Double(max(1, intermediateSteps + 1))).rounded()))
    }

    func testIntermediateStepsZeroWhenNoClimb() {
        XCTAssertEqual(CommandRamp.intermediateSteps(working: 100, command: 100, stepBPM: 5), 0)
    }

    // MARK: - Reach / back-up intermediate steps (ADR 0046 run-UI)

    func testReachStepsAddIntermediateClimbToTheSummit() {
        // command 100 → reach 112, 1 reach step ⇒ one stop midway (106) before the summit.
        var cmd = ramp(command: 100, target: 112, backoff: false)
        cmd.reachSteps = 1
        let above = cmd.plateaus.filter { $0.bpm > 100 }.map(\.bpm)
        XCTAssertEqual(above, [106, 112])
    }

    func testBackoffStepsAddIntermediateDescent() throws {
        // working 70, command 100, summit 130 ⇒ backoff floor 70 (100−30); 2 back-up steps ⇒
        // two stops (110, 90) on the way down before the floor.
        var cmd = ramp(working: 70, command: 100, target: 130)
        cmd.backoffSteps = 2
        let bpms = cmd.plateaus.map(\.bpm)
        let summit = try XCTUnwrap(bpms.firstIndex(of: 130))
        XCTAssertEqual(Array(bpms[(summit + 1)...]), [110, 90, 70])
    }

    func testZeroReachAndBackoffStepsMatchTheOriginalShape() {
        // Defaults (0/0) must reproduce the pre-feature staircase exactly.
        let plateaus = ramp().plateaus
        XCTAssertEqual(plateaus.map(\.bpm), [80, 85, 90, 95, 100, 106, 94])
    }

    // MARK: - Editable back-off floor (user-testing note 6)

    func testBackoffOverrideReplacesTheDerivedFloor() {
        // Default derives a 94 tail; a pin to 88 must land the tail there instead.
        var cmd = ramp()
        cmd.backoffOverride = 88
        XCTAssertEqual(cmd.plateaus.map(\.bpm), [80, 85, 90, 95, 100, 106, 88])
    }

    func testBackoffOverrideIsIgnoredWhenBackoffIsOff() {
        // The toggle wins: no tail at all, override notwithstanding.
        var cmd = ramp(backoff: false)
        cmd.backoffOverride = 88
        XCTAssertEqual(cmd.plateaus.map(\.bpm), [80, 85, 90, 95, 100, 106])
    }

    func testBackoffOverrideAtOrAboveCommandDropsTheTail() {
        // A floor that isn't below command can't be a back-off — the guard drops it.
        var cmd = ramp()
        cmd.backoffOverride = 100
        XCTAssertEqual(cmd.plateaus.map(\.bpm).last, 106)   // ends at the summit, no tail
    }

    func testBackoffOverrideDrivesTheIntermediateDescent() throws {
        // working 70, command 100, summit 130, pinned floor 76, 2 back-up steps ⇒ the stops
        // interpolate toward the pinned floor (not the derived one).
        var cmd = ramp(working: 70, command: 100, target: 130)
        cmd.backoffOverride = 76
        cmd.backoffSteps = 2
        let bpms = cmd.plateaus.map(\.bpm)
        let summit = try XCTUnwrap(bpms.firstIndex(of: 130))
        XCTAssertEqual(Array(bpms[(summit + 1)...]), [112, 94, 76])
    }

    func testIntermediateBPMsAreEvenlySpacedAndExcludeEndpoints() {
        XCTAssertEqual(CommandRamp.intermediateBPMs(from: 100, to: 120, steps: 3), [105, 110, 115])
        XCTAssertEqual(CommandRamp.intermediateBPMs(from: 120, to: 100, steps: 3), [115, 110, 105])
        XCTAssertEqual(CommandRamp.intermediateBPMs(from: 100, to: 100, steps: 3), [])
        XCTAssertEqual(CommandRamp.intermediateBPMs(from: 100, to: 120, steps: 0), [])
        // More stops than fit: clamped to the gap, never a repeated tempo (it used to emit 62, 62).
        XCTAssertEqual(CommandRamp.intermediateBPMs(from: 61, to: 63, steps: 3), [62])
    }

    // MARK: - Live plateau cursor (staircase highlight)

    func testCurrentPlateauIndexTracksTheElapsedWalk() {
        let cmd = ramp()   // plateaus: warm-up 0-3, dwell 4-7, summit 8, backoff 9 (per interval)
        XCTAssertEqual(cmd.currentPlateauIndex(elapsedBars: 0, elapsedSeconds: 0), 0)   // working
        XCTAssertEqual(cmd.currentPlateauIndex(elapsedBars: 12, elapsedSeconds: 0), 3)  // last warm-up
        XCTAssertEqual(cmd.currentPlateauIndex(elapsedBars: 16, elapsedSeconds: 0), 4)  // dwell
        XCTAssertEqual(cmd.currentPlateauIndex(elapsedBars: 32, elapsedSeconds: 0), 5)  // summit
        XCTAssertEqual(cmd.currentPlateauIndex(elapsedBars: 36, elapsedSeconds: 0), 6)  // backoff
    }

    func testCurrentPlateauIndexClampsToTheLastPlateau() {
        XCTAssertEqual(ramp().currentPlateauIndex(elapsedBars: 9999, elapsedSeconds: 0),
                       ramp().plateaus.count - 1)
    }
}
