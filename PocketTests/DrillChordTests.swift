import XCTest
@testable import Pocket

/// **The chord under the hand** (ADR 0313, *What the phone showed*): which chord each slot of a Triads run
/// belongs to, its name and numeral, what the line says next, which notes are ringed, and a range the
/// board keeps whole. Pure, SwiftUI-free.
final class DrillChordTests: XCTestCase {

    private func progression(_ name: String, _ steps: [ProgressionStep]) -> TriadRun.Progression {
        TriadRun.Progression(name: name, steps: steps)
    }

    // MARK: - Names and numerals

    func testTheKeysSevenNamesEachChordWithItsNumeralAndColour() {
        let chords = TriadRun.starter.expanded(beatsPerBar: 4).chords ?? []
        XCTAssertEqual(chords.map { $0.name(spelling: .sharps) }, ["C", "Dm", "Em", "F", "G", "Am", "Bdim", "C"])
        XCTAssertEqual(chords.map { $0.numeral?.numeral }, ["I", "ii", "iii", "IV", "V", "vi", "vii°", "I"])
        XCTAssertEqual(chords.map { $0.numeral?.degree }, [1, 2, 3, 4, 5, 6, 7, 1], "the colour is the degree's")
        XCTAssertTrue(chords.allSatisfy { $0.detail == nil }, "the chord changes, so it's the news")
    }

    func testAMinorKeyCountsFromItsOwnTonic() {
        let chords = TriadRun(tonic: 9, isMinor: true).expanded(beatsPerBar: 4).chords ?? []
        XCTAssertEqual(chords.map { $0.numeral?.numeral }, ["i", "ii°", "III", "iv", "v", "VI", "VII", "i"])
    }

    /// The line names what the board plays: a G7 is its G triad (D5), so it's V, not V7.
    func testABiggerChordIsNamedAsTheTriadItPlays() {
        let cadence = ProgressionTemplate.catalog.first { $0.id == "two-five-one" }?.steps ?? []
        let run = TriadRun(tonic: 0, source: .progression, progression: progression("ii–V–I", cadence))
        let chords = run.expanded(beatsPerBar: 4).chords ?? []
        XCTAssertEqual(chords.map { $0.name(spelling: .sharps) }, ["Dm", "G", "C"])
        XCTAssertEqual(chords.map { $0.numeral?.numeral }, ["ii", "V", "I"])
    }

    func testAChordWithNoShapeSaysItRests() {
        let run = TriadRun(tonic: 0, source: .progression,
                           progression: progression("I–I5", [.init(0), .init(0, .fifth)]))
        let chords = run.expanded(beatsPerBar: 4).chords ?? []
        XCTAssertEqual(chords.map(\.detail), [nil, "rests"])
        XCTAssertEqual(chords.last?.name(spelling: .sharps), "C5")
    }

    /// A run of one chord never changes chord, so the line names the inversion, and *then* the next one.
    func testOneChordNamesEachShapesInversion() throws {
        let drill = TriadRun(tonic: 0, source: .oneChord, placement: .upTheNeck).expanded(beatsPerBar: 4)
        let chords = try XCTUnwrap(drill.chords)
        XCTAssertEqual(chords.map(\.detail), ["2nd inversion", "root position", "1st inversion", "2nd inversion"])
        XCTAssertTrue(try XCTUnwrap(drill.chord(after: 0)).isSameChord(as: chords[0]))
    }

    // MARK: - Which chord is playing

    func testEachChordHoldsItsOwnSlotsAndTheCycleWraps() throws {
        let drill = TriadRun.starter.expanded(beatsPerBar: 4)
        let chords = try XCTUnwrap(drill.chords)
        XCTAssertEqual(chords.map(\.slots), (0..<8).map { $0 * 3..<($0 * 3 + 3) }, "three notes each, in order")
        XCTAssertEqual(drill.chordIndex(at: 0), 0)
        XCTAssertEqual(drill.chordIndex(at: 16), 5)
        XCTAssertEqual(drill.chordIndex(at: drill.noteCount), 0, "it loops")
        XCTAssertNil(drill.chordIndex(at: nil), "nothing lit, nothing playing")
        XCTAssertNil(FretboardDrill.spiderWalk.chordIndex(at: 0), "a drill that names no chords")
        XCTAssertEqual(drill.chord(after: 7)?.numeral?.numeral, "I", "then wraps to the top")
    }

    /// A progression's chord lasts its bars, so its slots do too.
    func testAProgressionChordHoldsForItsBars() throws {
        let run = TriadRun(tonic: 0, source: .progression,
                           progression: progression("I–V", [.init(0, bars: 2), .init(7)]), notesPerBeat: 2)
        let chords = try XCTUnwrap(run.expanded(beatsPerBar: 3).chords)
        XCTAssertEqual(chords.map(\.slots), [0..<12, 12..<18])
    }

    // MARK: - What the board rings and counts from

    /// While Am plays, its own A is ringed and every C stops being; with nothing playing, the key's C is.
    func testOnlyTheRootOfTheChordUnderTheHandIsRinged() throws {
        let drill = TriadRun.starter.expanded(beatsPerBar: 4)
        let positions = drill.plottedPositions
        let amIndex = 5
        let aMinor = try XCTUnwrap(drill.chords?[amIndex])
        let amRoot = try XCTUnwrap(positions.first { entry in
            entry.indices.contains { aMinor.slots.contains($0) } && drill.pitchClass(of: entry.note) == 9
        })
        XCTAssertTrue(drill.ringsRoot(amRoot.note, slots: amRoot.indices, chord: amIndex))
        XCTAssertFalse(drill.ringsRoot(amRoot.note, slots: amRoot.indices, chord: nil), "A isn't the key's root")

        let someC = try XCTUnwrap(positions.first { drill.pitchClass(of: $0.note) == 0 })
        XCTAssertFalse(drill.ringsRoot(someC.note, slots: someC.indices, chord: amIndex))
        XCTAssertTrue(drill.ringsRoot(someC.note, slots: someC.indices, chord: nil))

        XCTAssertEqual(drill.readingRoot(chord: amIndex), 9, "intervals count from A")
        XCTAssertEqual(drill.readingRoot(chord: nil), 0)
    }

