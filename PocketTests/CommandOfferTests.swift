import XCTest
@testable import Pocket

/// Pure post-run **command revision** math (ADR 0079, widened by ADR 0134): the direction the offer
/// points, the raised-command target, and the settled-command target. Exercised as plain values — no
/// engine/UI — because this is exactly the tempo boundary logic that breaks silently (AGENTS.md).
final class CommandOfferTests: XCTestCase {

    /// The exercise device range the cases below revise against.
    private let ceiling = StandaloneMetronomeEngine.bpmRange.upperBound
    private let floor = StandaloneMetronomeEngine.bpmRange.lowerBound

    /// A drill at command 100 with room in both directions.
    private func anchors(command: Int = 100, raise: Int = 106, settle: Int = 94,
                         floor: Int? = nil, ceiling: Int? = nil) -> CommandOffer.Anchors {
        .init(command: command, floor: floor ?? self.floor, ceiling: ceiling ?? self.ceiling,
              raiseTarget: raise, settleTarget: settle)
    }

    // MARK: - Stance: the rating chooses the lean (ADR 0134 §2)

    func testUnratedLeansNeitherWay() {
        // The app has been told nothing, so it presumes nothing — a neutral prompt over a range that
        // spans both directions.
        XCTAssertEqual(CommandOffer.preferredStance(mastery: nil), .open)
        XCTAssertEqual(CommandOffer.stance(mastery: nil, anchors: anchors()), .open)
    }

    func testLowRatingsLeanSettle() {
        for rating in 0...2 {
            XCTAssertEqual(CommandOffer.stance(mastery: rating, anchors: anchors()), .settle,
                           "mastery \(rating) should lean settle")
        }
    }

    func testMiddleRatingOffersNothing() {
        // The deliberate dead band — "fine" is not a request to change anything (§2).
        XCTAssertNil(CommandOffer.preferredStance(mastery: 3))
        XCTAssertNil(CommandOffer.stance(mastery: 3, anchors: anchors()))
    }

    func testHighRatingsLeanRaise() {
        for rating in 4...5 {
            XCTAssertEqual(CommandOffer.stance(mastery: rating, anchors: anchors()), .raise,
                           "mastery \(rating) should lean raise")
        }
    }

    // MARK: - Stance: the room decides whether it survives

    func testRaiseIsWithheldWhenTheReachIsNotAboveCommand() {
        // Command has caught up to the reach — nothing to raise to, so no row (ADR 0079 §5).
        XCTAssertNil(CommandOffer.stance(mastery: 5, anchors: anchors(raise: 100)))
        XCTAssertNil(CommandOffer.stance(mastery: 5, anchors: anchors(raise: 98)))
    }

    func testRaiseIsWithheldAtTheCeilingEvenWithAnOvershootingReach() {
        // Command at the ceiling, auto-reach past it (300 × 1.06 = 318): the clamped raise equals
        // command, so the offer would be a no-op.
        XCTAssertNil(CommandOffer.stance(mastery: 5, anchors: anchors(command: ceiling, raise: 318)))
    }

    func testSettleIsWithheldAtTheFloor() {
        // Already as low as the instrument goes — nowhere to settle to.
        XCTAssertNil(CommandOffer.stance(mastery: 1, anchors: anchors(command: floor, settle: 30)))
    }

    func testSettleSurvivesOneStepAboveTheFloor() {
        XCTAssertEqual(CommandOffer.stance(mastery: 1, anchors: anchors(command: floor + 1)), .settle)
    }

    func testSettleIsOfferedEvenWithHeadroomAbove() {
        // A drill with plenty of room to grow still leans settle when rated low — the rating leads,
        // not the headroom.
        XCTAssertEqual(CommandOffer.stance(mastery: 2, anchors: anchors()), .settle)
    }

    func testOpenSurvivesAtTheCeilingBecauseItCanStillGoDown() {
        // A neutral offer needs only *an* axis, not headroom in particular.
        XCTAssertEqual(CommandOffer.stance(mastery: nil, anchors: anchors(command: ceiling,
                                                                          raise: 318)), .open)
    }

    // MARK: - Bounds: what each lean opens on and how far it reaches

    func testOpenSpansTheInstrumentAndOpensOnCommandItself() {
        // The honest neutral: toggling it on and committing without moving the stepper changes
        // nothing, because the app has proposed no tempo at all.
        let bounds = CommandOffer.bounds(for: .open, anchors: anchors())
        XCTAssertEqual(bounds?.defaultTarget, 100)
        XCTAssertEqual(bounds?.minValue, floor)
        XCTAssertEqual(bounds?.maxValue, ceiling)
    }

    func testRaiseOpensOnTheReachAndStaysAboveCommand() {
        let bounds = CommandOffer.bounds(for: .raise, anchors: anchors())
        XCTAssertEqual(bounds?.defaultTarget, 106)
        XCTAssertEqual(bounds?.minValue, 101)
        XCTAssertEqual(bounds?.maxValue, ceiling)
    }

    func testSettleOpensOnTheBackoffAndReachesTheFloor() {
        // Opens on the tempo the tail played, but ranges the whole way down — the step back is
        // sometimes twenty, not four (§4).
        let bounds = CommandOffer.bounds(for: .settle, anchors: anchors())
        XCTAssertEqual(bounds?.defaultTarget, 94)
        XCTAssertEqual(bounds?.minValue, floor)
        XCTAssertEqual(bounds?.maxValue, 99)
    }

    func testSettleBoundsClampADefaultThatIsNotBelowCommand() {
        // `includeBackoff` off, or a stale pin: the derived value can land on or above command.
        let bounds = CommandOffer.bounds(for: .settle, anchors: anchors(settle: 120))
        XCTAssertEqual(bounds?.defaultTarget, 99)
    }

