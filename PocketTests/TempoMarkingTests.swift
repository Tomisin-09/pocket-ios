import XCTest
@testable import Pocket

/// Pure BPM→Italian-tempo-marking lookup (ADR 0043, slice 1). A contiguous, gap-free
/// band table rots silently if a boundary is fenced wrong, so the edges are pinned
/// (AGENTS.md).
final class TempoMarkingTests: XCTestCase {

    // MARK: representative tempos

    func testCommonTemposNameTheExpectedMarking() {
        XCTAssertEqual(TempoMarking.marking(forBPM: 50), .largo)
        XCTAssertEqual(TempoMarking.marking(forBPM: 72), .adagio)
        XCTAssertEqual(TempoMarking.marking(forBPM: 90), .andante)
        XCTAssertEqual(TempoMarking.marking(forBPM: 112), .moderato)
        XCTAssertEqual(TempoMarking.marking(forBPM: 140), .allegro)
        XCTAssertEqual(TempoMarking.marking(forBPM: 190), .presto)
    }

    // MARK: band boundaries are half-open [lower, upper)

    func testBoundaryBelongsToTheFasterBand() {
        // 120 is the allegro floor (moderato runs up to but not including 120).
        XCTAssertEqual(TempoMarking.marking(forBPM: 119.9), .moderato)
        XCTAssertEqual(TempoMarking.marking(forBPM: 120), .allegro)
        // 168 is the vivace floor.
        XCTAssertEqual(TempoMarking.marking(forBPM: 167.9), .allegro)
        XCTAssertEqual(TempoMarking.marking(forBPM: 168), .vivace)
    }

    // MARK: open ends

    func testVerySlowClampsToSlowestBand() {
        XCTAssertEqual(TempoMarking.marking(forBPM: 10), .larghissimo)
        // Non-positive BPM still names a tempo (slowest) rather than crashing/returning nil.
        XCTAssertEqual(TempoMarking.marking(forBPM: 0), .larghissimo)
        XCTAssertEqual(TempoMarking.marking(forBPM: -30), .larghissimo)
    }

    func testVeryFastIsPrestissimo() {
        XCTAssertEqual(TempoMarking.marking(forBPM: 200), .prestissimo)
        XCTAssertEqual(TempoMarking.marking(forBPM: 300), .prestissimo)
    }

    // MARK: table integrity

    func testEveryPositiveBPMNamesExactlyOneMarking() {
        // Sweep the usable range; the lookup must never trap or skip a band.
        for bpm in stride(from: 1.0, through: 320.0, by: 0.5) {
            _ = TempoMarking.marking(forBPM: bpm)
        }
    }

    func testDisplayNameIsCapitalised() {
        XCTAssertEqual(TempoMarking.allegro.name, "Allegro")
        XCTAssertEqual(TempoMarking.prestissimo.name, "Prestissimo")
    }
}
