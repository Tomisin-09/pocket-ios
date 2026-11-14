import XCTest
@testable import Pocket

/// **A bend released on a tap of its own** (ADR 0296): a bend held on one tap and let down on the next, as
/// a join. When it fits, what choosing *Release* does, the tab, the glow, the tidy step, and what's stored,
/// including what a build that doesn't know the join reads.
final class BendReleaseJoinTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi   // [64, 59, 55, 50, 45, 40]

    /// The solo's bend: B string, fret 10, bent a half step to fret 11's pitch.
    private func bent(_ bend: Int = 1, releases: Bool = false, preBent: Bool = false) -> PieceLabel {
        .fretted([FrettedNote(string: 1, fret: 10, bend: bend, releases: releases, preBent: preBent)], into: nil)
    }

    private func plain(_ fret: Int = 10, string: Int = 1, vibrato: Bool = false, into: Join? = nil) -> PieceLabel {
        .fretted([FrettedNote(string: string, fret: fret, vibrato: vibrato)], into: into)
    }

    private func spot(_ string: Int, _ fret: Int) -> NeckSpot { NeckSpot(string: string, fret: fret) }

    // MARK: - When it fits (D4)

    func testAReleaseFitsAfterABendHeldOnTheSameFret() {
        let labels: [PieceLabel?] = [bent(), plain(into: .release)]
        XCTAssertTrue(NeckJoin.releases(into: 1, of: labels))
        XCTAssertTrue(NeckJoin.fits(.release, into: 1, of: labels))
        XCTAssertEqual(NeckJoin.symbol(into: 1, of: labels), "r")
        XCTAssertTrue(NeckJoin.releases(into: 1, of: [bent(preBent: true), plain(into: .release)]),
                      "a pre-bend held comes down the same way")
    }

    func testAReleaseDoesNotFitWithoutABendHeldWhereItLands() {
        let cases: [(String, [PieceLabel?])] = [
            ("the tap before isn't bent", [plain(), plain(into: .release)]),
            ("the bend before already came down", [bent(releases: true), plain(into: .release)]),
            ("it's on another fret", [bent(), plain(8, into: .release)]),
            ("it's on another string", [bent(), plain(10, string: 2, into: .release)]),
            ("it's bent itself", [bent(), .fretted([FrettedNote(string: 1, fret: 10, bend: 1)], into: .release)]),
            ("the tap before is unnamed", [nil, plain(into: .release)])
        ]
        for (why, labels) in cases {
            XCTAssertFalse(NeckJoin.releases(into: 1, of: labels), why)
            XCTAssertNil(NeckJoin.symbol(into: 1, of: labels), why)
        }
        XCTAssertFalse(NeckJoin.releases(into: 0, of: [plain(into: .release)]), "the first note")
    }

    func testInAShapeTheBentNoteComesDownAndTheOtherIsHeld() {
        let before: PieceLabel = .fretted([FrettedNote(string: 1, fret: 10, bend: 1), FrettedNote(string: 2, fret: 9)],
                                          into: nil)
        let after: PieceLabel = .fretted([FrettedNote(string: 1, fret: 10), FrettedNote(string: 2, fret: 9)],
                                         into: .release)
        XCTAssertTrue(NeckJoin.releases(into: 1, of: [before, after]))
        XCTAssertEqual(HaloMotion.motions(into: 1, of: [before, after]),
                       [.bend(from: spot(1, 11), to: spot(1, 10)), .pop(spot(2, 9))])
    }

    // MARK: - Offered after a bend (D2)

    func testReleaseIsOfferedOnlyAfterABentNote() {
        let four: [IntoChoice] = [.picked, .hammerOn, .pullOff, .slide]
        XCTAssertEqual(IntoChoice.offered(into: 1, of: [bent(), nil]), four + [.release])
        XCTAssertEqual(IntoChoice.offered(into: 1, of: [bent(releases: true), plain()]), four + [.release],
                       "a bend already released can still move its release to this tap")
        XCTAssertEqual(IntoChoice.offered(into: 1, of: [plain(), plain()]), four)
        XCTAssertEqual(IntoChoice.offered(into: 0, of: [bent(), plain()]), four, "the first note")
        XCTAssertEqual(NeckJoin.route(.release, into: 1, of: [plain(), plain()]), .unavailable)
    }

    // MARK: - Choosing it places the note (D3)

    func testChoosingReleasePutsTheNoteWhereTheBendWasAndTakesTheBendsOwnReleaseOff() {
        for current in [nil, plain(8), plain(10, string: 2), PieceLabel.muted] as [PieceLabel?] {
            let edit = NeckEditing.choose(.release, labels: [bent(releases: true), current],
                                          cursor: NeckCursor(active: 1))
            XCTAssertEqual(edit.labels, [bent(), plain(into: .release)], "from \(String(describing: current))")
            XCTAssertEqual(edit.cursor, NeckCursor(active: 1), "the cursor stays, as for any choice")
        }
    }

    func testChoosingReleaseKeepsVibratoAlreadyOnTheNote() {
        let edit = NeckEditing.choose(.release, labels: [bent(), plain(vibrato: true)], cursor: NeckCursor(active: 1))
        XCTAssertEqual(edit.labels[1], plain(vibrato: true, into: .release))
        XCTAssertTrue(NeckJoin.holds(.release, into: 1, of: edit.labels))
        XCTAssertFalse(NeckJoin.holds(.picked, into: 1, of: edit.labels))
    }

    func testReleaseDoesNothingWithoutABendBefore() {
        let labels: [PieceLabel?] = [plain(), plain(8)]
        XCTAssertEqual(NeckEditing.choose(.release, labels: labels, cursor: NeckCursor(active: 1)).labels, labels)
    }

    func testPickedTakesTheReleaseOff() {
        let edit = NeckEditing.choose(.picked, labels: [bent(), plain(into: .release)], cursor: NeckCursor(active: 1))
        XCTAssertEqual(edit.labels, [bent(), plain()])
    }

    // MARK: - Tidied as any join is

    func testTheTidyStepKeepsAReleaseThatFitsAndDropsOneThatDoesnt() {
        XCTAssertEqual(NeckJoin.tidied([bent(), plain(into: .release)]), [bent(), plain(into: .release)])
        XCTAssertEqual(NeckJoin.tidied([bent(releases: true), plain(into: .release)]),
                       [bent(releases: true), plain()], "the bend let down on its own tap leaves nothing to release")
        XCTAssertEqual(NeckJoin.tidied([plain(), plain(into: .release)]), [plain(), plain()])
    }

    // MARK: - Named, written and drawn (D5–D7)

    func testTheReleaseTapIsNamedByItsFret() {
        XCTAssertEqual(plain(into: .release).name(openMidi: guitar, spelling: .sharps), "A")
        XCTAssertEqual(bent().name(openMidi: guitar, spelling: .sharps), "A♯")
    }

    func testTheTabReadsTheSameAsAReleaseInsideOneTap() {
        let twoTaps = TabLine.render([bent(), plain(into: .release)], openMidi: guitar)
        XCTAssertEqual(twoTaps, TabLine.render([bent(releases: true)], openMidi: guitar))
        XCTAssertTrue(twoTaps?.contains("B|-10b11r10--|") == true, twoTaps ?? "no tab")
        let unfit = TabLine.render([bent(releases: true), plain(into: .release)], openMidi: guitar)
        XCTAssertTrue(unfit?.contains("B|-10b11r10--10--|") == true, "a release that doesn't fit is picked")
    }

    func testTheGlowHoldsTheBendThenComesDownOnTheReleaseTap() {
        let labels: [PieceLabel?] = [bent(), plain(into: .release)]
        XCTAssertEqual(HaloMotion.motions(into: 0, of: labels), [.bend(from: spot(1, 10), to: spot(1, 11))])
        XCTAssertEqual(HaloMotion.motions(into: 1, of: labels), [.bend(from: spot(1, 11), to: spot(1, 10))])
        XCTAssertEqual(HaloMotion.motions(into: 1, of: [plain(), plain(into: .release)]), [.pop(spot(1, 10))],
                       "with nothing bent before it, it's picked")
    }

    // MARK: - Stored as a join (D8)

    func testItIsStoredAsAJoinBesideAPlainFret() throws {
        let labels: [PieceLabel?] = [bent(), plain(into: .release)]
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(labels)
        XCTAssertEqual(String(data: data, encoding: .utf8),
                       #"[{"bend":1,"fret":10,"kind":"fret","string":1},"#
                       + #"{"fret":10,"into":"release","kind":"fret","string":1}]"#,
                       "the release tap is its plain fret and the join, with no bend of its own")
        XCTAssertEqual(try JSONDecoder().decode([PieceLabel?].self, from: data), labels)
    }

    func testABuildThatDoesntKnowTheJoinReadsTheFretPickedAgain() throws {
        // What 1.4 does with `"into": "release"` is what this build does with any value it doesn't know.
        let json = #"[{"kind":"fret","string":1,"fret":10,"bend":1},"#
            + #"{"kind":"fret","string":1,"fret":10,"into":"letdown"}]"#
        let read = try JSONDecoder().decode([PieceLabel?].self, from: Data(json.utf8))
        XCTAssertEqual(read, [bent(), plain()], "the right pitch, picked: the tap is kept")
    }

    func testALeadInIsNeverARelease() throws {
        XCTAssertNil(LeadIn(from: .fret(11), join: .release).direction(into: 10))
        let json = #"[{"kind":"fret","string":1,"fret":10,"leadIn":{"from":11,"join":"release"}}]"#
        let read = try JSONDecoder().decode([PieceLabel?].self, from: Data(json.utf8))
        XCTAssertEqual(read, [plain()], "a bend let down inside one tap is the note's own Release")
    }
}
