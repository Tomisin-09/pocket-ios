import XCTest
@testable import Pocket

/// The chords under what's watched (ADR 0308 D4–D6): which chord the song is on, read from the whole chords
/// lane (`SectionWatch.chords`), then named, numbered and handed to each chip (`WatchChords`).
final class WatchChordsTests: XCTestCase {

    private let standard = Instrument.guitar.standardTuning.engineOpenMidi
    private let aMinorChord = PieceLabel.chord(root: 9, suffix: "m")
    private let gMajor = PieceLabel.chord(root: 7, suffix: "")
    private let fMajor = PieceLabel.chord(root: 5, suffix: "")
    private let eMajor = PieceLabel.chord(root: 4, suffix: "")

    private func source(_ start: TimeInterval, _ end: TimeInterval, _ taps: [(TimeInterval, PieceLabel?)],
                        chords: Bool = true) -> SectionWatch.Source {
        SectionWatch.Source(id: UUID(), name: chords ? "Changes" : "Riff", start: start, end: end, reach: end,
                            piece: PieceTranscription(taps: taps.map { .init(seconds: $0.0, label: $0.1) },
                                                      openMidi: standard),
                            isChords: chords)
    }

    private func aMinor(_ chords: [SectionWatch.Chord]) -> WatchChords {
        WatchChords(chords, key: .aMinor, spelling: NoteSpelling.forMusicalKey(.aMinor) ?? .default)
    }

    // MARK: - The chords lane

    func testTheChordsLaneSaysWhichChordTheSongIsOnAndUntilWhen() {
        let lane = source(0, 16, [(0, aMinorChord), (4, gMajor), (8, fMajor), (12, eMajor)])
        let chords = SectionWatch.chords([lane], from: 0, to: 16)
        XCTAssertEqual(chords.map(\.root), [9, 7, 5, 4])
        XCTAssertEqual(chords.map(\.until), [4, 8, 12, 16])
    }

    func testAShapePlacedOnTheNeckCountsAsTheChordItSpells() {
        let openC = PieceLabel.fretted([FrettedNote(string: 4, fret: 3), FrettedNote(string: 3, fret: 2),
                                        FrettedNote(string: 2, fret: 0), FrettedNote(string: 1, fret: 1),
                                        FrettedNote(string: 0, fret: 0)], into: nil)
        let chords = SectionWatch.chords([source(0, 8, [(1, openC)])], from: 0, to: 8)
        XCTAssertEqual(chords, [.init(seconds: 1, until: 8, root: 0, suffix: "")])
    }

    func testANotesPieceIsNeverAChordAndATapNamingNoChordEndsOne() {
        // A notes piece with a chord named among its notes is still a line, not the chords lane.
        let riff = source(0, 8, [(1, .fretted(string: 2, fret: 5)), (3, gMajor)], chords: false)
        XCTAssertTrue(SectionWatch.chords([riff], from: 0, to: 8).isEmpty)
        let lane = source(0, 8, [(0, aMinorChord), (2, nil), (4, gMajor)])
        let chords = SectionWatch.chords([lane], from: 0, to: 8)
        XCTAssertEqual(chords.map(\.until), [2, 8], "Am stops where an unnamed tap is")
        XCTAssertNil(aMinor(chords).index(at: 3), "no chord between them: the notes are drawn as they are")
    }

    // MARK: - Named and numbered

    func testEachChordIsNamedAndNumberedInTheSongsKey() {
        let lane = source(0, 16, [(0, aMinorChord), (4, gMajor), (8, fMajor), (12, eMajor)])
        let chords = aMinor(SectionWatch.chords([lane], from: 0, to: 16))
        XCTAssertEqual(chords.chords.map(\.title), ["Am · i", "G · VII", "F · VI", "E · V"])
        XCTAssertEqual(chords.chords.map { $0.numeral?.degree }, [1, 7, 6, 5])
        XCTAssertTrue(chords.hasNumerals)
    }

    func testARootOutsideTheKeyIsSpelledAsItsNumeralSays() {
        let lane = source(0, 8, [(0, .chord(root: 10, suffix: "")), (4, .chord(root: 1, suffix: "m"))])
        let chords = aMinor(SectionWatch.chords([lane], from: 0, to: 8))
        XCTAssertEqual(chords.chords.map(\.title), ["B♭ · ♭II", "C♯m · ♯iii"])
    }

    func testWithNoKeyAChordIsItsNameAlone() {
        let lane = source(0, 8, [(0, aMinorChord), (4, gMajor)])
        let chords = WatchChords(SectionWatch.chords([lane], from: 0, to: 8), key: .unknown, spelling: .default)
        XCTAssertEqual(chords.chords.map(\.title), ["Am", "G"])
        XCTAssertFalse(chords.hasNumerals, "so the sheet offers Set the key")
    }

    func testTheSameChordPlayedAgainInARowIsHeldAsOne() {
        let lane = source(0, 8, [(0, aMinorChord), (2, aMinorChord), (4, gMajor)])
        let chords = aMinor(SectionWatch.chords([lane], from: 0, to: 8))
        XCTAssertEqual(chords.chords.map(\.name), ["Am", "G"])
        XCTAssertEqual(chords.chords.first?.until, 4)
    }

    func testWhatComesNext() throws {
        let lane = source(0, 12, [(0, aMinorChord), (4, gMajor), (8, fMajor)])
        let chords = aMinor(SectionWatch.chords([lane], from: 0, to: 12))
        let now = try XCTUnwrap(chords.index(at: 5))
        XCTAssertEqual(chords.chords[now].name, "G")
        XCTAssertEqual(chords.next(after: now)?.title, "F · VI", "then F · VI")
        XCTAssertNil(chords.next(after: chords.chords.count - 1))
    }

    // MARK: - The chips

    func testEachTapTakesItsChordAndTheFirstOfEachCarriesItsName() {
        let lane = source(0, 12, [(0, aMinorChord), (4, gMajor), (8, fMajor)])
        let chords = aMinor(SectionWatch.chords([lane], from: 0, to: 12))
        let indices = chords.chordIndices(of: [0.5, 1, 4.5, 9, 13])
        XCTAssertEqual(indices, [0, 0, 1, 2, nil])
        XCTAssertEqual(indices.indices.map { WatchChords.startsAChord(indices, at: $0) },
                       [true, false, true, true, false])
    }
}
