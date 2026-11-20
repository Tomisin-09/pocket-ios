import XCTest
@testable import Pocket

/// A chord read against the song's key (ADR 0308 D6): the numeral, the degree its colour comes from, and
/// whether it's the key's own. The examples are the ADR's own.
final class ChordNumeralTests: XCTestCase {

    // Pitch classes.
    private let cRoot = 0, dRoot = 2, eRoot = 4, fRoot = 5, gRoot = 7, gSharp = 8, aRoot = 9, bFlat = 10,
                bRoot = 11, cSharp = 1

    private func read(_ root: Int, _ suffix: String = "", in key: MusicalKey) throws -> ChordNumeral {
        try XCTUnwrap(ChordNumeral.read(root: root, suffix: suffix, in: key))
    }

    func testTheKeysOwnOneIsI() throws {
        let aMinorChord = try read(aRoot, "m", in: .aMinor)
        XCTAssertEqual(aMinorChord.numeral, "i")
        XCTAssertEqual(aMinorChord.degree, 1)
        XCTAssertTrue(aMinorChord.isKeysOwn)
        XCTAssertEqual(try read(cRoot, in: .cMajor).numeral, "I")
    }

    func testTheCaseSaysTheKindAndASeventhFollows() throws {
        XCTAssertEqual(try read(gRoot, in: .aMinor).numeral, "VII")
        XCTAssertEqual(try read(gRoot, "7", in: .aMinor).numeral, "VII7", "G is never read as G7")
        XCTAssertEqual(try read(cRoot, "maj7", in: .aMinor).numeral, "IIImaj7")
        XCTAssertEqual(try read(dRoot, "m7", in: .cMajor).numeral, "ii7")
        XCTAssertEqual(try read(bRoot, "dim", in: .cMajor).numeral, "vii°")
        XCTAssertEqual(try read(bRoot, "m7♭5", in: .cMajor).numeral, "viiø7")
        XCTAssertEqual(try read(cRoot, "aug", in: .cMajor).numeral, "I+")
        XCTAssertEqual(try read(gRoot, "sus4", in: .cMajor).numeral, "Vsus4")
        XCTAssertEqual(try read(aRoot, "mMaj7", in: .cMajor).numeral, "vimaj7")
    }

    func testTheColourComesFromTheRootsDegreeAlone() throws {
        XCTAssertEqual(try read(eRoot, in: .aMinor).degree, 5)
        XCTAssertEqual(try read(eRoot, "m", in: .aMinor).degree, 5, "E and Em are both the 5")
    }

    func testAnotherKindOnARootInTheKeyIsOutlinedAndSaysTheKeysOwn() throws {
        let dMajor = try read(dRoot, in: .aMinor)
        XCTAssertEqual(dMajor.numeral, "IV")
        XCTAssertEqual(dMajor.degree, 4, "it keeps its root's colour")
        XCTAssertFalse(dMajor.isKeysOwn)
        XCTAssertTrue(dMajor.isOutlined)
        XCTAssertEqual(dMajor.keysOwn, "iv", "A minor's own here: iv")

        let fMinor = try read(fRoot, "m", in: .cMajor)
        XCTAssertEqual(fMinor.numeral, "iv")
        XCTAssertEqual(fMinor.keysOwn, "IV")
        XCTAssertEqual(try read(cRoot, "aug", in: .cMajor).keysOwn, "I")
    }

    func testAMinorKeyTakesVAndViiDiminishedAsItsOwn() throws {
        let eMajor = try read(eRoot, in: .aMinor)
        XCTAssertEqual(eMajor.numeral, "V")
        XCTAssertTrue(eMajor.isKeysOwn)
        XCTAssertFalse(eMajor.isOutlined)
        let leading = try read(gSharp, "dim", in: .aMinor)
        XCTAssertEqual(leading.numeral, "vii°", "not ♯vii°: the leading tone's chord is the key's own")
        XCTAssertEqual(leading.degree, 7)
        XCTAssertTrue(leading.isKeysOwn)
        XCTAssertEqual(try read(gSharp, "dim7", in: .aMinor).numeral, "vii°7")
    }

    func testARootOutsideTheKeyIsSilverWithItsAccidental() throws {
        let flatSeven = try read(bFlat, in: .cMajor)
        XCTAssertEqual(flatSeven.numeral, "♭VII")
        XCTAssertNil(flatSeven.degree, "silver")
        XCTAssertFalse(flatSeven.isOutlined, "silver, not outlined")
        XCTAssertNil(flatSeven.keysOwn)
        XCTAssertEqual(try read(cSharp, "m", in: .aMinor).numeral, "♯iii")
        XCTAssertEqual(try read(gSharp, in: .aMinor).numeral, "♯VII", "a major chord on the leading tone isn't vii°")
    }

    func testAnOpenChordIsNeverOutlined() throws {
        XCTAssertTrue(try read(dRoot, "5", in: .aMinor).isKeysOwn)
        XCTAssertTrue(try read(eRoot, "sus4", in: .aMinor).isKeysOwn)
    }

    func testNoKeyMeansNoNumeral() {
        XCTAssertNil(ChordNumeral.read(root: aRoot, suffix: "m", in: .unknown))
    }

    /// A song raised or lowered (ADR 0305) moves the key and the chords together, so nothing renumbers.
    func testMovingTheKeyAndTheChordsTogetherKeepsTheNumerals() throws {
        for shift in 1...6 {
            let key = MusicalKey.aMinor.moved(by: shift)
            XCTAssertEqual(try read(aRoot + shift, "m", in: key).numeral, "i")
            XCTAssertEqual(try read(gRoot + shift, in: key).numeral, "VII")
            XCTAssertEqual(try read(dRoot + shift, in: key).keysOwn, "iv")
        }
    }
}
