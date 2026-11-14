import XCTest
@testable import Pocket

/// What a **swap** knows about the chord it replaces (ADR 0297) — the root the picker opens on and the
/// shape it marks, read back off a voicing's frets. Pure, so it is tested here rather than through the
/// sheet: a wrong reading would open the picker on the wrong root or mark the wrong chip, and nothing on
/// screen would say why.
final class ChordPickerCurrentTests: XCTestCase {

    // MARK: - Grips read back exactly

    func testEveryPlaceableGripAtEveryRootReadsBackAsItself() {
        // The property the whole feature stands on: placing a grip is deterministic, so its frets name
        // it. This is also the collision check — if two grips ever drew the same frets at some root,
        // the swap would mark the wrong one, and this would say which.
        for grip in ChordPicker.placeableGrips {
            for root in 0..<12 {
                let voicing = grip.voicing(rootPitchClass: root)
                let placement = ChordPicker.gripPlacement(of: voicing)
                XCTAssertEqual(placement?.grip, grip,
                               "\(grip.quality) \(grip.name) inv \(grip.inversion) at \(root) read back as "
                                   + "\(placement.map { "\($0.grip.quality) \($0.grip.name)" } ?? "nothing")")
                XCTAssertEqual(placement?.rootPitchClass, root)
            }
        }
    }

    func testThePlaceableSetIsEveryGripTheInsertGridPlaces() {
        // A grip added to Insert but not here would be a chip a swap can never mark.
        let inserted = ChordPicker.insertMovableGrips + ChordPicker.insertTriadGrips + ChordPicker.insertTier2Grips
        XCTAssertEqual(ChordPicker.placeableGrips.count, inserted.count)
        for grip in inserted {
            XCTAssertTrue(ChordPicker.placeableGrips.contains(grip))
        }
    }

    func testTheNameDoesNotMatterOnlyTheFrets() {
        // A♯ and B♭ are one placement (ADR 0123 — names follow the accidental preference). A chord saved
        // under a name of the player's own is the same grip too.
        let flat = ChordGrip.aShapeMin7.voicing(rootPitchClass: 10, spelling: .flats)
        let renamed = ChordVoicing("My jazz thing", frets: flat.frets)
        XCTAssertEqual(ChordPicker.gripPlacement(of: renamed)?.grip, .aShapeMin7)
        XCTAssertEqual(ChordPicker.gripPlacement(of: renamed)?.rootPitchClass, 10)
    }

    func testATriadInversionOpensOnItsRootNotItsBassNote() {
        // First inversion has the 3rd in the bass — C major's E. Reading the bass would open the root
        // row on E, and the shape would be "wrong" at every root after it.
        let cFirst = ChordGrip.triadGBEMajor1.voicing(rootPitchClass: 0)
        XCTAssertNotEqual(cFirst.rootPitchClass, 0, "precondition: the bass note isn't the root")
        let current = ChordPickerCurrent(cFirst)
        XCTAssertEqual(current.rootPitchClass, 0)
        XCTAssertEqual(current.grip, .triadGBEMajor1)
    }

    // MARK: - Open shapes and custom chords

    func testOpenShapesThatAreAGripAtTheNutReadAsThatGrip() {
        // Open E is the E-shape at fret 0 and open Am the A-shape minor there — so a swap from them can
        // slide the shape, which is the barre the open chord grows into.
        XCTAssertEqual(ChordPickerCurrent(.eMajor).grip, .eShapeMajor)
        XCTAssertEqual(ChordPickerCurrent(.aMinor).grip, .aShapeMinor)
        XCTAssertEqual(ChordPickerCurrent(.fBarre).grip, .eShapeMajor)
        XCTAssertEqual(ChordPickerCurrent(.fBarre).rootPitchClass, 5)
    }

    func testAnOpenShapeWithNoGripStillOpensOnItsRoot() {
        let current = ChordPickerCurrent(.cMajor)
        XCTAssertNil(current.grip, "open C is not a movable shape")
        XCTAssertEqual(current.rootPitchClass, 0)
        XCTAssertTrue(current.isCurrent(frets: ChordVoicing.cMajor.frets))
        XCTAssertFalse(current.isCurrent(frets: ChordVoicing.cMajor7.frets))
    }

    func testASlashChordOpensOnTheChordNotTheBass() {
        // D/F♯ — F♯ on the low E. The chord is D; the root row should say so.
        let slash = ChordVoicing("D/F#", frets: [2, 3, 2, 0, nil, 2])
        let current = ChordPickerCurrent(slash)
        XCTAssertNil(current.grip)
        XCTAssertEqual(current.rootPitchClass, 2)
    }

    func testAChordPlacedBeforeTheFiveStringAShapeStillHasARoot() {
        // ADR 0122 moved the A-shape from four strings to five. A Cm placed under the old geometry no
        // longer matches a grip — nothing is marked — but it still opens on C.
        let oldCm = ChordVoicing("Cm", frets: [nil, 4, 5, 5, 3, nil])
        let current = ChordPickerCurrent(oldCm)
        XCTAssertNil(current.grip)
        XCTAssertEqual(current.rootPitchClass, 0)
    }

    func testASilentVoicingHasNoRoot() {
        let silent = ChordVoicing("", frets: [nil, nil, nil, nil, nil, nil])
        XCTAssertNil(ChordPickerCurrent(silent).rootPitchClass, "nothing to open on — the row stays on Any")
    }

    // MARK: - Bass

    func testABassShapeReadsBackAtAnyOfItsPlacements() {
        for shape in BassChordShape.all {
            for voicing in shape.voicings() {
                let current = ChordPickerCurrent(voicing)
                XCTAssertEqual(current.bassShape, shape, "\(shape.name) \(voicing.frets) read back wrong")
                XCTAssertEqual(current.rootPitchClass, voicing.rootPitchClass)
                XCTAssertNil(current.grip, "a four-string chord is never a guitar grip")
            }
        }
    }

    // MARK: - Fixed chips under a root

    func testAnyRootKeepsEveryFixedChip() {
        for voicing in ChordVoicing.library {
            XCTAssertTrue(ChordPicker.fixedChord(voicing, isAt: nil))
        }
    }

    func testAChosenRootNarrowsFixedChipsToChordsOfThatRoot() {
        let atA = ChordVoicing.library.filter { ChordPicker.fixedChord($0, isAt: 9) }.map(\.name)
        XCTAssertEqual(Set(atA), ["A", "Am", "A7", "Am triad"])
        let atC = ChordVoicing.library.filter { ChordPicker.fixedChord($0, isAt: 0) }.map(\.name)
        XCTAssertEqual(Set(atC), ["C", "C7", "Cmaj7", "C triad"])
    }

    // MARK: - Search reads what the chip shows

    func testAPlacedChipIsFoundByTheChordItShows() {
        let text = ChordPicker.movableSearchText(.aShapeMin7, placedName: "Cm7")
        XCTAssertTrue(ChordPicker.matches(query: "cm7", in: text))
        XCTAssertTrue(ChordPicker.matches(query: "a-shape", in: text), "the shape words still match")
        XCTAssertFalse(ChordPicker.matches(query: "cm7", in: ChordPicker.movableSearchText(.aShapeMin7)),
                       "on Any there is no chord name to find")
        let triad = ChordPicker.triadSearchText(.triadGBEMajor1, placedName: "C")
        XCTAssertTrue(triad.hasPrefix("C "))
    }
}
