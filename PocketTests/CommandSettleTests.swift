import XCTest
@testable import Pocket

/// The **invariants a settle carries with it** (ADR 0134 §6) — the two pure rules, and the model
/// setters that apply them.
///
/// These are the parts that fail *silently*: a settle that leaves the warm-up floor above the new
/// command produces a ramp with no warm-up at all, and one that leaves a caught-up backoff pin in
/// place produces a ramp with no tail. Neither errors, and both are invisible until someone plays the
/// drill. So the assertions below go through `CommandRamp.plateaus` — what the run actually performs —
/// rather than stopping at the stored fields.
///
/// Models are built **uninserted**: inserting an object graph SIGTRAPs in the XCTest host
/// (`docs/swiftdata-gotchas.md`).
final class CommandSettleTests: XCTestCase {

    // MARK: - The pure floor rule

    func testFloorIsUntouchedWhenTheSettleStaysAboveIt() {
        XCTAssertEqual(CommandOffer.settledFloor(command: 90, working: 80), 80)
    }

    func testFloorComesDownWhenTheSettleLandsOnIt() {
        // Equal is not safe: `CommandRamp` needs `command > working` to emit a warm-up at all.
        let floor = CommandOffer.settledFloor(command: 80, working: 80)
        XCTAssertLessThan(floor, 80)
        XCTAssertEqual(floor, TempoStretch.warmupFloorBPM(forCommand: 80))
    }

    func testFloorComesDownWhenTheSettleGoesWellBelowIt() {
        let floor = CommandOffer.settledFloor(command: 60, working: 80)
        XCTAssertLessThan(floor, 60)
        XCTAssertEqual(floor, TempoStretch.warmupFloorBPM(forCommand: 60))
    }

    // MARK: - The pure backoff-pin rule

    func testBackoffPinSurvivesWhenItStaysBelowTheSettledCommand() {
        XCTAssertEqual(CommandOffer.survivingBackoffPin(70, command: 90), 70)
    }

    func testBackoffPinIsClearedWhenCaughtUp() {
        // At or above the settled command, `plateaus` would drop the tail entirely.
        XCTAssertNil(CommandOffer.survivingBackoffPin(90, command: 90))
        XCTAssertNil(CommandOffer.survivingBackoffPin(95, command: 90))
    }

    func testAbsentBackoffPinStaysAbsent() {
        XCTAssertNil(CommandOffer.survivingBackoffPin(Int?.none, command: 90))
    }

    func testBackoffPinRuleWorksInLoopSpeedUnits() {
        // The same rule over `×` rather than BPM — one generic implementation, both models.
        XCTAssertEqual(CommandOffer.survivingBackoffPin(0.7, command: 0.9), 0.7)
        XCTAssertNil(CommandOffer.survivingBackoffPin(0.9, command: 0.9))
    }

    // MARK: - Exercise.settleCommand

    /// A drill with a measured command well above its working floor.
    private func measuredExercise(working: Int = 80, command: Int = 100) -> Exercise {
        let exercise = Exercise(name: "Alternate picking", currentTempo: working)
        exercise.promoteCommand(to: command)
        exercise.workingTempo = working      // promoteCommand leaves working alone; pin it explicitly
        return exercise
    }

    func testSettleMovesCommandDown() {
        let exercise = measuredExercise()
        exercise.settleCommand(to: 88)
        XCTAssertEqual(exercise.command, 88)
    }

    func testSettleAboveTheFloorLeavesTheFloorAlone() {
        let exercise = measuredExercise(working: 80, command: 100)
        exercise.settleCommand(to: 90)
        XCTAssertEqual(exercise.workingTempo, 80)
    }

    func testSettleOntoTheFloorPullsTheFloorDown() {
        let exercise = measuredExercise(working: 80, command: 100)
        exercise.settleCommand(to: 80)
        XCTAssertLessThan(exercise.workingTempo, 80)
    }

    func testSettleBelowTheFloorPullsTheFloorDown() {
        let exercise = measuredExercise(working: 80, command: 100)
        exercise.settleCommand(to: 65)
        XCTAssertLessThan(exercise.workingTempo, 65)
    }

