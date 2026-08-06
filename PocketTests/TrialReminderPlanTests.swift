import XCTest
@testable import Pocket

/// `TrialReminderPlan` — when, and whether, to warn a player that their trial is about to charge them
/// (ADR 0144 D6).
///
/// Exactly the logic AGENTS.md requires tests for: every "don't send this" branch fails **silently**.
/// A reminder that shouldn't have fired looks like nothing at all until it lands on somebody's lock
/// screen the day after they cancelled.
final class TrialReminderPlanTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var day: TimeInterval { 24 * 60 * 60 }

    // MARK: - Scheduling

    func testSchedulesOneLeadTimeBeforeTheTrialEnds() {
        let end = now.addingTimeInterval(30 * day)
        XCTAssertEqual(TrialReminderPlan.decide(trialEnd: end, willAutoRenew: true, now: now),
                       .schedule(end.addingTimeInterval(-day)))
    }

    func testLeadTimeIsOneDay() {
        XCTAssertEqual(TrialReminderPlan.leadTime, 86_400)
    }

    func testHonoursACustomLeadTime() {
        let end = now.addingTimeInterval(10 * day)
        XCTAssertEqual(
            TrialReminderPlan.decide(trialEnd: end, willAutoRenew: true, leadTime: 2 * day, now: now),
            .schedule(end.addingTimeInterval(-2 * day)))
    }

    // MARK: - The four reasons to stay quiet

    func testNoTrialEndMeansNothingToWarnAbout() {
        XCTAssertEqual(TrialReminderPlan.decide(trialEnd: nil, willAutoRenew: true, now: now), .cancel)
    }

    /// The load-bearing one. Someone who has already cancelled will not be charged; reminding them
    /// anyway is a retention nag wearing an honesty costume.
    func testCancelledTrialIsNeverReminded() {
        let end = now.addingTimeInterval(30 * day)
        XCTAssertEqual(TrialReminderPlan.decide(trialEnd: end, willAutoRenew: false, now: now), .cancel)
    }

    func testAnEndedTrialIsNotWarnedAbout() {
        XCTAssertEqual(
            TrialReminderPlan.decide(trialEnd: now.addingTimeInterval(-day), willAutoRenew: true, now: now),
            .cancel)
    }

    /// Inside the lead time, the reminder's own promise ("24 hours to decide") is already false, so it
    /// isn't sent at all rather than sent late.
    func testDoesNotFireWhenTheLeadTimeHasAlreadyPassed() {
        XCTAssertEqual(
            TrialReminderPlan.decide(trialEnd: now.addingTimeInterval(3 * 3600),
                                     willAutoRenew: true, now: now),
            .cancel)
    }

    /// The boundary: a fire date exactly *at* now is behind us by the time anything delivers it.
    func testFireDateExactlyNowIsCancelled() {
        XCTAssertEqual(
            TrialReminderPlan.decide(trialEnd: now.addingTimeInterval(day), willAutoRenew: true, now: now),
            .cancel)
        XCTAssertEqual(
            TrialReminderPlan.decide(trialEnd: now.addingTimeInterval(day + 60),
                                     willAutoRenew: true, now: now),
            .schedule(now.addingTimeInterval(60)))
    }

    // MARK: - Countdown

    func testDaysRemainingRoundsUpSoALiveTrialNeverReadsZero() {
        XCTAssertEqual(TrialReminderPlan.daysRemaining(trialEnd: now.addingTimeInterval(30 * day),
                                                       now: now), 30)
        XCTAssertEqual(TrialReminderPlan.daysRemaining(trialEnd: now.addingTimeInterval(1.5 * day),
                                                       now: now), 2)
        XCTAssertEqual(TrialReminderPlan.daysRemaining(trialEnd: now.addingTimeInterval(60),
                                                       now: now), 1,
                       "A minute left is still a live trial — it must not read 0 days")
    }

    func testDaysRemainingIsNilWithoutALiveTrial() {
        XCTAssertNil(TrialReminderPlan.daysRemaining(trialEnd: nil, now: now))
        XCTAssertNil(TrialReminderPlan.daysRemaining(trialEnd: now, now: now))
        XCTAssertNil(TrialReminderPlan.daysRemaining(trialEnd: now.addingTimeInterval(-1), now: now))
    }
}
