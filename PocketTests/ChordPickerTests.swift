import XCTest
@testable import Pocket

/// Pure-logic coverage for the chord picker (ADR 0103): the browse picture placement, the movable
/// Insert set, and the live search match. UI-free, per the repo's pure-logic rule.
final class ChordPickerTests: XCTestCase {

    // MARK: - browseVoicing (ADR 0103 D4)

    func testEShapeBrowseVoicingBarresAtFretFive() {
        // E-shape root is the low E (open pc 4); fret 5 lands the root on A.
        let voicing = ChordGrip.eShapeMajor.browseVoicing
        XCTAssertEqual(voicing.lowestFret, 5, "E-shape browse picture should barre at fret 5")
        XCTAssertEqual(voicing.frets[5], 5, "root sits on the low-E string at fret 5")
        XCTAssertEqual(voicing.name, "A", "fret-5 E-shape major is A")
    }

    func testAShapeBrowseVoicingBarresAtFretFive() {
        // A-shape root is the A string (open pc 9); fret 5 lands the root on D.
        let voicing = ChordGrip.aShapeMinor.browseVoicing
        XCTAssertEqual(voicing.lowestFret, 5, "A-shape browse picture should barre at fret 5")
        XCTAssertEqual(voicing.frets[4], 5, "root sits on the A string at fret 5")
        XCTAssertEqual(voicing.name, "Dm", "fret-5 A-shape minor is Dm")
    }

    func testBrowseVoicingIsAlwaysPlayable() {
        for grip in ChordPicker.insertMovableGrips {
            XCTAssertTrue(grip.browseVoicing.isValid, "\(grip.quality) \(grip.name) browse picture invalid")
        }
    }

    // MARK: - Insert movable set

    func testInsertMovableSetIsTheSixEverydayBarres() {
        XCTAssertEqual(ChordPicker.insertMovableGrips.count, 6)
        let qualities = Set(ChordPicker.insertMovableGrips.map(\.quality))
        XCTAssertEqual(qualities, [.major, .minor, .dom7], "Insert offers maj/min/dom7 only")
        let families = Set(ChordPicker.insertMovableGrips.map(\.name))
        XCTAssertEqual(families, ["E-shape", "A-shape"], "both barre families are present")
    }

    // MARK: - Search match (ADR 0103 D1)

    func testEmptyQueryMatchesEverything() {
        XCTAssertTrue(ChordPicker.matches(query: "", in: "Cmaj7"))
        XCTAssertTrue(ChordPicker.matches(query: "   ", in: "anything"))
    }

    func testMatchIsCaseInsensitiveSubstring() {
        XCTAssertTrue(ChordPicker.matches(query: "MAJ", in: "Cmaj7"))
        XCTAssertTrue(ChordPicker.matches(query: "am", in: "Am"))
        XCTAssertFalse(ChordPicker.matches(query: "dim", in: "Cmaj7"))
    }

    func testMovableSearchTextMatchesQualityAndFamily() {
        let text = ChordPicker.movableSearchText(.eShapeDom7)
        XCTAssertTrue(ChordPicker.matches(query: "dominant", in: text))
        XCTAssertTrue(ChordPicker.matches(query: "e-shape", in: text))
        XCTAssertTrue(ChordPicker.matches(query: "barre", in: text))
        XCTAssertFalse(ChordPicker.matches(query: "a-shape", in: text))
    }
}
