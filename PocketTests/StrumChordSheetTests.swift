import XCTest
@testable import Pocket

/// The **strum-chord sheet** wrapper (ADR 0065, strum↔chord composition): pairs an existing,
/// independently-tested `StrumPattern` and `ChordProgression` with no new timing math of its own —
/// each cycles on its own pure `activeSlotIndex`/`activeIndex`, so the tests here cover the wrapper's
/// own shape (construction, equality, Codable round-trip, the seeded default) rather than
/// re-proving cycle math the sibling suites already exercise (T5).
final class StrumChordSheetTests: XCTestCase {

    func testPopGroovePairsTheFolkStrumWithThePopProgression() {
        let sheet = StrumChordSheet.popGroove
        XCTAssertEqual(sheet.strumPattern, .folk)
        XCTAssertEqual(sheet.chordProgression, .gMajorPop)
    }

    func testTheGrooveCompletesExactlyOncePerChordByConstruction() {
        // Not a coupling — the two lengths just happen to divide evenly in the shipped seed.
        let sheet = StrumChordSheet.popGroove
        XCTAssertEqual(sheet.strumPattern.lengthInBeats, 4)
        XCTAssertEqual(sheet.chordProgression.changes.first?.beats, 4)
    }

    func testInitDefaultsToCurrentVersion() {
        let sheet = StrumChordSheet(strumPattern: .downstrokes(), chordProgression: .gMajorPop)
        XCTAssertEqual(sheet.version, StrumChordSheet.currentVersion)
    }

    func testEqualityComparesBothHalves() {
        let base = StrumChordSheet.popGroove
        var differentStrum = base
        differentStrum.strumPattern = .downstrokes()
        XCTAssertNotEqual(base, differentStrum)

        var differentChords = base
        differentChords.chordProgression = differentChords.chordProgression.appending(.aMinor)
        XCTAssertNotEqual(base, differentChords)
    }

    func testSheetRoundTripsThroughCodable() throws {
        let data = try JSONEncoder().encode(StrumChordSheet.popGroove)
        let decoded = try JSONDecoder().decode(StrumChordSheet.self, from: data)
        XCTAssertEqual(decoded, .popGroove)
    }
}
