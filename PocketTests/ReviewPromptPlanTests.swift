import XCTest
@testable import Pocket

/// The review ask's decisions (ADR 0214).
///
/// Every assertion is on the **`Outcome`, including the `Hold` reason** — never on "a value was
/// stored". That is ADR 0186's lesson applied before it can bite: a test that calls the seam and
/// checks a key is now non-nil is green against a build that asks on every single appearance, which
/// is precisely the failure this feature must not ship.
///
/// What cannot be tested, here or anywhere: **whether iOS actually drew the dialog.**
/// `requestReview()` returns `Void` with no callback, and the process is never told. These tests
/// prove what the app decided; nothing can prove what the player saw.
final class ReviewPromptPlanTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let version = "1.3"

    private func ask(_ daysAgo: Double, version: String) -> ReviewPromptPlan.Ask {
        ReviewPromptPlan.Ask(askedAt: now.addingTimeInterval(-daysAgo * 86_400), version: version)
    }

    private func decide(settled: Bool = true,
                        sittings: @autoclosure () -> Int = 50,
                        lastAsk: ReviewPromptPlan.Ask? = nil,
                        currentVersion: String? = nil,
                        now: Date? = nil) -> ReviewPromptPlan.Outcome {
        ReviewPromptPlan.decide(screenIsSettled: settled,
                                sittingCount: sittings(),
                                lastAsk: lastAsk,
                                currentVersion: currentVersion ?? version,
                                now: now ?? self.now)
    }

    // MARK: - The sitting threshold

    func testAsksOnceTheFifthSittingIsDone() {
        XCTAssertEqual(decide(sittings: 5), .ask)
    }

    func testFourSittingsIsNotEnough() {
        XCTAssertEqual(decide(sittings: 4), .hold(.tooFewSittings))
    }

    func testAnEmptyLogNeverAsks() {
        XCTAssertEqual(decide(sittings: 0), .hold(.tooFewSittings))
    }

    func testNeverAskedIsTheOnlyPathThatIgnoresTheGap() {
        XCTAssertEqual(decide(sittings: 5, lastAsk: nil), .ask)
    }

    // MARK: - The screen

    func testDoesNotAskWhileTheScreenIsUnsettled() {
        XCTAssertEqual(decide(settled: false, sittings: 500), .hold(.screenNotSettled))
    }

    /// The gate ordering, asserted directly — and **this is the one that cannot pass against a
    /// broken implementation.** Every other test here would still be green if `decide` evaluated the
    /// count eagerly; this one fails, because the count is what costs a SwiftData fetch on every
    /// single Home appearance for the life of the install.
    func testTheCountIsNotEvenReadWhenACheaperGateFails() {
        var reads = 0
        func count() -> Int {
            reads += 1
            return 500
        }

        _ = decide(settled: false, sittings: count())
        XCTAssertEqual(reads, 0, "an unsettled screen must be rejected before the log is touched")

        _ = decide(sittings: count(), lastAsk: ask(1, version: version))
        XCTAssertEqual(reads, 0, "having already asked under this version must short-circuit too")

        _ = decide(sittings: count())
        XCTAssertEqual(reads, 1, "and when the cheap gates pass, it is read exactly once")
    }

    // MARK: - Asking twice

    /// The headline test. Apple's own sample re-opens the ask on any version change; ours does not,
    /// because a release train would then ask every few weeks.
    func testAVersionBumpAloneDoesNotReopenTheAsk() {
        XCTAssertEqual(decide(lastAsk: ask(10, version: "1.3"), currentVersion: "1.4"),
                       .hold(.askedTooRecently))
    }

    func testTheSameVersionNeverAsksTwiceHoweverLongItHasBeen() {
        XCTAssertEqual(decide(lastAsk: ask(730, version: "1.3"), currentVersion: "1.3"),
                       .hold(.askedUnderThisVersion))
    }

    func testANewVersionAfterTheGapMayAskAgain() {
        XCTAssertEqual(decide(lastAsk: ask(200, version: "1.3"), currentVersion: "1.4"), .ask)
    }

    /// The boundary is inclusive, and it is written down here rather than left to be inferred from
    /// the `>=` in the source.
    func testExactlyTheGapIsEnough() {
        let lastAsk = ReviewPromptPlan.Ask(askedAt: now.addingTimeInterval(-ReviewPromptPlan.minimumGapBetweenAsks),
                                           version: "1.3")
        XCTAssertEqual(decide(lastAsk: lastAsk, currentVersion: "1.4"), .ask)
    }

    func testOneSecondShortOfTheGapIsNot() {
        let short = -ReviewPromptPlan.minimumGapBetweenAsks + 1
        let lastAsk = ReviewPromptPlan.Ask(askedAt: now.addingTimeInterval(short), version: "1.3")
        XCTAssertEqual(decide(lastAsk: lastAsk, currentVersion: "1.4"), .hold(.askedTooRecently))
    }

    // MARK: - Degrading

    /// Fails closed. An ask that never happens is invisible; a double-ask is not.
    func testAClockMovedBackwardsHoldsRatherThanAsks() {
        let future = ReviewPromptPlan.Ask(askedAt: now.addingTimeInterval(86_400), version: "1.3")
        XCTAssertEqual(decide(lastAsk: future, currentVersion: "1.4"), .hold(.askedTooRecently))
    }

    /// An unreadable `CFBundleShortVersionString` stores `""`, which matches `""` next launch, so the
    /// app goes quiet for good rather than asking on every appearance.
    func testAnUnreadableVersionNeverReAsks() {
        XCTAssertEqual(decide(lastAsk: ask(730, version: ""), currentVersion: ""),
                       .hold(.askedUnderThisVersion))
    }

    // MARK: - The constants themselves

    /// Both numbers are product decisions rather than implementation detail, so a change to either
    /// should have to walk past a test that names it.
    func testTheThresholdsAreTheOnesTheDecisionRecords() {
        XCTAssertEqual(ReviewPromptPlan.sittingsBeforeAsking, 5)
        XCTAssertEqual(ReviewPromptPlan.minimumGapBetweenAsks, 180 * 86_400)
    }

    /// Our gap is stricter than Apple's three-per-365, which is the whole argument for not modelling
    /// their budget: ours binds first, so theirs is never approached.
    func testOurGapIsStricterThanApplesOwnBudget() {
        XCTAssertGreaterThan(ReviewPromptPlan.minimumGapBetweenAsks, 365 * 86_400 / 3)
    }
}
