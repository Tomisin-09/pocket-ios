import XCTest
@testable import Pocket

/// How many frets a chord diagram draws (1.5, item 2b). Until 1.5 the window was always four, so a bass
/// tenth, which reaches seven, drew only its root. The fix stretches the window to the shape's reach;
/// these pin both halves of that: every bass shape's dots land inside it, and no guitar diagram moves.
final class ChordDiagramWindowTests: XCTestCase {

    /// Whether every fretted note of `voicing` falls inside the window the diagram draws: the same
    /// test `ChordDiagramView.dots` applies before it draws a dot.
    private func everyDotIsDrawn(_ voicing: ChordVoicing) -> Bool {
        let base = voicing.displayBaseFret
        let window = voicing.displayFretWindow()
        return voicing.frets.compactMap { $0 }.filter { $0 > 0 }
            .allSatisfy { $0 >= base && $0 < base + window }
    }

    /// The case the backlog logged: C on the low E at fret 8 puts its E at fret 14.
    func testABassTenthDrawsItsTenth() throws {
        let cTenth = try XCTUnwrap(BassChordShape.majorTenth.voicing(rootString: 3, rootFret: 8))
        XCTAssertEqual(cTenth.frets, [nil, 14, nil, 8])
        XCTAssertEqual(cTenth.displayBaseFret, 8)
        XCTAssertEqual(cTenth.displayFretWindow(), 7)
        XCTAssertTrue(everyDotIsDrawn(cTenth))
    }

    /// Every bass shape, at every root on every string, draws every note it plays. That includes the
    /// shell *root · ♭7 · 10*, whose tenth sits six frets up the D string just as the dyad's does.
    func testEveryBassVoicingDrawsEveryNote() {
        var checked = 0
        for shape in BassChordShape.all {
            for voicing in shape.voicings() {
                checked += 1
                XCTAssertTrue(everyDotIsDrawn(voicing),
                              "\(voicing.name) \(voicing.frets) loses a dot in its window")
            }
        }
        XCTAssertGreaterThan(checked, 100, "the sweep has to have swept something")
    }

    /// No guitar diagram changes: every shape the app offers still spans four frets or fewer, so each
    /// keeps the four-fret window it always had. The library's open shapes, and every movable grip and
    /// triad slid to all twelve roots.
    func testEveryGuitarDiagramKeepsItsFourFrets() {
        let grips = ChordGrip.curated + ChordGrip.triads
        let slid = grips.flatMap { grip in (0..<12).map { grip.voicing(rootPitchClass: $0) } }
        let all = ChordVoicing.library + slid
        XCTAssertGreaterThan(all.count, 100, "the sweep has to have swept something")
        for voicing in all {
            XCTAssertEqual(voicing.frets.count, ChordVoicing.stringCount)
            XCTAssertEqual(voicing.displayFretWindow(), 4,
                           "\(voicing.name) \(voicing.frets) would stretch the guitar box")
        }
    }

    /// A shape that reaches further than any the app offers (a custom chord can) stops at the cap
    /// rather than squeezing the neck into a chip. An open-position shape keeps its nut window.
    func testTheWindowIsCappedAndNeverShrinks() {
        let wide = ChordVoicing("wide", frets: [nil, 15, nil, 3])
        XCTAssertEqual(wide.displayFretWindow(), ChordVoicing.maxDisplayFretWindow)
        XCTAssertEqual(ChordVoicing.cMajor.displayFretWindow(), 4)
        XCTAssertEqual(ChordVoicing("open", frets: [0, 0, 0, 0, 0, 0]).displayFretWindow(), 4)
        XCTAssertEqual(ChordVoicing.cMajor.displayFretWindow(minimum: 5), 5)
    }
}