    /// A root outside the shape under the hand isn't ringed: one chord up the neck, while its third shape
    /// plays at the 8th fret, the C at the nut is someone else's.
    func testARootOutsideTheShapeUnderTheHandIsNotRinged() throws {
        let climb = TriadRun(tonic: 0, source: .oneChord, placement: .upTheNeck).expanded(beatsPerBar: 4)
        let lowC = try XCTUnwrap(climb.plottedPositions.first { $0.note == FretNote(string: 1, fret: 1) })
        XCTAssertFalse(climb.ringsRoot(lowC.note, slots: lowC.indices, chord: 2))
        XCTAssertTrue(climb.ringsRoot(lowC.note, slots: lowC.indices, chord: 0), "it's the open shape's root")
    }

    func testANoteTwoChordsShareBelongsToWhicheverIsPlaying() {
        let drill = TriadRun.starter.expanded(beatsPerBar: 4)
        let shared = drill.plottedPositions.first { entry in
            Set(entry.indices.compactMap { drill.chordIndex(at: $0) }).count > 1
        }
        guard let shared else { return XCTFail("the key's seven in frets 3–7 share notes") }
        for chord in Set(shared.indices.compactMap { drill.chordIndex(at: $0) }) {
            XCTAssertTrue(drill.isPlayed(byChord: chord, slots: shared.indices))
        }
        XCTAssertFalse(drill.isPlayed(byChord: nil, slots: shared.indices))
    }

    func testTheChordsAreNeverWrittenIntoAPayload() throws {
        let drill = TriadRun.starter.expanded(beatsPerBar: 4)
        let data = try JSONEncoder().encode(drill)
        XCTAssertNil(try JSONDecoder().decode(FretboardDrill.self, from: data).chords)
        XCTAssertFalse(try XCTUnwrap(String(bytes: data, encoding: .utf8)).contains("chords"))
    }

    // MARK: - The board's window

    /// A range you stay in is where the hand is, so the board shows all of it, even ten frets, and doesn't
    /// follow the hand inside it (the phone's frets 0–9 scrolled to 3–10 and lost the nut).
    func testAShadedRangeIsShownWholeAndNeverFollows() {
        let drill = TriadRun(tonic: 0, lowFret: 0, highFret: 9).expanded(beatsPerBar: 4)
        let whole = drill.displayWindow(activeIndex: nil)
        XCTAssertEqual(whole, FretWindow(lowestFret: 1, span: 10))
        for index in 0..<drill.noteCount {
            XCTAssertEqual(drill.displayWindow(activeIndex: index), whole)
        }
    }

    /// Up the neck, the board follows the chord, not the note: the phone's F (frets 10, 10, then 8)
    /// scrolled the window up to 9–16 for its F and straight back to 3–10 for its C. Now the window holds
    /// for each chord, moves only when the chord changes, and shows every note of the chord under the hand.
    func testTheBoardFollowsTheChordNotTheNote() throws {
        let climb = TriadRun(tonic: 0, placement: .upTheNeck).expanded(beatsPerBar: 4)
        let chords = try XCTUnwrap(climb.chords)
        XCTAssertGreaterThan(climb.displayFretSpan, FretboardDrill.comfortableFretSpan, "a climb that follows")
        for chord in chords {
            let windows = chord.slots.map { climb.displayWindow(activeIndex: $0) }
            XCTAssertEqual(Set(windows.map(\.lowestFret)).count, 1, "\(chord.root): the window holds for the chord")
            let notes = chord.slots.compactMap { climb.note(at: $0) }
            XCTAssertEqual(notes.count, 3)
            for window in windows {
                XCTAssertTrue(notes.allSatisfy { window.shows($0) }, "\(chord.root): all of it in view, every beat")
            }
        }
        // C, Dm, Em at 3–9 fit the first window; F (8–10) moves it once, to 7; Am (12–14) once more.
        let lows = chords.map { climb.displayWindow(activeIndex: $0.slots.lowerBound).lowestFret }
        XCTAssertEqual(lows, [3, 3, 3, 7, 7, 10, 10, 10])
    }

    /// An open string sits on the nut, so a window that has followed the hand up the neck doesn't draw it.
    func testAnOpenStringShowsOnlyWhileTheNutIsInView() {
        let open = FretNote(string: 0, fret: 0)
        XCTAssertTrue(FretWindow(lowestFret: 1, span: 8).shows(open))
        XCTAssertFalse(FretWindow(lowestFret: 3, span: 8).shows(open))
        XCTAssertTrue(FretWindow(lowestFret: 3, span: 8).shows(FretNote(string: 0, fret: 10)))
        XCTAssertFalse(FretWindow(lowestFret: 3, span: 8).shows(FretNote(string: 0, fret: 11)))
        XCTAssertFalse(FretWindow(lowestFret: 3, span: 8).shows(FretNote(string: 0, fret: 2)))

        // One chord up the neck still follows the hand, from the open shape to the 12th fret.
        let climb = TriadRun(tonic: 0, source: .oneChord, placement: .upTheNeck).expanded(beatsPerBar: 4)
        let top = climb.displayWindow(activeIndex: climb.noteCount - 1)
        XCTAssertGreaterThan(top.lowestFret, 1)
        XCTAssertFalse(top.shows(FretNote(string: 2, fret: 0)))
    }
}
