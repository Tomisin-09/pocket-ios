import CoreGraphics
import SwiftUI
import XCTest
@testable import Pocket

/// The song player's hold tips (ADR 0244): which tag shows, when none may, how a retired one is
/// stored, and where a tag sits beside its control. Everything here is pure; what only a driven run
/// shows — that a real control is ringed and its hold still lands — is `GestureHintUITests`.
final class GestureHintTests: XCTestCase {

    private let all = Set(GestureHint.allCases)

    private func candidates(enabled: Bool = true,
                            retired: Set<GestureHint> = [],
                            outstanding: Bool = false,
                            seen: Bool = false,
                            shown: GestureHint? = nil) -> Set<GestureHint> {
        GestureHintPolicy.candidates(enabled: enabled, retired: retired, walkthroughOutstanding: outstanding,
                                     walkthroughSeenThisOpening: seen, shownThisOpening: shown)
    }

    // MARK: - The catalogue

    /// The raw values are stored in the retired set. A rename would bring a retired tag back.
    func testTheStoredNamesAreFrozen() {
        XCTAssertEqual(GestureHint.allCases.map(\.rawValue), [
            "waveform.loopRow", "waveform.metronome", "waveform.bpm",
            "waveform.markerRow", "waveform.panelHeader", "waveform.songTitle"
        ])
    }

    /// Every tag says what to hold first, and none uses the internal name.
    func testEveryTagStartsWithTheHoldAndSaysRedMoonNeverPocket() {
        for hint in GestureHint.allCases {
            XCTAssertTrue(hint.text.hasPrefix("Hold "), "\(hint) doesn't start with what to hold")
            XCTAssertTrue(hint.text.hasSuffix("."), "\(hint) isn't a sentence")
            XCTAssertFalse(hint.text.contains("Pocket"), "\(hint) names the target, not the app")
        }
    }

    // MARK: - Candidates

    func testWithNothingRetiredEveryTagIsInPlay() {
        XCTAssertEqual(candidates(), all)
    }

    /// D6: the switch in Settings ▸ Song player turns every tag off.
    func testTurnedOffNoTagIsInPlay() {
        XCTAssertEqual(candidates(enabled: false), [])
    }

    /// D4: used or closed is for good.
    func testARetiredTagIsNeverInPlayAgain() {
        XCTAssertEqual(candidates(retired: [.loopRow, .bpm]), all.subtracting([.loopRow, .bpm]))
        XCTAssertEqual(candidates(retired: all), [])
    }

    /// D3: the walkthrough's session comes first — while it waits for the next song, and through the
    /// opening that ran it, nothing else is offered.
    func testTheWalkthroughHoldsEveryTagBack() {
        XCTAssertEqual(candidates(outstanding: true), [], "armed: the next song opened runs it")
        XCTAssertEqual(candidates(seen: true), [], "this opening ran it")
        XCTAssertEqual(candidates(seen: true, shown: .loopRow), [], "it outranks a tag already shown")
    }

    /// D5: one tag an opening. Once one has shown it is the only one in play until it is used or closed.
    func testOnceATagHasShownItIsTheOnlyOneThisOpening() {
        XCTAssertEqual(candidates(shown: .markerRow), [.markerRow])
        XCTAssertEqual(candidates(retired: [.markerRow], shown: .markerRow), [],
                       "closing the one tag of the opening doesn't let the next one in")
    }

    // MARK: - Openings

    /// D5: half an hour in the background is opening the app again — the practice log's sitting gap.
    func testComingBackAfterHalfAnHourIsANewOpening() {
        let away = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let gap = GestureHintPolicy.openingGap
        XCTAssertEqual(gap, 30 * 60)
        XCTAssertEqual(gap, PracticeLog.sittingGap, "an opening and a sitting start on the same break")
        XCTAssertFalse(GestureHintPolicy.isNewOpening(awaySince: nil, now: away), "never away")
        XCTAssertFalse(GestureHintPolicy.isNewOpening(awaySince: away, now: away + gap - 1), "a second short")
        XCTAssertTrue(GestureHintPolicy.isNewOpening(awaySince: away, now: away + gap))
        XCTAssertTrue(GestureHintPolicy.isNewOpening(awaySince: away, now: away + 3 * 86_400), "days away")
        XCTAssertFalse(GestureHintPolicy.isNewOpening(awaySince: away, now: away - gap), "the clock went back")
    }

