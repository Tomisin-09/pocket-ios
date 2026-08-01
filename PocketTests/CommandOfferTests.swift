import XCTest
@testable import Pocket

/// Pure post-run **command revision** math (ADR 0079, widened by ADR 0134): the direction the offer
/// points, the raised-command target, and the settled-command target. Exercised as plain values — no
/// engine/UI — because this is exactly the tempo boundary logic that breaks silently (AGENTS.md).
final class CommandOfferTests: XCTestCase {

    /// The exercise device range the cases below revise against.
    private let ceiling = StandaloneMetronomeEngine.bpmRange.upperBound
    private let floor = StandaloneMetronomeEngine.bpmRange.lowerBound

    // MARK: - Direction: the rating chooses (ADR 0134 §2)

    func testUnratedOffersARaise() {
        // The pre-0134 behaviour, preserved exactly: a player who ignores the dots sees the screen
        // they already know.
        XCTAssertEqual(CommandOffer.direction(mastery: nil, command: 100, reach: 106,
                                              floor: floor, ceiling: ceiling), .raise)
    }

    func testLowRatingsOfferASettle() {
        for rating in 0...2 {
            XCTAssertEqual(CommandOffer.direction(mastery: rating, command: 100, reach: 106,
                                                  floor: floor, ceiling: ceiling), .settle,
                           "mastery \(rating) should offer a settle")
        }
    }

    func testMiddleRatingOffersNothing() {
        // The deliberate dead band — "fine" is not a request to change anything (§2).
        XCTAssertNil(CommandOffer.direction(mastery: 3, command: 100, reach: 106,
                                            floor: floor, ceiling: ceiling))
    }

    func testHighRatingsOfferARaise() {
        for rating in 4...5 {
            XCTAssertEqual(CommandOffer.direction(mastery: rating, command: 100, reach: 106,
                                                  floor: floor, ceiling: ceiling), .raise,
                           "mastery \(rating) should offer a raise")
        }
    }

    // MARK: - Direction: the room decides whether it survives

    func testRaiseIsWithheldWhenTheReachIsNotAboveCommand() {
        // Command has caught up to the reach — nothing to raise to, so no row (ADR 0079 §5).
        XCTAssertNil(CommandOffer.direction(mastery: 5, command: 100, reach: 100,
                                            floor: floor, ceiling: ceiling))
        XCTAssertNil(CommandOffer.direction(mastery: nil, command: 100, reach: 98,
                                            floor: floor, ceiling: ceiling))
    }

    func testRaiseIsWithheldAtTheCeilingEvenWithAnOvershootingReach() {
        // Command at the ceiling, auto-reach past it (300 × 1.06 = 318): the clamped raise equals
        // command, so the offer would be a no-op.
        XCTAssertNil(CommandOffer.direction(mastery: 5, command: ceiling, reach: 318,
                                            floor: floor, ceiling: ceiling))
    }

    func testSettleIsWithheldAtTheFloor() {
        // Already as low as the instrument goes — there is nowhere to settle to.
        XCTAssertNil(CommandOffer.direction(mastery: 1, command: floor, reach: 40,
                                            floor: floor, ceiling: ceiling))
    }

    func testSettleSurvivesOneStepAboveTheFloor() {
        XCTAssertEqual(CommandOffer.direction(mastery: 1, command: floor + 1, reach: 40,
                                              floor: floor, ceiling: ceiling), .settle)
    }

    func testSettleIsOfferedEvenWithHeadroomAbove() {
        // A drill with plenty of room to grow still offers the settle when the player rates it low —
        // the rating leads, not the headroom.
        XCTAssertEqual(CommandOffer.direction(mastery: 2, command: 100, reach: 106,
                                              floor: floor, ceiling: ceiling), .settle)
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

    func testLoopPercentRaiseMovesCommandToReach() {
        // A loop run (Loop 3 in the design): command 85%, summited reach 90% → offer, raise to 90.
        XCTAssertEqual(CommandOffer.direction(mastery: 5, command: 85, reach: 90,
                                              floor: loopFloor, ceiling: loopCeiling), .raise)
        XCTAssertEqual(CommandOffer.raisedCommand(reach: 90, ceiling: loopCeiling), 90)
    }

    func testLoopPercentRaiseClampsToThePlaybackCeiling() {
        // A reach past the ceiling raises only to the ceiling.
        XCTAssertEqual(CommandOffer.raisedCommand(reach: loopCeiling + 10, ceiling: loopCeiling),
                       loopCeiling)
    }

    func testLoopPercentSettleDropsTowardTheBackoffPercent() {
        // The same loop rated 2: settle from 85% toward the 80% its tail played.
        XCTAssertEqual(CommandOffer.direction(mastery: 2, command: 85, reach: 90,
                                              floor: loopFloor, ceiling: loopCeiling), .settle)
        XCTAssertEqual(CommandOffer.settledCommand(backoff: 80, floor: loopFloor, command: 85), 80)
    }

    func testLoopPercentSettleIsFlooredAtThePlaybackFloor() {
        XCTAssertEqual(CommandOffer.settledCommand(backoff: loopFloor - 10, floor: loopFloor,
                                                   command: 85), loopFloor)
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
