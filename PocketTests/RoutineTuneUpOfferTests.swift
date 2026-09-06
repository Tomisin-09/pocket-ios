import XCTest
@testable import Pocket

/// The tune-up offer's whole rule (ADR 0195). Pure, so the "never repeated within a session" half is
/// a tested fact — `RoutinePlayerView.onAppear` re-fires on every return to the front, and that is
/// exactly the sort of thing that breaks silently (AGENTS.md).
final class RoutineTuneUpOfferTests: XCTestCase {

    func testOffersWhenEnabledAndUndecided() {
        XCTAssertTrue(RoutineTuneUpOffer.shouldOffer(alreadyDecided: false,
                                                     isEnabled: true, hasStages: true))
    }

    func testDoesNotOfferWhenTheSettingIsOff() {
        XCTAssertFalse(RoutineTuneUpOffer.shouldOffer(alreadyDecided: false,
                                                      isEnabled: false, hasStages: true))
    }

    /// An all-orphaned routine lands on the summary, not a run — there is nothing to prepare for.
    func testDoesNotOfferForARoutineWithNothingToPlay() {
        XCTAssertFalse(RoutineTuneUpOffer.shouldOffer(alreadyDecided: false,
                                                      isEnabled: true, hasStages: false))
    }

    /// The one that matters: a second appear, mid-routine, must not put the offer up again.
    func testNeverOffersTwiceInOneSession() {
        XCTAssertFalse(RoutineTuneUpOffer.shouldOffer(alreadyDecided: true,
                                                      isEnabled: true, hasStages: true))
    }
}