    /// The opening as `PocketApp` drives it: only the background counts as away, it counts from when the
    /// app first went there, and a new opening clears both the latch and the walkthrough's hold.
    @MainActor
    func testANewOpeningClearsTheLatchAndTheWalkthroughsHold() {
        let opening = GestureHintOpening()
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let minute: TimeInterval = 60
        opening.shown = .bpm
        opening.walkthroughSeen = true

        opening.sceneChanged(to: .inactive, at: start)
        opening.sceneChanged(to: .active, at: start + 45 * minute)
        XCTAssertEqual(opening.shown, .bpm, "inactive is a glance, however long")

        opening.sceneChanged(to: .background, at: start + 50 * minute)
        opening.sceneChanged(to: .active, at: start + 79 * minute)
        XCTAssertEqual(opening.shown, .bpm, "29 minutes away is the same opening")
        XCTAssertTrue(opening.walkthroughSeen)

        // Away at 80; a pass through inactive at 90 and back to the background must not restart the clock.
        opening.sceneChanged(to: .background, at: start + 80 * minute)
        opening.sceneChanged(to: .inactive, at: start + 90 * minute)
        opening.sceneChanged(to: .background, at: start + 100 * minute)
        opening.sceneChanged(to: .active, at: start + 110 * minute)
        XCTAssertNil(opening.shown, "30 minutes from first going away is a new opening")
        XCTAssertFalse(opening.walkthroughSeen, "the walkthrough's opening is over")

        opening.shown = .loopRow
        opening.sceneChanged(to: .active, at: start + 200 * minute)
        XCTAssertEqual(opening.shown, .loopRow, "coming back clears the time away")
    }

    // MARK: - Which one

    /// The order of the cases is the rank: of what is on screen and in play, the first wins.
    func testTheHighestRankedTagOnScreenWins() {
        XCTAssertEqual(GestureHintPolicy.next(onScreen: all, candidates: all), .loopRow)
        XCTAssertEqual(GestureHintPolicy.next(onScreen: [.songTitle, .bpm, .markerRow], candidates: all), .bpm)
    }

    /// A tag points at something the player can hold now, or it doesn't show.
    func testATagWhoseControlIsOffScreenDoesNotShow() {
        XCTAssertEqual(GestureHintPolicy.next(onScreen: [.songTitle], candidates: [.loopRow]), nil)
        XCTAssertEqual(GestureHintPolicy.next(onScreen: [], candidates: all), nil)
        XCTAssertEqual(GestureHintPolicy.next(onScreen: [.loopRow, .songTitle], candidates: [.songTitle]),
                       .songTitle, "a retired higher rank doesn't block a lower one")
    }

    // MARK: - Storage

    func testRetiringAddsOnceAndSortsTheStoredString() {
        let once = GestureHintPolicy.retiring(.songTitle, in: "")
        XCTAssertEqual(once, "waveform.songTitle")
        let twice = GestureHintPolicy.retiring(.bpm, in: once)
        XCTAssertEqual(twice, "waveform.bpm,waveform.songTitle")
        XCTAssertEqual(GestureHintPolicy.retiring(.bpm, in: twice), twice, "already there: the same string")
        XCTAssertEqual(GestureHintPolicy.retired(twice), [.bpm, .songTitle])
    }

    /// A name written by a later build that knows a seventh tag survives this one, so a downgrade and
    /// an upgrade don't bring that tag back.
    func testAnUnknownStoredNameSurvivesARoundTrip() {
        let later = "waveform.somethingNew"
        let stored = GestureHintPolicy.retiring(.loopRow, in: later)
        XCTAssertEqual(GestureHintPolicy.storedNames(stored), [later, "waveform.loopRow"])
        XCTAssertEqual(GestureHintPolicy.retired(stored), [.loopRow])
        XCTAssertEqual(GestureHintPolicy.retired(",,"), [], "stray separators are nothing")
    }

    // MARK: - Settings

