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