    func testBoundsAreNilWhenTheLeanHasNowhereToGo() {
        XCTAssertNil(CommandOffer.bounds(for: .raise, anchors: anchors(raise: 100)))
        XCTAssertNil(CommandOffer.bounds(for: .settle, anchors: anchors(command: floor)))
    }

    // MARK: - The committed revision follows the value, not the lean

    func testValueAboveCommandCommitsARaise() {
        XCTAssertEqual(CommandOffer.revision(value: 108, command: 100), .raise(108))
    }

    func testValueBelowCommandCommitsASettle() {
        XCTAssertEqual(CommandOffer.revision(value: 88, command: 100), .settle(88))
    }

    func testValueEqualToCommandCommitsNothing() {
        // Reachable from an `open` offer, and must write nothing rather than a no-op.
        XCTAssertNil(CommandOffer.revision(value: 100, command: 100))
    }

    // MARK: - Raised-command target (min(ceiling, reach))

    func testRaisesUpToTheReachBelowCeiling() {
        XCTAssertEqual(CommandOffer.raisedCommand(reach: 106, ceiling: 300), 106)
    }

    func testClampsToCeilingWhenReachWouldExceedIt() {
        // A reach past the device ceiling raises only to the ceiling.
        XCTAssertEqual(CommandOffer.raisedCommand(reach: 315, ceiling: 300), 300)
    }

    func testRaisesToReachExactlyAtCeiling() {
        XCTAssertEqual(CommandOffer.raisedCommand(reach: 300, ceiling: 300), 300)
    }

    // MARK: - Settled-command target (the backoff the run already played)

    func testSettlesToTheBackoffTheRunPlayed() {
        // Command 100, reach 106 ⇒ derived backoff 94: the tempo the tail actually sounded (§3).
        XCTAssertEqual(CommandOffer.settledCommand(backoff: 94, floor: 30, command: 100), 94)
    }

    func testSettleIsFlooredAtTheInstrumentFloor() {
        XCTAssertEqual(CommandOffer.settledCommand(backoff: 20, floor: 30, command: 100), 30)
    }

    func testSettleStaysStrictlyBelowCommandWhenTheBackoffDoesNot() {
        // `includeBackoff` off, or a stale pin: the derived value can land on or above command, where
        // accepting would be a no-op.
        XCTAssertEqual(CommandOffer.settledCommand(backoff: 100, floor: 30, command: 100), 99)
        XCTAssertEqual(CommandOffer.settledCommand(backoff: 120, floor: 30, command: 100), 99)
    }

    func testSettleOneAboveTheFloorLandsOnTheFloor() {
        XCTAssertEqual(CommandOffer.settledCommand(backoff: 30, floor: 30, command: 31), 30)
    }

    // MARK: - Loop units (ADR 0082) — same math, percent-of-original, capped by the speed axis

    /// The playback range a loop run revises against. Read from the speed axis, not written as
    /// literals, so the tests move with it when it does (ADR 0124 took the ceiling 200% → 150%). From
    /// `TempoMath` rather than `LoopRunView`, whose copy is main-actor isolated and unreadable here.
    private var loopCeiling: Int { TempoMath.percentRange.upperBound }
    private var loopFloor: Int { TempoMath.percentRange.lowerBound }

    private func loopAnchors(command: Int = 85, raise: Int = 90,
                             settle: Int = 80) -> CommandOffer.Anchors {
        .init(command: command, floor: loopFloor, ceiling: loopCeiling,
              raiseTarget: raise, settleTarget: settle)
    }

    func testLoopPercentRaiseMovesCommandToReach() {
        // A loop run (Loop 3 in the design): command 85%, summited reach 90% → lean raise, open on 90.
        XCTAssertEqual(CommandOffer.stance(mastery: 5, anchors: loopAnchors()), .raise)
        XCTAssertEqual(CommandOffer.bounds(for: .raise, anchors: loopAnchors())?.defaultTarget, 90)
    }

    func testLoopPercentRaiseClampsToThePlaybackCeiling() {
        XCTAssertEqual(CommandOffer.raisedCommand(reach: loopCeiling + 10, ceiling: loopCeiling),
                       loopCeiling)
    }

    func testLoopPercentSettleDropsTowardTheBackoffPercent() {
        // The same loop rated 2: lean settle, opening on the 80% its tail played.
        XCTAssertEqual(CommandOffer.stance(mastery: 2, anchors: loopAnchors()), .settle)
        let bounds = CommandOffer.bounds(for: .settle, anchors: loopAnchors())
        XCTAssertEqual(bounds?.defaultTarget, 80)
        XCTAssertEqual(bounds?.minValue, loopFloor)
    }

    func testLoopPercentSettleIsFlooredAtThePlaybackFloor() {
        let bounds = CommandOffer.bounds(for: .settle, anchors: loopAnchors(settle: loopFloor - 10))
        XCTAssertEqual(bounds?.defaultTarget, loopFloor)
    }

    // MARK: - Tempo unit labels (ADR 0082)

    func testExerciseUnitIsBPM() {
        // Inline (in a "Move command to …" phrase) reads bare; a standalone signpost carries "BPM".
        XCTAssertEqual(TempoUnit.bpm.inline(106), "106")
        XCTAssertEqual(TempoUnit.bpm.signpost(106), "106 BPM")
    }

    func testLoopUnitIsPercentEverywhere() {
        // A loop's tempo is a percent of original — always a "%", inline or standalone, never "BPM".
        XCTAssertEqual(TempoUnit.percent.inline(90), "90%")
        XCTAssertEqual(TempoUnit.percent.signpost(90), "90%")
    }
}
