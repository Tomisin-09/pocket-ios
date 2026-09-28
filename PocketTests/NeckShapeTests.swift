import XCTest
@testable import Pocket

/// Chords on the neck (ADR 0227 D4): what a placed shape reads as, and the one-note-per-string tap rule.
final class NeckShapeTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi   // [64, 59, 55, 50, 45, 40]

    private func shape(_ frets: [Int: Int]) -> [FrettedNote] {
        frets.keys.sorted().map { FrettedNote(string: $0, fret: frets[$0] ?? 0) }
    }

    private func read(_ frets: [Int: Int]) -> ShapeReading? {
        NeckShape.read(shape(frets), openMidi: guitar)
    }

    // MARK: - Reading a shape

    func testAnOpenChordReadsByTheNamer() throws {
        let openAm = try XCTUnwrap(read([0: 0, 1: 1, 2: 2, 3: 2, 4: 0]))
        XCTAssertEqual(openAm.name(spelling: .sharps), "Am")
        XCTAssertEqual(openAm.word, "Chord")
        XCTAssertEqual(openAm.chord, EarReading(root: 9, kind: .chord(suffix: "m")))
    }

    func testAnInversionReadsAsASlashName() throws {
        let triad = try XCTUnwrap(read([4: 3, 3: 2, 2: 2]))   // C on the A string, under E and A
        XCTAssertEqual(triad.name(spelling: .sharps), "Am/C")
        XCTAssertEqual(triad.word, "Triad")
    }

    func testRootAndFifthIsAPowerChordButUpsideDownIsAFourth() throws {
        let power = try XCTUnwrap(read([5: 0, 4: 2]))   // E and the B above it
        XCTAssertEqual(power.name(spelling: .sharps), "E5")
        XCTAssertEqual(power.word, "Power chord")
        let fourth = try XCTUnwrap(read([4: 2, 3: 2]))   // B under E
        XCTAssertEqual(fourth.name(spelling: .sharps), "a 4th", "not A5/E, nor E5/B")
        XCTAssertNil(fourth.chord)
        XCTAssertEqual(fourth.shortName(spelling: .sharps), "4th")
    }

    func testAnyOtherDoubleStopIsNamedByItsInterval() throws {
        XCTAssertEqual(try XCTUnwrap(read([2: 5, 1: 5])).name(spelling: .sharps), "a major 3rd")   // C, E
        XCTAssertEqual(try XCTUnwrap(read([3: 7, 0: 5])).name(spelling: .sharps), "an octave")   // A, A
        XCTAssertEqual(try XCTUnwrap(read([3: 7, 0: 5])).shortName(spelling: .sharps), "8ve")
        XCTAssertEqual(NeckShape.intervalName(15), "a minor 3rd", "a 10th reduces to its 3rd")
        XCTAssertEqual(NeckShape.intervalName(0), "a unison")
        XCTAssertEqual(NeckShape.intervalChip(10), "min 7th", "not m7, which By ear reads as a chord")
    }

    func testAShapeThatSpellsNoChordSaysSo() throws {
        let cluster = try XCTUnwrap(read([4: 3, 3: 0, 2: 0]))   // C, D, G: a chord after all
        XCTAssertEqual(cluster.name(spelling: .sharps), "Csus2")
        let clash = try XCTUnwrap(read([4: 3, 3: 11, 2: 7]))   // C, C♯, D
        XCTAssertEqual(clash.name(spelling: .sharps), "no common chord name")
        XCTAssertEqual(clash.shortName(spelling: .sharps), "C·C♯·D")
    }

    func testOneNoteIsNotAShape() {
        XCTAssertNil(read([2: 5]))
        XCTAssertNil(NeckShape.read([FrettedNote(string: 7, fret: 1), FrettedNote(string: 0, fret: 1)],
                                    openMidi: guitar), "a note off the strings reads as nothing")
    }

    // MARK: - A shape as an answer

    func testAShapeAnswersWithTheChordItSpells() {
        let label = PieceLabel.fretted(shape([4: 3, 3: 2, 2: 2]), into: nil)
        XCTAssertEqual(label.name(openMidi: guitar, spelling: .sharps), "Am/C")
        XCTAssertEqual(label.pitchClass(openMidi: guitar), 9, "its root")
        XCTAssertEqual(label.earReading(openMidi: guitar), EarReading(root: 9, kind: .chord(suffix: "m")))
        let fourth = PieceLabel.fretted(shape([4: 2, 3: 2]), into: nil)
        XCTAssertEqual(fourth.name(openMidi: guitar, spelling: .sharps), "4th")
        XCTAssertNil(fourth.earReading(openMidi: guitar), "an interval is nothing By ear can name")
    }

    func testByEarKeepsAShapeWhenPickedAsWhatItReads() {
        let label = PieceLabel.fretted(shape([4: 3, 3: 2, 2: 2]), into: nil)
        XCTAssertEqual(EarPick.name(9, as: .chord(suffix: "m"), over: label, openMidi: guitar),
                       .save(label, advance: true))
        XCTAssertEqual(EarPick.name(0, as: .chord(suffix: ""), over: label, openMidi: guitar),
                       .askToReplace(.chord(root: 0, suffix: "")))
    }

    // MARK: - Tapping the neck

    func testWithChordsOffATapReplacesTheNoteAndKeepsItsMarks() {
        let bent = PieceLabel.fretted([FrettedNote(string: 2, fret: 7, bend: 2, vibrato: true)], into: .legato)
        let outcome = NeckPlacement.tap(string: 1, fret: 8, on: bent, ringed: 2, chords: false)
        let moved = FrettedNote(string: 1, fret: 8, bend: 2, vibrato: true)
        XCTAssertEqual(outcome.label, .fretted([moved], into: .legato))
        XCTAssertEqual(NeckPlacement.tap(string: 2, fret: 7, on: bent, ringed: 2, chords: false).label, bent,
                       "tapping the placed note does nothing")
        XCTAssertEqual(NeckPlacement.tap(string: 0, fret: 3, on: .pitchClass(2), ringed: nil, chords: true).label,
                       .fretted(string: 0, fret: 3), "a name by ear gives way to a note")
    }

    func testWithChordsOnItsOneNotePerString() {
        let start = PieceLabel.fretted(string: 1, fret: 5)
        let added = NeckPlacement.tap(string: 0, fret: 5, on: start, ringed: 1, chords: true)
        XCTAssertEqual(added.label.frettedNotes.map(\.string), [1, 0], "an empty string adds a note")
        XCTAssertEqual(added.ringed, 0)
        let moved = NeckPlacement.tap(string: 1, fret: 7, on: added.label, ringed: 0, chords: true)
        XCTAssertEqual(moved.label.frettedNotes.first { $0.string == 1 }?.fret, 7, "a string with a note moves it")
        XCTAssertEqual(moved.label.frettedNotes.count, 2)
    }

    func testTappingANoteRingsItThenTakesItOut() {
        let pair = PieceLabel.fretted([FrettedNote(string: 1, fret: 5), FrettedNote(string: 0, fret: 5)], into: nil)
        let ring = NeckPlacement.tap(string: 1, fret: 5, on: pair, ringed: 0, chords: true)
        XCTAssertEqual(ring.label, pair, "the first tap only rings it")
        XCTAssertEqual(ring.ringed, 1)
        let out = NeckPlacement.tap(string: 1, fret: 5, on: ring.label, ringed: 1, chords: true)
        XCTAssertEqual(out.label, .fretted(string: 0, fret: 5), "the second takes it out")
        let last = NeckPlacement.tap(string: 0, fret: 5, on: out.label, ringed: 0, chords: true)
        XCTAssertEqual(last.label, out.label, "the last note stays")
    }
}
