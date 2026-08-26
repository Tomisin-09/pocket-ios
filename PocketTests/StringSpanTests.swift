import XCTest
@testable import Pocket

/// The picking editor's **string-span strip** (ADR 0184): the pure tap rule behind it, and the string
/// naming the cells and caption read from. UI-free logic that breaks silently otherwise (AGENTS.md) —
/// and the strip's one non-obvious behaviour, since "which end did that move?" cannot be inferred by
/// looking at the control.
final class StringSpanTests: XCTestCase {

    // MARK: - Which end a tap moves

    func testTappingNearerTheStartMovesTheStart() {
        // low E → high e (5 → 0). Fret 3 is nearer the low-E end.
        let span = StringSpanEdit.apply(tapped: 3, from: 5, to: 0)
        XCTAssertEqual(span.from, 3)
        XCTAssertEqual(span.to, 0)
    }

    func testTappingNearerTheFinishMovesTheFinish() {
        let span = StringSpanEdit.apply(tapped: 2, from: 5, to: 0)
        XCTAssertEqual(span.from, 5)
        XCTAssertEqual(span.to, 2)
    }

    func testTappingAnEndCollapsesTheSpanOntoIt() {
        // The only route back to a single-string run — the two menus this replaced could express one.
        let start = StringSpanEdit.apply(tapped: 5, from: 5, to: 0)
        XCTAssertEqual(start.from, 5)
        XCTAssertEqual(start.to, 5)

        let finish = StringSpanEdit.apply(tapped: 0, from: 5, to: 0)
        XCTAssertEqual(finish.from, 0)
        XCTAssertEqual(finish.to, 0)
    }

    func testTappingACollapsedSpanIsANoOp() {
        let span = StringSpanEdit.apply(tapped: 3, from: 3, to: 3)
        XCTAssertEqual(span.from, 3)
        XCTAssertEqual(span.to, 3)
    }

    func testTappingBesideACollapsedSpanOpensItBack() {
        // A one-string run must be escapable, or the collapse above would be a trap.
        let span = StringSpanEdit.apply(tapped: 1, from: 3, to: 3)
        XCTAssertEqual(Set([span.from, span.to]), [1, 3])
    }

    /// The property the strip's whole forgiving feel rests on: an end never jumps past the other one,
    /// so tapping around can widen, narrow or collapse a span but never silently reverse it. Direction
    /// changes only through Reverse.
    func testNoTapEverCrossesTheEndsOver() {
        for from in 0...5 {
            for to in 0...5 {
                for tapped in 0...5 {
                    let span = StringSpanEdit.apply(tapped: tapped, from: from, to: to)
                    guard from != to, span.from != span.to else { continue }
                    XCTAssertEqual(span.from < span.to, from < to,
                                   "tap \(tapped) on \(from)→\(to) flipped direction")
                }
            }
        }
    }

    func testEveryTapLandsOnTheTappedString() {
        // Whichever end moves, the tapped string is always an end of the result — otherwise the tap
        // would appear to do nothing, or something else.
        for from in 0...5 {
            for to in 0...5 {
                for tapped in 0...5 {
                    let span = StringSpanEdit.apply(tapped: tapped, from: from, to: to)
                    XCTAssertTrue(span.from == tapped || span.to == tapped,
                                  "tap \(tapped) on \(from)→\(to) gave \(span.from)→\(span.to)")
                }
            }
        }
    }

    func testATapMidwayBetweenTheEndsResolvesDeterministically() {
        // Equidistant: the rule moves the start, and must keep doing so.
        let span = StringSpanEdit.apply(tapped: 2, from: 4, to: 0)
        XCTAssertEqual(span.from, 2)
        XCTAssertEqual(span.to, 0)
    }

    // MARK: - String naming

    func testHighAndLowEAreSpelledApart() {
        // The one place the short name isn't simply the note letter — six cells share a row, and two
        // of them are an E.
        XCTAssertEqual(NeckStringName.short(0), "e")
        XCTAssertEqual(NeckStringName.short(5), "E")
        XCTAssertEqual(NeckStringName.full(0), "high e")
        XCTAssertEqual(NeckStringName.full(5), "low E")
    }

    func testBassNamesItsFourStringsFromItsOwnIndices() {
        // Engine index 0 = G … 3 = low E on bass (ADR 0116).
        XCTAssertEqual(NeckStringName.short(0, instrument: .bass), "G")
        XCTAssertEqual(NeckStringName.full(3, instrument: .bass), "low E")
    }

    func testAnOutOfRangeIndexDescribesItselfRatherThanMislabelling() {
        // A guitar span decoded onto a bass neck before clamping must not name a string that isn't there.
        XCTAssertEqual(NeckStringName.full(5, instrument: .bass), "String 6")
        XCTAssertEqual(NeckStringName.short(9), "10")
    }
}
