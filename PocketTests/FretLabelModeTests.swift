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
