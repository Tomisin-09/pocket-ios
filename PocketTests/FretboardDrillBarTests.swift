import XCTest
@testable import Pocket

/// Multi-bar authoring for the custom fretboard drill (ADR 0107, device feedback 2026-07-23) — the pure
/// `barCount` / `withBarCount` ops and the bar-preserving `resized`, kept separate from the core
/// `FretboardDrillTests` so neither class outgrows the body-length limit.
final class FretboardDrillBarTests: XCTestCase {
    func testBarCountDividesSlotsByMeterTimesSubdivision() {
        // 8 eighth-notes in 4/4 = one bar; 16 = two bars.
        XCTAssertEqual(FretboardDrill.spiderWalk.barCount(beatsPerBar: 4), 1)
        let twoBars = FretboardDrill(notesPerBeat: 2, notes: Array(repeating: nil, count: 16))
        XCTAssertEqual(twoBars.barCount(beatsPerBar: 4), 2)
        XCTAssertEqual(twoBars.barCount(beatsPerBar: 3), 2)   // 16 / (2*3=6) floored = 2, at least 1
        XCTAssertEqual(FretboardDrill(notesPerBeat: 2, notes: [nil, nil]).barCount(beatsPerBar: 4), 1)
    }

    func testWithBarCountGrowsWithRestsAndKeepsPlacedNotes() {
        let oneBar = FretboardDrill(notesPerBeat: 2, notes: [
            FretNote(string: 5, fret: 1), FretNote(string: 5, fret: 2),
            FretNote(string: 5, fret: 3), FretNote(string: 5, fret: 4),
            nil, nil, nil, nil
        ])
        let twoBars = oneBar.withBarCount(2, beatsPerBar: 4)
        XCTAssertEqual(twoBars.notes.count, 16, "two 4/4 bars of eighths = 16 slots")
        XCTAssertEqual(Array(twoBars.notes.prefix(8)), oneBar.notes, "the first bar is preserved by index")
        XCTAssertTrue(twoBars.notes.suffix(8).allSatisfy { $0 == nil }, "the appended bar is rests")
    }

    func testWithBarCountShrinkingDropsTrailingSlots() {
        let twoBars = FretboardDrill(notesPerBeat: 2,
                                     notes: (0..<16).map { FretNote(string: 5, fret: $0 % 5) })
        let oneBar = twoBars.withBarCount(1, beatsPerBar: 4)
        XCTAssertEqual(oneBar.notes.count, 8)
        XCTAssertEqual(oneBar.notes, Array(twoBars.notes.prefix(8)))
    }

    func testWithBarCountClampsToAtLeastOneBar() {
        let drill = FretboardDrill.spiderWalk
        XCTAssertEqual(drill.withBarCount(0, beatsPerBar: 4).barCount(beatsPerBar: 4), 1)
    }

    func testResizedPreservesBarCount() {
        // Two bars of quarters (8 slots) → eighths keeps two bars (16 slots), not one.
        let twoBarsQuarters = FretboardDrill(notesPerBeat: 1,
                                             notes: (0..<8).map { FretNote(string: 5, fret: $0 % 4 + 1) })
        let eighths = twoBarsQuarters.resized(notesPerBeat: 2, beatsPerBar: 4)
        XCTAssertEqual(eighths.barCount(beatsPerBar: 4), 2, "bar count survives a subdivision change")
        XCTAssertEqual(eighths.notes.count, 16)
    }

    func testEmptyBarWithBarsProducesThatManyBarsOfRests() {
        let drill = FretboardDrill.emptyBar(beatsPerBar: 4, notesPerBeat: 2, bars: 3)
        XCTAssertEqual(drill.notes.count, 24)
        XCTAssertTrue(drill.hasNoNotes)
        XCTAssertEqual(drill.barCount(beatsPerBar: 4), 3)
    }
}