    func testTheLedgerRetiresRestoresAndResets() throws {
        let suite = "GestureHintTests"
        let store = try XCTUnwrap(UserDefaults(suiteName: suite))
        store.removePersistentDomain(forName: suite)
        defer { store.removePersistentDomain(forName: suite) }
        let retired = { GestureHintPolicy.retired(store.string(forKey: AppSettings.Key.gestureHintsRetired) ?? "") }

        AppSettings.retireGestureHint(.loopRow, store: store)
        AppSettings.retireGestureHint(.loopRow, store: store)
        AppSettings.retireGestureHint(.metronome, store: store)
        XCTAssertEqual(retired(), [.loopRow, .metronome])

        AppSettings.restoreGestureHints(store: store)
        XCTAssertEqual(retired(), [])

        store.set(false, forKey: AppSettings.Key.gestureHints)
        AppSettings.retireGestureHint(.bpm, store: store)
        AppSettings.resetGestureHints(store: store)
        XCTAssertEqual(retired(), [])
        XCTAssertNil(store.object(forKey: AppSettings.Key.gestureHints), "the switch goes back to its default")
        XCTAssertTrue(AppSettings.gestureHintsDefault, "on until turned off (ADR 0195)")
    }

    /// Off under `-uiTesting`, so no tag sits on the suite's controls or the manual's figures; on
    /// everywhere else, and to the test that asks.
    func testTheTipsAreOpenOutsideUITestsAndToTheTestThatAsks() {
        let uiTesting = UITestHooks.launchArgument
        XCTAssertTrue(UITestRuntime.parseGestureHints(in: []))
        XCTAssertFalse(UITestRuntime.parseGestureHints(in: [uiTesting]))
        XCTAssertTrue(UITestRuntime.parseGestureHints(in: [uiTesting, UITestHooks.gestureHintsArgument]))
    }

    // MARK: - Placement

    private let screen = CGRect(x: 0, y: 0, width: 393, height: 760)

    func testATagSitsAboveItsControlWhenThereIsRoom() {
        let row = CGRect(x: 16, y: 500, width: 300, height: 44)
        let width = GestureHintPlacement.width(in: screen)
        let placement = GestureHintPlacement.make(target: row, bounds: screen, width: width)
        XCTAssertTrue(placement.above)
        XCTAssertEqual(width, 300, "capped, so a tag never spans a wide screen")
        XCTAssertEqual(placement.leading, row.midX - width / 2, accuracy: 0.001, "centred on the control")
        XCTAssertEqual(placement.caretX, width / 2, accuracy: 0.001)
    }

    /// The song's name sits under the status bar: there is no room above it.
    func testATagGoesBelowAControlAtTheTop() {
        let title = CGRect(x: 60, y: 4, width: 200, height: 40)
        let placement = GestureHintPlacement.make(target: title, bounds: screen, width: 300)
        XCTAssertFalse(placement.above)
    }

    /// A control hard against the side keeps the tag on screen, and the caret still points at it.
    func testATagStaysOnScreenAndItsCaretFollowsTheControl() {
        // Where the speed bar's metronome disc sits: inside the panel's padding, near the right edge.
        let metronome = CGRect(x: 326, y: 300, width: 30, height: 30)
        let width = GestureHintPlacement.width(in: screen)
        let placement = GestureHintPlacement.make(target: metronome, bounds: screen, width: width)
        XCTAssertEqual(placement.leading + width, screen.maxX - GestureHintPlacement.margin, accuracy: 0.001)
        XCTAssertEqual(placement.leading + placement.caretX, metronome.midX, accuracy: 0.001)

        // Closer to the edge than any control sits, the caret stops short of the rounded corner.
        let corner = CGRect(x: 360, y: 300, width: 20, height: 30)
        let cornered = GestureHintPlacement.make(target: corner, bounds: screen, width: width)
        XCTAssertEqual(cornered.caretX, width - GestureHintPlacement.caretInset, accuracy: 0.001)

        let leftEdge = CGRect(x: 0, y: 300, width: 10, height: 30)
        let left = GestureHintPlacement.make(target: leftEdge, bounds: screen, width: width)
        XCTAssertEqual(left.leading, GestureHintPlacement.margin, accuracy: 0.001)
        XCTAssertEqual(left.caretX, GestureHintPlacement.caretInset, accuracy: 0.001,
                       "the caret stops at the tag's rounded corner")
    }

    func testANarrowScreenNarrowsTheTag() {
        let narrow = CGRect(x: 0, y: 0, width: 200, height: 400)
        XCTAssertEqual(GestureHintPlacement.width(in: narrow), 200 - 2 * GestureHintPlacement.margin)
        XCTAssertEqual(GestureHintPlacement.width(in: .zero), 0)
    }
}
