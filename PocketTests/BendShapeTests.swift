import XCTest
@testable import Pocket

/// **Bend releases and pre-bends** (ADR 0288): where each shape is named, the tab it writes, the glow and the
/// words, and a stored note that an older build still names by the fret it lands on.
final class BendShapeTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi   // [64, 59, 55, 50, 45, 40]

    /// G string, fret 7, bent a whole step to fret 9's pitch: D bent up to E.
    private func bent(releases: Bool = false, preBent: Bool = false, vibrato: Bool = false) -> FrettedNote {
        FrettedNote(string: 2, fret: 7, bend: 2, releases: releases, preBent: preBent, vibrato: vibrato)
    }

    private var allFour: [FrettedNote] {
        [bent(), bent(releases: true), bent(preBent: true), bent(releases: true, preBent: true)]
    }

    private func spot(_ string: Int, _ fret: Int) -> NeckSpot { NeckSpot(string: string, fret: fret) }

    // MARK: - Named where it lands

    func testEachShapeIsNamedByThePitchItLandsOn() {
        let names = allFour.map { PieceLabel.fretted([$0], into: nil).name(openMidi: guitar, spelling: .sharps) }
        XCTAssertEqual(names, ["E", "D", "E", "D"], "a release lands back on the fret; a pre-bend stays bent")
        XCTAssertEqual(PieceLabel.fretted([bent(releases: true)], into: nil).midiNote(openMidi: guitar), 62)
    }

    func testEachShapeHasItsOwnName() {
        XCTAssertEqual(allFour.map(\.bendShape), [.bend, .bendAndRelease, .preBend, .preBendAndRelease])
        XCTAssertNil(FrettedNote(string: 2, fret: 7, releases: true, preBent: true).bendShape,
                     "no bend, no shape, whatever the flags say")
    }

    // MARK: - Tab

    func testTheTabWritesEachShape() {
        XCTAssertEqual(allFour.map(TabLine.cell), ["7b9", "7b9r7", "7pb9", "7pb9r7"])
        XCTAssertEqual(TabLine.cell(bent(releases: true, vibrato: true)), "7b9r7~")
    }

    // MARK: - Stored

    func testEachShapeComesBackAsItWasSaved() throws {
        for note in allFour + [bent(releases: true, preBent: true, vibrato: true)] {
            let data = try JSONEncoder().encode(note)
            XCTAssertEqual(try JSONDecoder().decode(FrettedNote.self, from: data), note)
        }
    }

    func testAReleaseIsStoredWhereAnOlderBuildWontReadItAsABend() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let release = try XCTUnwrap(String(bytes: try encoder.encode(bent(releases: true)), encoding: .utf8))
        XCTAssertEqual(release, #"{"fret":7,"release":2,"string":2}"#)
        let older = try allFour.map { try JSONDecoder().decode(Note0227.self, from: encoder.encode($0)) }
        XCTAssertEqual(older.map(\.sounding), [64, 62, 64, 62],
                       "an older build names every shape by the note it lands on")
    }

    func testAPreBendWithNoBendReadsAsAPlainNote() throws {
        let json = #"{"string":2,"fret":7,"preBend":true}"#
        XCTAssertEqual(try JSONDecoder().decode(FrettedNote.self, from: Data(json.utf8)),
                       FrettedNote(string: 2, fret: 7))
    }

    func testNoneTakesTheShapeWithIt() {
        var note = bent(releases: true, preBent: true)
        note.changeBend(to: 1)
        XCTAssertEqual(note.bendShape, .preBendAndRelease, "a new size keeps the shape")
        note.changeBend(to: 0)
        XCTAssertEqual(note, FrettedNote(string: 2, fret: 7), "an unbent note carries no shape")
    }

    // MARK: - On the neck

    func testTheGlowMovesTheWayThePitchIsHeard() {
        let motions = allFour.map { HaloMotion.motions(into: 0, of: [.fretted([$0], into: nil)]) }
        XCTAssertEqual(motions, [[.bend(from: spot(2, 7), to: spot(2, 9))],
                                 [.bendAndRelease(from: spot(2, 7), peak: spot(2, 9))],
                                 [.pop(spot(2, 9))],
                                 [.bend(from: spot(2, 9), to: spot(2, 7))]])
        XCTAssertEqual(HaloMotion.motions(into: 0, of: [.fretted([bent(preBent: true, vibrato: true)], into: nil)]),
                       [.vibrato(spot(2, 9))], "a pre-bend shakes where it's heard")
        XCTAssertEqual(HaloMotion.bendAndRelease(from: spot(2, 7), peak: spot(2, 9)).end, spot(2, 7))
    }

    func testTheLineSaysHowItWasBent() {
        let words = allFour.map {
            PieceNeck.words(for: 0, of: [.fretted([$0], into: nil)], openMidi: guitar, spelling: .sharps)
        }
        XCTAssertEqual(words, ["G string, fret 7, bent a whole step",
                               "G string, fret 7, bent a whole step and released",
                               "G string, fret 7, pre-bent a whole step",
                               "G string, fret 7, pre-bent a whole step and released"])
    }

    func testMovingANoteKeepsHowItWasBent() {
        let before = PieceLabel.fretted([bent(releases: true, preBent: true)], into: nil)
        let moved = NeckPlacement.tap(string: 1, fret: 8, on: before, ringed: 2, chords: false)
        XCTAssertEqual(moved.label.frettedNotes.first?.bendShape, .preBendAndRelease)
    }
}

/// A note as a build from before ADR 0288 reads it: `string`, `fret` and `bend`, and nothing it doesn't know.
private struct Note0227: Decodable {
    let string: Int
    let fret: Int
    let bend: Int

    private enum Keys: String, CodingKey { case string, fret, bend }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        string = try container.decode(Int.self, forKey: .string)
        fret = try container.decode(Int.self, forKey: .fret)
        bend = try container.decodeIfPresent(Int.self, forKey: .bend) ?? 0
    }

    /// On the G string of standard tuning, as these tests place it.
    var sounding: Int { 55 + fret + bend }
}