    /// The defect the floor rule exists to prevent, asserted on the ramp the run actually plays.
    func testSettledRampKeepsItsWarmUpEvenWhenSettlingBelowTheOldFloor() {
        let exercise = measuredExercise(working: 80, command: 100)
        exercise.settleCommand(to: 65)
        let plateaus = exercise.ramp.plateaus
        XCTAssertEqual(plateaus.first?.bpm, exercise.rampFloor)
        XCTAssertLessThan(plateaus[0].bpm, exercise.command,
                          "a settled ramp must still climb to command, not open at it")
        XCTAssertGreaterThan(plateaus.count, 1)
    }

    func testSettledRampKeepsItsBackoffTail() {
        let exercise = measuredExercise(working: 80, command: 100)
        exercise.backoffTempoOverride = 94          // valid under command 100
        exercise.settleCommand(to: 90)              // …but caught up by the settle
        XCTAssertNil(exercise.backoffTempoOverride)
        let plateaus = exercise.ramp.plateaus
        XCTAssertLessThan(plateaus.last?.bpm ?? .max, exercise.command,
                          "a settled ramp must still end below command")
    }

    func testSettleKeepsAReachPinThatIsStillAboveCommand() {
        let exercise = measuredExercise(working: 80, command: 100)
        exercise.targetTempoOverride = 120
        exercise.settleCommand(to: 90)
        XCTAssertEqual(exercise.targetTempoOverride, 120,
                       "a goal still above command is not the settle's to discard")
    }

    func testSettleRebindsTheRhythmItWasMeasuredIn() {
        // A settled command is still a measurement, taken in this run's rhythm (ADR 0121).
        let exercise = measuredExercise()
        exercise.notesPerBeat = 4      // `noteRate` is derived; this is the stored axis
        exercise.settleCommand(to: 88)
        XCTAssertEqual(exercise.commandNotesPerBeat, 4)
    }

    func testSettleRecordsAnUnstatedRhythmAsUnstated() {
        let exercise = measuredExercise()
        exercise.notesPerBeat = nil
        exercise.settleCommand(to: 88)
        XCTAssertNil(exercise.commandNotesPerBeat)
    }

    // MARK: - Loop.settleCommand and its derived backoff

    private func measuredLoop(speed: Double = 0.8, command: Double = 0.9) -> Loop {
        let loop = Loop(name: "Chorus", start: 0.1, end: 0.3, speed: speed, repeats: 4)
        loop.promoteCommand(to: command)
        return loop
    }

    func testLoopSettleMovesCommandDown() {
        let loop = measuredLoop()
        loop.settleCommand(to: 0.82)
        XCTAssertEqual(loop.command, 0.82, accuracy: 0.0001)
    }

    func testLoopSettleClearsACaughtUpBackoffPin() {
        let loop = measuredLoop(speed: 0.8, command: 0.9)
        loop.backoffSpeedOverride = 0.85
        loop.settleCommand(to: 0.84)
        XCTAssertNil(loop.backoffSpeedOverride)
    }

    func testLoopSettleKeepsABackoffPinStillBelowCommand() {
        let loop = measuredLoop(speed: 0.8, command: 0.9)
        loop.backoffSpeedOverride = 0.75
        loop.settleCommand(to: 0.85)
        XCTAssertEqual(loop.backoffSpeedOverride ?? 0, 0.75, accuracy: 0.0001)
    }

    /// A loop needs no floor pull-down — `rampFloor` forces its own gap — so assert that rather than
    /// leaving the asymmetry with `Exercise` as an unwritten assumption.
    func testLoopFloorCannotInvertAfterASettle() {
        let loop = measuredLoop(speed: 0.9, command: 0.9)
        loop.settleCommand(to: 0.5)
        XCTAssertLessThan(loop.rampFloor, loop.command)
        XCTAssertEqual(loop.ramp.plateaus.first?.bpm, LoopCommandRamp.percent(loop.rampFloor))
    }

