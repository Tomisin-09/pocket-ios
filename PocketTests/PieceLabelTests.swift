import XCTest
@testable import Pocket

/// What a tap was (ADR 0225): the pitch arithmetic behind names, frets and chords, the tab drawn from
/// frets, and a piece that survives being written by a newer build.
final class PieceLabelTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi   // [64, 59, 55, 50, 45, 40]
    private let bass = Instrument.bass.standardTuning.engineOpenMidi       // [43, 38, 33, 28]

    // MARK: - Frets

    func testAFretSoundsItsStringPlusTheFret() {
        XCTAssertEqual(PieceLabel.fretted(string: 1, fret: 3).midiNote(openMidi: guitar), 62)   // D on B
        XCTAssertEqual(PieceLabel.fretted(string: 5, fret: 0).midiNote(openMidi: guitar), 40)   // low E
        XCTAssertEqual(PieceLabel.fretted(string: 0, fret: PieceLabel.maxFret).midiNote(openMidi: guitar), 86)
    }

    func testTheSameFretReadsAgainstBass() {
        XCTAssertEqual(PieceLabel.fretted(string: 3, fret: 5).midiNote(openMidi: bass), 33)   // A on the E
        XCTAssertEqual(PieceLabel.fretted(string: 3, fret: 5).pitchClass(openMidi: bass), 9)
    }

    func testAFretPastTheStringsHasNoPitch() {
        // A six-string fret read against a four-string tuning must not land on some other string.
        XCTAssertNil(PieceLabel.fretted(string: 5, fret: 2).midiNote(openMidi: bass))
        XCTAssertNil(PieceLabel.fretted(string: 5, fret: 2).name(openMidi: bass, spelling: .sharps))
    }

    // MARK: - Names

    func testANameSpellsByTheKey() {
        XCTAssertEqual(PieceLabel.pitchClass(3).name(openMidi: [], spelling: .sharps), "D♯")
        XCTAssertEqual(PieceLabel.pitchClass(3).name(openMidi: [], spelling: .flats), "E♭")
        XCTAssertEqual(PieceLabel.fretted(string: 2, fret: 3).name(openMidi: guitar, spelling: .flats), "B♭")
    }

    func testAChordNamesByRootAndQuality() {
        XCTAssertEqual(PieceLabel.chord(root: 9, suffix: "m7").name(openMidi: [], spelling: .sharps), "Am7")
        XCTAssertEqual(PieceLabel.chord(root: 10, suffix: "").name(openMidi: [], spelling: .flats), "B♭")
        XCTAssertEqual(PieceLabel.chord(root: 9, suffix: "m").pitchClass(openMidi: []), 9)
    }

    func testThePickerOffersEachQualityOnce() {
        let suffixes = PieceLabel.chordQualities.map(\.suffix)
        XCTAssertEqual(suffixes.count, Set(suffixes).count)
        XCTAssertEqual(suffixes.first, "", "major first, the commonest")
    }

    // MARK: - Coding

    func testEveryKindRoundTrips() throws {
        let labels: [PieceLabel] = [.pitchClass(3), .fretted(string: 2, fret: 12), .chord(root: 9, suffix: "m7♭5")]
        let data = try JSONEncoder().encode(labels)
        XCTAssertEqual(try JSONDecoder().decode([PieceLabel].self, from: data), labels)
    }

    func testTheWireFormatIsTagged() throws {
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(PieceLabel.pitchClass(3)), encoding: .utf8))
        XCTAssertTrue(json.contains("\"kind\":\"note\""), json)
    }
}

final class TabLineTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi

    func testATwoDigitFretWidensOnlyItsColumn() {
        let tab = TabLine.render([.fretted(string: 1, fret: 5), .fretted(string: 1, fret: 10)], openMidi: guitar)
        XCTAssertEqual(tab, """
        e|--------|
        B|-5--10--|
        G|--------|
        D|--------|
        A|--------|
        E|--------|
        """)
    }

    func testEveryLineIsTheSameWidth() throws {
        let tab = try XCTUnwrap(TabLine.render([.fretted(string: 1, fret: 5), .fretted(string: 3, fret: 12),
                                                .fretted(string: 0, fret: 0)], openMidi: guitar))
        let widths = Set(tab.split(separator: "\n").map(\.count))
        XCTAssertEqual(widths.count, 1, tab)
    }

    func testTheTopEIsLowerCased() {
        XCTAssertEqual(TabLine.stringNames(openMidi: guitar), ["e", "B", "G", "D", "A", "E"])
    }

    func testBassHasFourLines() throws {
        let tab = try XCTUnwrap(TabLine.render([.fretted(string: 3, fret: 5)],
                                               openMidi: Instrument.bass.standardTuning.engineOpenMidi))
        XCTAssertEqual(tab.split(separator: "\n").map { String($0.prefix(2)) }, ["G|", "D|", "A|", "E|"])
        XCTAssertTrue(tab.hasSuffix("E|-5--|"), tab)
    }

    func testNamesPadSoTheBarsLineUp() {
        // Open D has an F♯: every name pads to two characters.
        let openD = Instrument.guitar.tuning(named: "Open D").engineOpenMidi
        XCTAssertEqual(Set(TabLine.stringNames(openMidi: openD).map(\.count)), [2])
    }

    func testNothingPlacedNoTab() {
        XCTAssertNil(TabLine.render([], openMidi: guitar))
        XCTAssertNil(TabLine.render([.fretted(string: 9, fret: 2)], openMidi: guitar))
    }
}

