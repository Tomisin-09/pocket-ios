import XCTest
@testable import Pocket

/// The pure **chord-change timing** (ADR 0065): which chord is active at a beat position, cycle
/// wrapping, count-in handling, and the pure editing helpers. All SwiftUI-free (T5).
final class ChordProgressionTests: XCTestCase {

    private let pop = ChordProgression.gMajorPop  // G(4) · D(4) · Em(4) · C(4) = 16 beats

    // MARK: - Cycle geometry

    func testLengthIsTheSumOfHolds() {
        XCTAssertEqual(pop.lengthInBeats, 16)
        XCTAssertEqual(pop.changeCount, 4)
    }

    func testBeatOffsets() {
        XCTAssertEqual(pop.beatOffset(ofChange: 0), 0)
        XCTAssertEqual(pop.beatOffset(ofChange: 1), 4)
        XCTAssertEqual(pop.beatOffset(ofChange: 2), 8)
        XCTAssertEqual(pop.beatOffset(ofChange: 3), 12)
    }

    // MARK: - Active chord over the beat grid

    func testActiveChordAtBeatBoundaries() {
        XCTAssertEqual(pop.activeIndex(atBeat: 0), 0)      // G
        XCTAssertEqual(pop.activeIndex(atBeat: 3.9), 0)
        XCTAssertEqual(pop.activeIndex(atBeat: 4), 1)      // D
        XCTAssertEqual(pop.activeIndex(atBeat: 7.5), 1)
        XCTAssertEqual(pop.activeIndex(atBeat: 8), 2)      // Em
        XCTAssertEqual(pop.activeIndex(atBeat: 12), 3)     // C
        XCTAssertEqual(pop.activeIndex(atBeat: 15.9), 3)
    }

    func testProgressionWrapsAtTheCycleLength() {
        XCTAssertEqual(pop.activeIndex(atBeat: 16), 0, "one cycle later, back to G")
        XCTAssertEqual(pop.activeIndex(atBeat: 20), 1, "16 + 4 → D")
    }

    func testCountInAndEmptyReturnNil() {
        XCTAssertNil(pop.activeIndex(atBeat: -1), "before beat 0 nothing is active")
        XCTAssertNil(pop.activeIndex(atBeat: .infinity))
        XCTAssertNil(ChordProgression(changes: []).activeIndex(atBeat: 0))
    }

    func testUnevenHoldsMapCorrectly() {
        // Two bars of G, one of C: G held 8, C held 4 → 12-beat cycle.
        let progression = ChordProgression(changes: [
            ChordChange(.gMajor, beats: 8), ChordChange(.cMajor, beats: 4)
        ])
        XCTAssertEqual(progression.activeIndex(atBeat: 7.5), 0)
        XCTAssertEqual(progression.activeIndex(atBeat: 8), 1)
        XCTAssertEqual(progression.activeIndex(atBeat: 12), 0, "wraps back to G")
    }

    func testNextIndexWraps() {
        XCTAssertEqual(pop.nextIndex(after: 0), 1)
        XCTAssertEqual(pop.nextIndex(after: 3), 0)
        XCTAssertNil(ChordProgression(changes: []).nextIndex(after: 0))
    }

    // MARK: - Pure editing helpers

    func testAppendRemoveReplaceAndRebeat() {
        let grown = pop.appending(.aMinor, beats: 2)
        XCTAssertEqual(grown.changeCount, 5)
        XCTAssertEqual(grown.changes.last?.beats, 2)
        XCTAssertEqual(grown.changes.last?.voicing, .aMinor)

        let trimmed = grown.removingChange(at: 4)
        XCTAssertEqual(trimmed.changeCount, 4)

        let revoiced = pop.replacingVoicing(at: 0, with: .fBarre)
        XCTAssertEqual(revoiced.changes[0].voicing, .fBarre)
        XCTAssertEqual(revoiced.changes[0].beats, 4, "hold is preserved when re-voicing")

        let rebeat = pop.settingBeats(at: 1, to: 2)
        XCTAssertEqual(rebeat.changes[1].beats, 2)
        XCTAssertEqual(rebeat.lengthInBeats, 14)
    }

    func testCannotRemoveTheLastChange() {
        let single = ChordProgression(changes: [ChordChange(.gMajor)])
        XCTAssertEqual(single.removingChange(at: 0).changeCount, 1, "never empties the progression")
    }

    func testBeatsClampToAtLeastOne() {
        XCTAssertEqual(ChordChange(.gMajor, beats: 0).beats, 1)
        XCTAssertEqual(pop.settingBeats(at: 0, to: -5).changes[0].beats, 1)
    }

    // MARK: - Roman-numeral badges

    func testPopProgressionReadsAsOneFiveSixFourInGMajor() {
        // The seeded G-major turnaround: G=I, D=V, Em=vi, C=IV.
        XCTAssertEqual(pop.numeral(for: .gMajor), "I")
        XCTAssertEqual(pop.numeral(for: .dMajor), "V")
        XCTAssertEqual(pop.numeral(for: .eMinor), "vi")
        XCTAssertEqual(pop.numeral(for: .cMajor), "IV")
    }

    func testKeyRootInfersFromFirstChordWhenUnset() {
        // No explicit key → infer C major from the first chord (C), so C=I, G=V, Am=vi, F=IV.
        let progression = ChordProgression(changes: [
            ChordChange(.cMajor), ChordChange(.gMajor), ChordChange(.aMinor), ChordChange(.fBarre)
        ])
        XCTAssertEqual(progression.resolvedKeyRoot, 0)
        XCTAssertEqual(progression.numeral(for: .cMajor), "I")
        XCTAssertEqual(progression.numeral(for: .gMajor), "V")
        XCTAssertEqual(progression.numeral(for: .aMinor), "vi")
        XCTAssertEqual(progression.numeral(for: .fBarre), "IV")
    }

    func testMinorKeyNumerals() {
        // A natural-minor key: Am=i, Dm=iv, Em=v, C=III.
        let progression = ChordProgression(changes: [ChordChange(.aMinor)],
                                           keyRoot: 9, keyIsMinor: true)
        XCTAssertEqual(progression.numeral(for: .aMinor), "i")
        XCTAssertEqual(progression.numeral(for: .dMinor), "iv")
        XCTAssertEqual(progression.numeral(for: .eMinor), "v")
        XCTAssertEqual(progression.numeral(for: .cMajor), "III")
    }

    // MARK: - Codable round-trip + back-compat

    func testProgressionRoundTripsThroughCodable() throws {
        let data = try JSONEncoder().encode(pop)
        let decoded = try JSONDecoder().decode(ChordProgression.self, from: data)
        XCTAssertEqual(decoded, pop)
    }

    func testDecodesAPreKeyBlobWithoutFailing() throws {
        // A payload written before the key fields existed (only version + changes) must still decode,
        // defaulting to inferred key / major rather than dropping the whole progression.
        let json = """
        {"version":1,"changes":[{"voicing":{"name":"G","frets":[3,0,0,0,2,3]},"beats":4}]}
        """
        let decoded = try JSONDecoder().decode(ChordProgression.self, from: Data(json.utf8))
        XCTAssertNil(decoded.keyRoot, "absent keyRoot decodes as inferred (nil)")
        XCTAssertFalse(decoded.keyIsMinor, "absent keyIsMinor defaults to major")
        XCTAssertEqual(decoded.changeCount, 1)
        XCTAssertEqual(decoded.numeral(for: .gMajor), "I", "infers G major from the only chord")
    }
}
