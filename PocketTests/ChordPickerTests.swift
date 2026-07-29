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

    func testInsertMovableSetIsTheWholeOfTierOne() {
        // ADR 0122: all twelve, not the curated six — the shapes already existed, so showing half of
        // them read as a gap. Identity with `tier1` is the point: nothing to keep in step by hand.
        XCTAssertEqual(ChordPicker.insertMovableGrips, ChordGrip.tier1)
        XCTAssertEqual(ChordPicker.insertMovableGrips.count, 12)
        let qualities = Set(ChordPicker.insertMovableGrips.map(\.quality))
        XCTAssertEqual(qualities, [.major, .minor, .dom7, .min7, .maj7, .fifth])
        let families = Set(ChordPicker.insertMovableGrips.map(\.name))
        XCTAssertEqual(families, ["E-shape", "A-shape"], "both shape families are present")
        // Tier 2 stays in Build → Movable shape, so the Insert grid doesn't become the whole catalog.
        XCTAssertTrue(qualities.isDisjoint(with: [.sus2, .sus4, .sixth, .dom9, .maj9, .min9]))
    }

    func testInsertCarriesTierTwoAsItsOwnSet() {
        // ADR 0122: the suspensions / 6ths / 9ths moved into Insert as their own section when
        // `MovableChordSheet` was retired — that sheet was the only door to them, so folding them in is
        // what makes retiring it lossless rather than a removal.
        XCTAssertEqual(ChordPicker.insertTier2Grips, ChordGrip.tier2)
        let qualities = Set(ChordPicker.insertTier2Grips.map(\.quality))
        XCTAssertEqual(qualities, [.sus2, .sus4, .sixth, .dom9, .maj9, .min9])
    }

    func testInsertNowOffersTheWholeCuratedMovableVocabulary() {
        // Tier 1 + Tier 2 = `ChordGrip.curated`, so nothing a player could reach through the old Build
        // pane is unreachable now. This is the test that would fail if a future grip were added to
        // `curated` without a home in the picker.
        let offered = ChordPicker.insertMovableGrips + ChordPicker.insertTier2Grips
        XCTAssertEqual(Set(offered.map { "\($0.name)-\($0.quality)" }),
                       Set(ChordGrip.curated.map { "\($0.name)-\($0.quality)" }))
    }

    func testTierTwoChipsShareTheMovableSubtitleAndSearchText() {
        // They're barres like their Tier-1 kin, so they reuse the movable chip vocabulary rather than
        // needing a third label style.
        XCTAssertEqual(ChordPicker.movableSubtitle(.aShapeSus4), "A-shape barre")
        let text = ChordPicker.movableSearchText(.aShapeSus4)
        XCTAssertTrue(ChordPicker.matches(query: "sus4", in: text))
        XCTAssertTrue(ChordPicker.matches(query: "a-shape", in: text))
    }

    func testTierOneOrderLaysEachFamilyOutOnWholeRows() {
        // The grid is three columns; `tier1` runs family-then-quality, so E-shapes fill rows 1–2 and
        // A-shapes rows 3–4 rather than interleaving mid-row.
        let families = ChordPicker.insertMovableGrips.map(\.name)
        XCTAssertEqual(Array(families.prefix(6)), Array(repeating: "E-shape", count: 6))
        XCTAssertEqual(Array(families.suffix(6)), Array(repeating: "A-shape", count: 6))
    }

    func testPowerChordSubtitleIsNotCalledABarre() {
        XCTAssertEqual(ChordPicker.movableSubtitle(.eShapeFifth), "E-shape")
        XCTAssertEqual(ChordPicker.movableSubtitle(.eShapeMajor), "E-shape barre")
        let text = ChordPicker.movableSearchText(.aShapeFifth)
        XCTAssertTrue(ChordPicker.matches(query: "power", in: text))
        XCTAssertFalse(ChordPicker.matches(query: "barre", in: text), "a power chord is not a barre")
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