final class PieceTranscriptionTests: XCTestCase {

    func testAPieceRoundTripsThroughItsStorage() throws {
        let piece = PieceTranscription(taps: [.init(seconds: 31.2, label: .fretted(string: 1, fret: 5)),
                                              .init(seconds: 30.4, label: nil)],
                                       openMidi: [64, 59, 55, 50, 45, 40], tuningLabel: "Guitar · Standard")
        XCTAssertEqual(piece.taps.map(\.seconds), [30.4, 31.2], "stored in song order")
        XCTAssertEqual(PieceTranscription.decoded(from: piece.encoded()), piece)
    }

    func testALabelFromANewerBuildReadsAsUnnamed() throws {
        let json = """
        {"version": 2, "taps": [{"seconds": 30.5, "label": {"kind": "bend", "from": 7}},
                                {"seconds": 31, "label": {"kind": "note", "pitchClass": 2}}]}
        """
        let piece = try XCTUnwrap(PieceTranscription.decoded(from: Data(json.utf8)))
        XCTAssertEqual(piece.labels, [nil, .pitchClass(2)], "one unknown label, not a lost piece")
        XCTAssertNil(piece.openMidi)
    }

    func testNoDataNoPiece() {
        XCTAssertNil(PieceTranscription.decoded(from: nil))
        XCTAssertNil(PieceTranscription.decoded(from: Data("not json".utf8)))
    }

    func testNamesUseTheStoredStrings() {
        let piece = PieceTranscription(taps: [.init(seconds: 1, label: .fretted(string: 3, fret: 5))],
                                       openMidi: Instrument.bass.standardTuning.engineOpenMidi)
        XCTAssertEqual(piece.names(spelling: .sharps), ["A"])
    }

    @MainActor
    func testTheLoopStoresNothingForAnEmptyPiece() {
        let loop = Loop(name: "Lick", start: 0.2, end: 0.3, speed: 1, repeats: 1)
        loop.transcription = PieceTranscription(taps: [.init(seconds: 30)])
        XCTAssertNotNil(loop.transcriptionData)
        loop.transcription = PieceTranscription(taps: [])
        XCTAssertNil(loop.transcriptionData)
    }
}

final class AudioSliceTests: XCTestCase {

    func testTheSliceStartsJustBeforeTheTap() throws {
        let window = try XCTUnwrap(AudioSlice.window(tap: 30, duration: 120))
        XCTAssertEqual(window.start, 30 - AudioSlice.preroll, accuracy: 1e-9)
        XCTAssertEqual(window.length, AudioSlice.length, accuracy: 1e-9)
    }

    func testTheSliceStaysInsideTheSong() throws {
        let top = try XCTUnwrap(AudioSlice.window(tap: 0.02, duration: 120))
        XCTAssertEqual(top.start, 0)
        let end = try XCTUnwrap(AudioSlice.window(tap: 119.9, duration: 120))
        XCTAssertEqual(end.start + end.length, 120, accuracy: 1e-9)
        XCTAssertNil(AudioSlice.window(tap: 1, duration: 0))
    }

    func testTheEnvelopeStartsAndEndsAtSilence() {
        let count = 1000
        XCTAssertEqual(AudioSlice.gain(frame: 0, frameCount: count, fadeInFrames: 10, fadeOutFrames: 100), 0)
        XCTAssertEqual(AudioSlice.gain(frame: count - 1, frameCount: count, fadeInFrames: 10, fadeOutFrames: 100), 0)
        XCTAssertEqual(AudioSlice.gain(frame: 500, frameCount: count, fadeInFrames: 10, fadeOutFrames: 100), 1)
        XCTAssertEqual(AudioSlice.gain(frame: 5, frameCount: count, fadeInFrames: 10, fadeOutFrames: 100), 0.5)
    }

    func testAShortSliceTakesTheSmallerRamp() {
        // Shorter than both fades: the ramps meet, and nothing jumps above either of them.
        let gain = AudioSlice.gain(frame: 4, frameCount: 10, fadeInFrames: 20, fadeOutFrames: 20)
        XCTAssertEqual(gain, min(4.0 / 20, 5.0 / 20), accuracy: 1e-6)
    }
}
