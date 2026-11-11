import XCTest
@testable import Pocket

/// `FretLabelMode`'s **rootless** rules (2026-07-28). Interval captions need a tonal centre
/// (`FretboardDrill.rootPitchClass`); the generated scale and arpeggio runs carry one, but a
/// hand-drawn drill, a warm-up and a picking run don't. Offering Interval there drew nothing at all,
/// which read as a broken option rather than an inapplicable one — so a rootless surface both hides
/// the mode and resolves an inherited one, and both rules are pure and live here.
final class FretLabelModeTests: XCTestCase {

    // MARK: - Which modes a surface offers

    func testRootedSurfaceOffersEveryMode() {
        XCTAssertEqual(FretLabelMode.available(hasRoot: true), FretLabelMode.allCases)
    }

    func testRootlessSurfaceDropsIntervalOnly() {
        let modes = FretLabelMode.available(hasRoot: false)
        XCTAssertFalse(modes.contains(.interval))
        XCTAssertEqual(modes, [.none, .note], "Off and Note both still work without a root")
    }

    // MARK: - Resolving an inherited mode

    /// The caption preference is **global**, so a player who chose Interval on a scale then opens a
    /// hand-drawn drill arrives carrying a mode that surface can't spell. It resolves to Off, which is
    /// what the board already drew — the point is that the picker now agrees with it.
    func testIntervalResolvesToOffWithoutARoot() {
        XCTAssertEqual(FretLabelMode.interval.resolved(hasRoot: false), .none)
    }

    func testIntervalSurvivesWhereThereIsARoot() {
        XCTAssertEqual(FretLabelMode.interval.resolved(hasRoot: true), .interval)
    }

    /// Only Interval is conditional — nothing else changes meaning without a root, and resolving must
    /// never quietly rewrite a mode the surface can honour.
    func testEveryOtherModeResolvesToItself() {
        for mode in [FretLabelMode.none, .note] {
            XCTAssertEqual(mode.resolved(hasRoot: false), mode)
            XCTAssertEqual(mode.resolved(hasRoot: true), mode)
        }
    }

    /// Resolving lands on a mode the surface actually offers — the property the picker relies on to
    /// keep its selection in range once Interval is hidden.
    func testResolvedModeIsAlwaysOffered() {
        for hasRoot in [true, false] {
            for mode in FretLabelMode.allCases {
                XCTAssertTrue(FretLabelMode.available(hasRoot: hasRoot).contains(mode.resolved(hasRoot: hasRoot)),
                              "\(mode) resolved out of range for hasRoot: \(hasRoot)")
            }
        }
    }
}

/// `EditorSummary.line` — the collapsed-disclosure summary budget (2026-07-28). The row sits beside its
/// title on one line, so a run with several non-default settings has to be summarised rather than
/// listed; the `+N` count keeps "there is more in here" visible, which a mid-word ellipsis did not.
final class EditorSummaryTests: XCTestCase {

    func testEmptyPartsSummariseToNothing() {
        XCTAssertEqual(EditorSummary.line([]), "")
    }

    func testShortListIsSpelledOutInFull() {
        XCTAssertEqual(EditorSummary.line(["Quarters"]), "Quarters")
        XCTAssertEqual(EditorSummary.line(["Quarters", "1 octave"]), "Quarters · 1 octave")
    }

    /// The case that motivated it: five deviations on one scale run.
    func testLongListKeepsTwoAndCountsTheRest() {
        let parts = ["Quarters", "1 octave", "Groups of 4", "One way", "From lowest note"]
        XCTAssertEqual(EditorSummary.line(parts), "Quarters · 1 octave +3")
    }

    /// Exactly one over the limit still counts rather than spelling the last one out — otherwise the
    /// row's width would jump about as settings cross the boundary.
    func testOneOverTheLimitCounts() {
        XCTAssertEqual(EditorSummary.line(["a", "b", "c"]), "a · b +1")
    }

    /// The count is always the number actually withheld, at any limit.
    func testCountMatchesWhatIsWithheld() {
        for count in 1...8 {
            let parts = (1...count).map { "item \($0)" }
            for limit in 1...4 {
                let line = EditorSummary.line(parts, showing: limit)
                if count <= limit {
                    XCTAssertFalse(line.contains("+"), "\(count) items at limit \(limit) fits")
                } else {
                    XCTAssertTrue(line.hasSuffix("+\(count - limit)"),
                                  "\(count) items at limit \(limit) → \(line)")
                }
            }
        }
    }
}

/// `FretboardRun.movementSummaryParts` — what the picking-run editor's collapsed **Movement** row says
/// (ADR 0293). Up and back moved in with its Coming back, so the row leads with the path every time
/// rather than reading "Off" over a run that still comes back; the rest is only what deviates.
final class MovementSummaryTests: XCTestCase {

    private func run(roundTrip: Bool = true, returnStyle: ReturnStyle = .retrace,
                     shift: Int = 0, passes: Int = 1, stagger: Int = 0) -> FretboardRun {
        FretboardRun(fingers: [1, 2, 3, 4], baseFret: 1, fromString: 0, toString: 5,
                     roundTrip: roundTrip, fretShiftPerPass: shift, passCount: passes,
                     fretShiftPerString: stagger, returnStyle: returnStyle)
    }

    /// The defaults say the path, never nothing and never "Off".
    func testDefaultsReadAsTheRoundTrip() {
        XCTAssertEqual(run().movementSummaryParts, ["Up and back"])
        XCTAssertEqual(run(roundTrip: false).movementSummaryParts, ["One way"])
    }

    /// Restate only means something on the way back, so a one-way run doesn't mention it.
    func testRestateShowsOnlyWhenTheRunComesBack() {
        XCTAssertEqual(run(returnStyle: .restate).movementSummaryParts, ["Up and back", "restate"])
        XCTAssertEqual(run(roundTrip: false, returnStyle: .restate).movementSummaryParts, ["One way"])
    }

    func testClimbAndStaggerFollowThePath() {
        XCTAssertEqual(run(shift: 2, passes: 3).movementSummaryParts, ["Up and back", "↑2/run × 3"])
        XCTAssertEqual(run(stagger: -1).movementSummaryParts, ["Up and back", "diag −1"])
        XCTAssertEqual(run(roundTrip: false, shift: 1, passes: 2, stagger: 2).movementSummaryParts,
                       ["One way", "↑1/run × 2", "diag +2"])
    }

    /// Everything on at once still fits the row: two spelled out, the rest counted.
    func testEverythingOnIsBudgetedByTheSummaryLine() {
        let parts = run(returnStyle: .restate, shift: 2, passes: 3, stagger: 1).movementSummaryParts
        XCTAssertEqual(EditorSummary.line(parts), "Up and back · restate +2")
    }

    /// A true minus sign, so "−1" doesn't read as a hyphen beside "+1".
    func testSignedFretsUsesATrueMinus() {
        XCTAssertEqual(FretboardRun.signedFrets(2), "+2")
        XCTAssertEqual(FretboardRun.signedFrets(-2), "−2")
        XCTAssertEqual(FretboardRun.signedFrets(0), "+0")
    }
}
