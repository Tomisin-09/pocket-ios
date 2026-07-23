import XCTest
@testable import Pocket

/// The **scale reference catalog** (pocket-172) — the pure pitch-class formulas the custom-scale canvas
/// ghosts as a tracing guide. Verifies the symmetric scales it exists for, and that reusing the
/// `GuitarScale` formulas keeps the two in step. All SwiftUI-free (the repo's pure-logic rule).
final class ScaleReferenceTests: XCTestCase {

    // MARK: - Catalog integrity

    func testCatalogIncludesSymmetricScalesAndEveryGuitarScale() {
        let names = ScaleReference.all.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "duplicate reference names")
        // The three symmetric scales the canvas exists for.
        for symmetric in ["Whole Tone", "Diminished (whole–half)", "Diminished (half–whole)"] {
            XCTAssertTrue(names.contains(symmetric), "missing symmetric scale \(symmetric)")
        }
        // Every GuitarScale is reused by display name (so the two never drift).
        for scale in GuitarScale.allCases {
            XCTAssertTrue(names.contains(scale.displayName), "missing reuse of \(scale.displayName)")
        }
        XCTAssertEqual(ScaleReference.all.count,
                       ScaleReference.symmetric.count + GuitarScale.allCases.count)
    }

    func testArpeggioCatalogReusesEveryQualityFormula() {
        let names = ScaleReference.arpeggios.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "duplicate arpeggio reference names")
        XCTAssertEqual(ScaleReference.arpeggios.count, ArpeggioQuality.allCases.count)
        // Each arpeggio reference reuses its `ArpeggioQuality` formula (so the two never drift), and
        // ghosts the same pitch classes the generated box would sound.
        for quality in ArpeggioQuality.allCases {
            let reference = ScaleReference.arpeggios.first { $0.name == quality.displayName }
            XCTAssertEqual(reference?.pitchClasses(root: 9),
                           Set(quality.intervals.map { (9 + $0) % 12 }),
                           "the \(quality.displayName) arpeggio reference reuses its chord-tone formula")
        }
    }

    // MARK: - Pitch-class formulas

    func testWholeToneIsSixWholeSteps() {
        let wholeTone = ScaleReference.symmetric[0]
        XCTAssertEqual(wholeTone.pitchClasses(root: 0), [0, 2, 4, 6, 8, 10], "C whole tone")
    }

    func testDiminishedFormulasAtC() {
        let wholeHalf = ScaleReference.all.first { $0.name == "Diminished (whole–half)" }
        let halfWhole = ScaleReference.all.first { $0.name == "Diminished (half–whole)" }
        XCTAssertEqual(wholeHalf?.pitchClasses(root: 0), [0, 2, 3, 5, 6, 8, 9, 11])
        XCTAssertEqual(halfWhole?.pitchClasses(root: 0), [0, 1, 3, 4, 6, 7, 9, 10])
    }

    // MARK: - Symmetry (the reason these can't be CAGED boxes)

    func testWholeToneRepeatsEveryWholeStep() {
        let wholeTone = ScaleReference.symmetric[0]
        XCTAssertEqual(wholeTone.pitchClasses(root: 0), wholeTone.pitchClasses(root: 2),
                       "a whole-tone scale is the same six notes a whole step up")
    }

    func testDiminishedRepeatsEveryMinorThird() {
        let dim = ScaleReference.symmetric[1]   // whole–half
        XCTAssertEqual(dim.pitchClasses(root: 0), dim.pitchClasses(root: 3),
                       "a diminished scale is the same eight notes a minor third up")
    }

    // MARK: - Reused formulas match GuitarScale

    func testReusedScaleMatchesItsGuitarScaleFormula() {
        let reference = ScaleReference.all.first { $0.name == GuitarScale.minorPentatonic.displayName }
        XCTAssertEqual(reference?.pitchClasses(root: 9),
                       GuitarScale.minorPentatonic.pitchClasses(root: 9),
                       "the reference reuses the GuitarScale formula, so the pitch classes match")
    }
}