    /// The whole reason `backoffPercent` is derived once on the model (ADR 0134 §3): the tempo the
    /// offer proposes has to be the tempo the tail actually plays.
    func testLoopBackoffPercentMatchesTheTailTheRampEmits() {
        let loop = measuredLoop(speed: 0.8, command: 0.9)
        XCTAssertEqual(loop.ramp.plateaus.last?.bpm, loop.backoffPercent)
    }

    func testLoopBackoffPercentHonoursAPin() {
        let loop = measuredLoop(speed: 0.8, command: 0.9)
        loop.backoffSpeedOverride = 0.72
        XCTAssertEqual(loop.backoffPercent, 72)
        XCTAssertEqual(loop.ramp.plateaus.last?.bpm, 72)
    }

    // MARK: - The routine player's loop seam (ADR 0134 §8, wired in the v2 close-out)

    /// The anchors `RoutinePlayerView.revisionOffer(for:)` builds for a **loop block**, assembled here
    /// from the same expressions. Kept as a helper so the assertions below test the composition rather
    /// than restating it, and so a change to either side has to be made twice deliberately.
    private func routineLoopAnchors(_ loop: Loop) -> CommandOffer.Anchors {
        let range = TempoMath.percentRange
        return .init(command: LoopCommandRamp.percent(loop.command),
                     floor: range.lowerBound, ceiling: range.upperBound,
                     raiseTarget: CommandOffer.raisedCommand(
                        reach: LoopCommandRamp.percent(loop.targetSpeed),
                        ceiling: range.upperBound),
                     settleTarget: loop.backoffPercent)
    }

    /// The offer a routine's loop block makes has to describe the ramp that block just played. This is
    /// the assertion the unwired version could not have failed, because it returned `nil`.
    func testRoutineLoopAnchorsMatchTheRampTheBlockPlayed() {
        let loop = measuredLoop(speed: 0.8, command: 0.9)
        let anchors = routineLoopAnchors(loop)
        XCTAssertEqual(anchors.command, 90)
        XCTAssertEqual(anchors.settleTarget, loop.ramp.plateaus.last?.bpm)
        XCTAssertGreaterThan(anchors.raiseTarget, anchors.command)
    }

    /// Both leans have somewhere to go on an ordinary loop — the same room check the exercise side
    /// gets, asserted rather than assumed from "it's the same code" (§8).
    func testRoutineLoopOffersBothDirections() {
        let anchors = routineLoopAnchors(measuredLoop(speed: 0.8, command: 0.9))
        XCTAssertEqual(CommandOffer.stance(mastery: 5, anchors: anchors), .raise)
        XCTAssertEqual(CommandOffer.stance(mastery: 1, anchors: anchors), .settle)
        XCTAssertEqual(CommandOffer.stance(mastery: nil, anchors: anchors), .open)
        XCTAssertNil(CommandOffer.stance(mastery: 3, anchors: anchors))
    }

    /// The screen chooses a whole percent; the model stores `×`. `commitDone` converts with
    /// `Double(percent) / 100`, and the next offer reads back through `LoopCommandRamp.percent` — so
    /// the two have to be exact inverses or a settle would drift by a percent every time it was taken.
    func testRoutineLoopSettleRoundTripsThroughPercent() {
        for percent in [25, 63, 80, 99, 150] {
            let loop = measuredLoop(speed: 0.8, command: 1.5)
            loop.settleCommand(to: Double(percent) / 100)
            XCTAssertEqual(routineLoopAnchors(loop).command, percent, "settled to \(percent)%")
        }
    }

    /// The raise mirror, same conversion.
    func testRoutineLoopRaiseRoundTripsThroughPercent() {
        let loop = measuredLoop(speed: 0.8, command: 0.9)
        loop.promoteCommand(to: Double(112) / 100)
        XCTAssertEqual(routineLoopAnchors(loop).command, 112)
    }

    /// A loop's offer must never borrow BPM's bare digits — the value is a percent of a recording,
    /// and "90" on its own is a number from the exercise axis (ADR 0082).
    func testRoutineLoopOfferReadsInPercent() {
        XCTAssertEqual(TempoUnit.percent.inline(90), "90%")
        XCTAssertEqual(TempoUnit.percent.signpost(90), "90%")
    }
}
