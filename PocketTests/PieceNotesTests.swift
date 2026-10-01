import XCTest
@testable import Pocket

/// A piece's notes without their seconds (ADR 0235 D9): what a loop's piece gives the reading view, and all
/// a tab written on the neck has. A loop's piece must read exactly as it did through its notes.
final class PieceNotesTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi

    private func fret(_ string: Int, _ fret: Int, into join: Join? = nil) -> PieceLabel {
        .fretted([FrettedNote(string: string, fret: fret)], into: join)
    }

    private var labels: [PieceLabel?] {
        [fret(2, 5), fret(2, 7, into: .legato), nil, .pitchClass(9), nil, nil, nil, nil, .chord(root: 9, suffix: "m")]
    }

    /// Taps out of order, so the piece's sorting is part of what the notes must carry.
    private var piece: PieceTranscription {
        let seconds: [Double] = [3, 1, 4, 0, 5, 9, 2, 6, 8]
        let taps = zip(seconds, labels).map { PieceTranscription.Tap(seconds: $0.0, label: $0.1) }
        return PieceTranscription(taps: taps, openMidi: guitar, tuningLabel: "Guitar · Standard")
    }

    func testAPiecesNotesAreItsLabelsInTapOrderWithItsTuning() {
        let notes = piece.notes
        XCTAssertEqual(notes.labels, piece.labels, "in tap order, not the order they were given")
        XCTAssertEqual(notes.openMidi, guitar)
        XCTAssertEqual(notes.tuningLabel, "Guitar · Standard")
        XCTAssertEqual(notes.count, 9)
        XCTAssertTrue(notes.hasFrettedLabels)
    }

    func testAPieceReadsTheSameThroughItsNotes() {
        for spelling in [NoteSpelling.sharps, .flats] {
            XCTAssertEqual(piece.notes.names(spelling: spelling), piece.names(spelling: spelling))
            XCTAssertEqual(piece.notes.summary(spelling: spelling), piece.summary(spelling: spelling))
            XCTAssertEqual(PieceStaff.columns(of: piece.notes, spelling: spelling),
                           PieceStaff.columns(of: piece, spelling: spelling))
            XCTAssertEqual(PieceStaff.groups(of: piece.notes, spelling: spelling).map { $0.map(\.name) },
                           PieceStaff.groups(of: piece, spelling: spelling).map { $0.map(\.name) })
        }
        XCTAssertEqual(PieceStaff.meta(of: piece.notes), PieceStaff.meta(of: piece))
    }

    /// Written the long way, so a forwarder that reads the wrong field can't pass by agreeing with itself.
    func testNotesWithNoSecondsSayWhatTheyAre() {
        let notes = PieceNotes(labels: [fret(2, 5), nil, fret(1, 8)], openMidi: guitar, tuningLabel: "Guitar · Drop D")
        XCTAssertEqual(PieceStaff.meta(of: notes), "3 notes · Guitar · Drop D · 1 unnamed")
        XCTAssertEqual(notes.names(spelling: .sharps), ["C", nil, "G"], "G string fret 5, B string fret 8")
        XCTAssertEqual(PieceStaff.columns(of: notes, spelling: .sharps).map(\.above), [nil, "·", nil])
    }

    func testNotesWithNothingOnTheNeckHaveNoTuningToSay() {
        let notes = PieceNotes(labels: [.pitchClass(0), .pitchClass(4)])
        XCTAssertFalse(notes.hasFrettedLabels)
        XCTAssertEqual(PieceStaff.meta(of: notes), "2 notes")
        XCTAssertEqual(notes.names(spelling: .sharps), ["C", "E"])
    }

    func testChordsAreCountedAsChords() {
        let notes = PieceNotes(labels: [.chord(root: 9, suffix: "m"), .chord(root: 0, suffix: "")])
        XCTAssertEqual(PieceStaff.meta(of: notes), "2 chords")
        XCTAssertEqual(notes.summary(spelling: .sharps)?.hasPrefix("2 chords"), true)
    }
}
