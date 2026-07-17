import XCTest
@testable import Pocket

/// The **saved custom chord** model (ADR 0095): the voicing round-trips through its encoded blob, the
/// name column mirrors the voicing, and the pure dedupe rule holds. Models are constructed **uninserted**
/// and asserted on directly (never `context.insert` in a test host — `docs/swiftdata-gotchas.md`).
final class SavedChordTests: XCTestCase {

    // MARK: - Blob round-trip (the migration-safe persistence, ADR 0095 S1)

    func testVoicingRoundTripsThroughBlob() {
        let original = ChordVoicing("Cadd9", frets: [3, 3, 0, 2, 3, nil])
        let saved = SavedChord(original)
        XCTAssertEqual(saved.voicing, original)
    }

    func testNameColumnMirrorsVoicing() {
        let saved = SavedChord(ChordVoicing("F♯m7", frets: [2, 2, 2, 2, 4, 2]))
        XCTAssertEqual(saved.name, "F♯m7")
        XCTAssertEqual(saved.voicing.name, "F♯m7")
    }

    func testMutedAndOpenStringsSurviveTheRoundTrip() {
        // nil (muted) and 0 (open) must both decode back intact — the frets array's whole vocabulary.
        let original = ChordVoicing("D", frets: [2, 3, 2, 0, nil, nil])
        XCTAssertEqual(SavedChord(original).voicing.frets, [2, 3, 2, 0, nil, nil])
    }

    // MARK: - Dedupe (pure, ADR 0095 S3)

    func testIsAlreadySavedMatchesIdenticalVoicing() {
        let chord = ChordVoicing("Am", frets: [0, 1, 2, 2, 0, nil])
        XCTAssertTrue(SavedChord.isAlreadySaved(chord, among: [chord]))
    }

    func testDifferentGeometryIsNotADuplicate() {
        let saved = ChordVoicing("C", frets: [0, 1, 0, 2, 3, nil])
        let other = ChordVoicing("C", frets: [3, 5, 5, 5, 3, nil])   // same name, different shape
        XCTAssertFalse(SavedChord.isAlreadySaved(other, among: [saved]))
    }

    func testEmptyLibraryHasNoDuplicates() {
        XCTAssertFalse(SavedChord.isAlreadySaved(.cMajor, among: []))
    }

    // MARK: - Rename (My Chords detail, ADR 0096)

    func testRenameUpdatesBothColumnAndVoicing() {
        // Rename must keep the queryable `name` column and the encoded voicing's own name in step, or the
        // list row and the diagram caption would disagree.
        let saved = SavedChord(ChordVoicing("Cadd9", frets: [3, 3, 0, 2, 3, nil]))
        saved.rename(to: "Csus2")
        XCTAssertEqual(saved.name, "Csus2")
        XCTAssertEqual(saved.voicing.name, "Csus2")
        XCTAssertEqual(saved.voicing.frets, [3, 3, 0, 2, 3, nil])   // geometry untouched
    }

    func testRenameTrimsWhitespace() {
        let saved = SavedChord(ChordVoicing("Am", frets: [0, 1, 2, 2, 0, nil]))
        saved.rename(to: "  A minor  ")
        XCTAssertEqual(saved.name, "A minor")
    }

    func testRenameIgnoresBlankName() {
        let saved = SavedChord(ChordVoicing("Am", frets: [0, 1, 2, 2, 0, nil]))
        saved.rename(to: "   ")
        XCTAssertEqual(saved.name, "Am")   // unchanged
    }
}
