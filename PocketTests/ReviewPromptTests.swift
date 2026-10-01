import XCTest
@testable import Pocket

/// The review ask's **stored side** (ADR 0214) — that it asks once, records what it did, and cannot
/// be talked into asking twice.
///
/// Driven against a throwaway `UserDefaults` suite and an injected `ask:` closure. That closure is
/// the only reason this half is testable at all: `RequestReviewAction` exists only inside a live
/// SwiftUI environment, so the seam takes the call as a parameter rather than reaching for one.
///
/// **What no test here — or anywhere — can assert:** whether iOS drew the dialog. `requestReview()`
/// returns `Void` with no callback and the process is never told, on any timescale. These tests
/// prove the app asked. Nothing can prove the player was asked.
///
/// The class is **not** `@MainActor` and `setUp`/`tearDown` are not isolated, deliberately. CI builds
/// on an older, stricter toolchain than local Xcode, where mutating a main-actor-isolated stored
/// property from `XCTestCase`'s nonisolated `setUp` is an error rather than a warning — the same wall
/// the project's other `@MainActor` suites hit. `Analytics` *is* `@MainActor`, so the two calls that
/// touch it are wrapped in `MainActor.assumeIsolated`, which is sound because XCTest runs the
/// non-async `setUp`/`tearDown` pair on the main thread.
final class ReviewPromptTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var sink: RecordingSink!

    override func setUp() {
        super.setUp()
        suiteName = "ReviewPromptTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        let sink = RecordingSink()
        self.sink = sink
        MainActor.assumeIsolated { Analytics.resetForTesting(sink: sink, consent: { true }) }
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        sink = nil
        MainActor.assumeIsolated { Analytics.resetForTesting() }
        super.tearDown()
    }

    @MainActor
    @discardableResult
    private func askIfDue(settled: Bool = true,
                          sittings: Int = 50,
                          version: String = "1.3",
                          now: Date = Date(timeIntervalSince1970: 1_800_000_000),
                          ask: () -> Void = {}) -> ReviewPromptPlan.Outcome {
        ReviewPrompt.askIfDue(screenIsSettled: settled,
                              sittingCount: sittings,
                              version: version,
                              now: now,
                              defaults: defaults,
                              ask: ask)
    }

    // MARK: - Asking

    @MainActor
    func testAsksOnceAndThenNeverAgainUnderTheSameVersion() {
        var asks = 0
        XCTAssertEqual(askIfDue(ask: { asks += 1 }), .ask)
        XCTAssertEqual(asks, 1)

        XCTAssertEqual(askIfDue(ask: { asks += 1 }), .hold(.askedUnderThisVersion))
        XCTAssertEqual(asks, 1, "the second call must not reach the system")
    }

    @MainActor
    func testTheRecordSaysWhenAndUnderWhichVersion() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        askIfDue(version: "1.3", now: now)

        let data = try XCTUnwrap(defaults.data(forKey: "reviewPromptLastAsk"),
                                 "the ask must be recorded under a single key")
        let stored = try JSONDecoder().decode(ReviewPromptPlan.Ask.self, from: data)
        XCTAssertEqual(stored.version, "1.3")
        XCTAssertEqual(stored.askedAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }

    @MainActor
    func testHoldingWritesNothing() {
        var asks = 0
        XCTAssertEqual(askIfDue(settled: false, ask: { asks += 1 }), .hold(.screenNotSettled))
        XCTAssertEqual(asks, 0)
        XCTAssertNil(defaults.data(forKey: "reviewPromptLastAsk"))

        XCTAssertEqual(askIfDue(sittings: 1, ask: { asks += 1 }), .hold(.tooFewSittings))
        XCTAssertEqual(asks, 0)
        XCTAssertNil(defaults.data(forKey: "reviewPromptLastAsk"),
                     "a hold must leave no trace, or the next launch would think we had asked")
    }

    /// The ordering, asserted rather than assumed. Recording *before* the call is what makes a crash
    /// inside the system prompt safe — the app has already committed to having asked.
    @MainActor
    func testTheRecordIsWrittenBeforeTheAskIsMade() {
        var reentrantOutcome: ReviewPromptPlan.Outcome?
        var asks = 0

        askIfDue(ask: {
            asks += 1
            reentrantOutcome = self.askIfDue(ask: { asks += 1 })
        })

        XCTAssertEqual(reentrantOutcome, .hold(.askedUnderThisVersion),
                       "re-entering mid-ask must find the record already written")
        XCTAssertEqual(asks, 1)
    }

    @MainActor
    func testANewVersionAfterTheGapAsksAgain() {
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        var asks = 0

        askIfDue(version: "1.3", now: first, ask: { asks += 1 })
        askIfDue(version: "1.4",
                 now: first.addingTimeInterval(ReviewPromptPlan.minimumGapBetweenAsks),
                 ask: { asks += 1 })

        XCTAssertEqual(asks, 2)
    }

    // MARK: - Analytics

    @MainActor
    func testItEmitsExactlyOneReviewRequestedEventOnTheAsk() {
        askIfDue()
        XCTAssertEqual(sink.events, [.reviewRequested(trigger: .sittings)])
    }

    @MainActor
    func testAHoldEmitsNothing() {
        askIfDue(settled: false)
        askIfDue(sittings: 0)
        XCTAssertTrue(sink.events.isEmpty,
                      "an ask that never happened is not an event; it is the absence of one")
    }

    // MARK: - The debug reset

    @MainActor
    func testResettingForgetsOnlyOurOwnRecord() {
        askIfDue()
        XCTAssertNotNil(defaults.data(forKey: "reviewPromptLastAsk"))

        ReviewPrompt.resetForTesting(in: defaults)
        XCTAssertNil(defaults.data(forKey: "reviewPromptLastAsk"))

        var asks = 0
        XCTAssertEqual(askIfDue(ask: { asks += 1 }), .ask)
        XCTAssertEqual(asks, 1)
    }

    // MARK: - The Developer readout

    /// The readout must read the **same record** the ask writes, or a device check proves nothing:
    /// `requestReview()` returns no answer, so this record is the only thing a person can look at.
    @MainActor
    func testTheReadoutShowsTheRecordTheAskWrote() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func readout() -> ReviewPrompt.DebugState {
            ReviewPrompt.debugState(sittingCount: 5, version: "1.3", now: now, defaults: defaults)
        }
        XCTAssertNil(readout().lastAsk)
        XCTAssertEqual(readout().outcome, .ask)

        askIfDue(version: "1.3", now: now)
        XCTAssertEqual(readout().lastAsk, ReviewPromptPlan.Ask(askedAt: now, version: "1.3"))
        XCTAssertEqual(readout().outcome, .hold(.askedUnderThisVersion))

        ReviewPrompt.resetForTesting(in: defaults)
        XCTAssertNil(readout().lastAsk, "Reset must clear what the readout reads")
        XCTAssertEqual(readout().outcome, .ask)
    }

    @MainActor
    func testTheReadoutCountsWithTheSameThresholdAsTheAsk() {
        let state = ReviewPrompt.debugState(sittingCount: ReviewPromptPlan.sittingsBeforeAsking - 1,
                                            version: "1.3",
                                            defaults: defaults)
        XCTAssertEqual(state.sittings, ReviewPromptPlan.sittingsBeforeAsking - 1)
        XCTAssertEqual(state.outcome, .hold(.tooFewSittings))
    }
}
