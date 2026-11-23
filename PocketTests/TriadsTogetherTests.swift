import XCTest
@testable import Pocket

/// **The board shows a chord** (ADR 0313 D7, D8, slice 3): *Play as* Together and the companions it lights,
/// where the fingers just were, and the chips under the editor's board. Pure, SwiftUI-free.
final class TriadsTogetherTests: XCTestCase {

    private func progression(_ name: String, _ steps: [ProgressionStep]) -> TriadRun.Progression {
        TriadRun.Progression(name: name, steps: steps)
    }

    private func note(_ string: Int, _ fret: Int) -> FretNote { FretNote(string: string, fret: fret) }

    /// I – V – vi – IV in C, G‑B‑e, frets 3 to 7: C 5‑5‑3, G 4‑3‑3, Am 5‑5‑5, F 5‑6‑5 (`TriadRunTests`).
    private func loop(_ playAs: TriadRun.PlayAs = .broken, placement: TriadRun.Placement = .stayInFrets) -> TriadRun {
        TriadRun(tonic: 0, source: .progression, progression: TriadRun.defaultProgression, placement: placement,
                 playAs: playAs)
    }

    // MARK: - Play as (D7)

    func testPlayAsRoundTripsAndAnOlderRunPlaysBroken() throws {
        let run = TriadRun(tonic: 2, playAs: .together)
        let data = try JSONEncoder().encode(FretboardContent.triads(run))
        XCTAssertEqual(try JSONDecoder().decode(FretboardContent.self, from: data), .triads(run))

        let before = #"{"version":1,"tonic":7}"#
        XCTAssertEqual(try JSONDecoder().decode(TriadRun.self, from: Data(before.utf8)).playAs, .broken,
                       "a run saved before Play as existed plays as it did")
        let newer = #"{"version":2,"tonic":7,"playAs":"strummed"}"#
        XCTAssertEqual(try JSONDecoder().decode(TriadRun.self, from: Data(newer.utf8)).playAs, .broken)
    }

    /// Together lights the shape at once and holds it for the slots Broken would take, so switching never
    /// changes how long the run is.
    func testTogetherTakesBrokensTimeAndSoundsTheWholeShapeInEverySlot() throws {
        for run in [TriadRun.starter, loop(), TriadRun(tonic: 0, source: .oneChord, placement: .upTheNeck)] {
            var together = run
            together.playAs = .together
            let broken = run.expanded(beatsPerBar: 4)
            let held = together.expanded(beatsPerBar: 4)
            XCTAssertEqual(held.noteCount, broken.noteCount)
            XCTAssertEqual(held.chords?.map(\.slots), broken.chords?.map(\.slots))
            XCTAssertTrue(held.playsTogether)
            XCTAssertFalse(broken.playsTogether)
            XCTAssertNil(broken.companions, "Broken plays one note a slot, as it always has")
            for (item, chord) in zip(together.placed(), try XCTUnwrap(held.chords)) {
                let shape = try XCTUnwrap(item.shape).notes
                for slot in chord.slots {
                    XCTAssertEqual(held.notes[slot], shape[0], "the slot's own note is the bass")
                    XCTAssertEqual(held.sounding(at: slot), shape, "all three, low string to high")
                }
            }
        }
    }

    func testAChordThatRestsHasNoCompanions() {
        let run = TriadRun(tonic: 0, source: .progression,
                           progression: progression("I–I5", [.init(0), .init(0, .fifth)]), playAs: .together)
        let drill = run.expanded(beatsPerBar: 4)
        XCTAssertEqual(drill.noteCount, 16)
        XCTAssertTrue((8..<16).allSatisfy { drill.notes[$0] == nil && drill.sounding(at: $0).isEmpty })
        XCTAssertTrue((0..<8).allSatisfy { drill.sounding(at: $0).count == 3 })
    }

    /// The board plots positions, not slots: a companion plays its slot as much as the bass does, so it's
    /// paired with every slot it sounds in, and the static board shows the same notes either way.
    func testCompanionsArePlottedWithEverySlotTheySoundIn() throws {
        let broken = loop().expanded(beatsPerBar: 4)
        let held = loop(.together).expanded(beatsPerBar: 4)
        XCTAssertEqual(Set(held.plottedPositions.map(\.note)), Set(broken.plottedPositions.map(\.note)))
        let topG = try XCTUnwrap(held.plottedPositions.first { $0.note == note(0, 3) })
        XCTAssertEqual(topG.indices, Array(0..<16), "the high-e G sounds through C and then G")
        let middleE = try XCTUnwrap(held.plottedPositions.first { $0.note == note(1, 5) })
        XCTAssertEqual(middleE.indices, Array(0..<8) + Array(16..<24), "C, then Am")
        XCTAssertTrue(held.isPlayed(byChord: 1, slots: topG.indices))
    }

    /// Up the neck, the window takes the whole chord: every note sounding is in view, companions included.
    func testTheWindowKeepsEveryNoteOfAChordPlayedTogetherInView() {
        var run = TriadRun(tonic: 0, placement: .upTheNeck)
        run.playAs = .together
        let drill = run.expanded(beatsPerBar: 4)
        let broken = TriadRun(tonic: 0, placement: .upTheNeck).expanded(beatsPerBar: 4)
        XCTAssertEqual(drill.displayWindow(activeIndex: nil), broken.displayWindow(activeIndex: nil))
        XCTAssertGreaterThan(drill.displayFretSpan, FretboardDrill.comfortableFretSpan, "a climb that follows")
        for slot in 0..<drill.noteCount {
            let window = drill.displayWindow(activeIndex: slot)
            XCTAssertEqual(window, broken.displayWindow(activeIndex: slot), "the window moves as Broken's does")
            for sounding in drill.sounding(at: slot) {
                XCTAssertTrue(window.shows(sounding), "slot \(slot): \(sounding) is off the board")
            }
        }
    }

    // MARK: - Where the fingers just were (D8)

    /// A note two shapes share is a finger that stayed: only the ones that moved are ringed.
    func testTheNotesOfTheShapeBeforeThatMovedAreRinged() {
        for playAs in TriadRun.PlayAs.allCases {
            let drill = loop(playAs).expanded(beatsPerBar: 4)
            XCTAssertEqual(drill.notesJustLeft(chord: 0), [], "the first chord has nowhere the fingers were")
            XCTAssertEqual(drill.notesJustLeft(chord: 1), [note(2, 5), note(1, 5)], "C to G keeps the high-e G")
            XCTAssertEqual(drill.notesJustLeft(chord: 2), [note(2, 4), note(1, 3), note(0, 3)], "G to Am")
            XCTAssertEqual(drill.notesJustLeft(chord: 3), [note(1, 5)], "Am to F moves one finger")
            XCTAssertEqual(drill.notesJustLeft(chord: nil), [], "nothing while nothing plays")
        }
    }

    /// A chord that rests rings nothing, and the chord after it rings the last shape that played.
    func testARestIsPassedOverForTheShapeBeforeIt() {
        let run = TriadRun(tonic: 0, source: .progression,
                           progression: progression("I–I5–V", [.init(0), .init(0, .fifth), .init(7)]))
        let drill = run.expanded(beatsPerBar: 4)
        XCTAssertEqual(drill.notesJustLeft(chord: 1), [])
        XCTAssertEqual(drill.notesJustLeft(chord: 2), [note(2, 5), note(1, 5)], "from the C, past the C5")
    }

    func testABoardThatDoesNotNameItsChordsRingsNothing() {
        XCTAssertEqual(FretboardDrill.spiderWalk.notesJustLeft(chord: 0), [])
        XCTAssertNil(FretboardDrill.spiderWalk.companions)
        XCTAssertFalse(FretboardDrill.spiderWalk.playsTogether)
        XCTAssertEqual(FretboardDrill.spiderWalk.sounding(at: 0), [note(5, 1)])
    }

    // MARK: - The chips (D8)

    func testEachChipSaysTheChordItsNumeralInversionAndFrets() {
        let chips = loop().chips()
        XCTAssertEqual(chips.map(\.name), ["C", "G", "Am", "F"])
        XCTAssertEqual(chips.map(\.shapeLine), ["I · root", "V · 1st inv", "vi · 1st inv", "IV · 2nd inv"])
        XCTAssertEqual(chips.map(\.fretLine), ["5 5 3", "4 3 3", "5 5 5", "5 6 5"], "low string first")
        XCTAssertTrue(chips.allSatisfy { $0.rest == nil && $0.playsAs == nil && !$0.startsPass })
        XCTAssertEqual(chips.first?.spoken, "C, I, root position, frets 5 5 3")
    }

    /// Chip *n* is the board's chord *n*, and wears the same colour.
    func testTheChipsLineUpWithTheBoardsChords() {
        for run in [TriadRun.starter, loop(placement: .upTheNeck), TriadRun(tonic: 9, isMinor: true, lowFret: 4,
                                                                             highFret: 8)] {
            let chips = run.chips()
            let chords = run.expanded(beatsPerBar: 4).chords ?? []
            XCTAssertEqual(chips.count, chords.count)
            XCTAssertEqual(chips.map(\.degree), chords.map { $0.numeral?.degree })
        }
    }

    /// A bigger chord is named as written and says the triad it plays (D5).
    func testABiggerChordsChipSaysWhatItPlays() {
        let cadence = ProgressionTemplate.catalog.first { $0.id == "two-five-one" }?.steps ?? []
        let chips = TriadRun(tonic: 0, source: .progression, progression: progression("ii–V–I", cadence)).chips()
        XCTAssertEqual(chips.map(\.name), ["Dm7", "G7", "Cmaj7"])
        XCTAssertEqual(chips.map(\.playsAs), ["Dm", "G", "C"])
        XCTAssertEqual(chips.map(\.numeral), ["ii7", "V7", "Imaj7"])
        XCTAssertTrue(chips[0].spoken.hasPrefix("Dm7, plays Dm, ii7, "))
    }

    func testAChordThatRestsSaysWhy() {
        let power = TriadRun(tonic: 0, source: .progression,
                             progression: progression("I–I5", [.init(0), .init(0, .fifth)])).chips()
        XCTAssertEqual(power.last?.rest, .noTriad)
        XCTAssertEqual(power.last?.fretLine, "no triad")
        XCTAssertNil(power.last?.inversion)

        let narrow = TriadRun(tonic: 0, lowFret: 4, highFret: 8)
        let missing = narrow.chips().filter { $0.rest == .noShape }
        XCTAssertEqual(missing.map(\.name), ["C", "Em", "C"], "a chip per chord played; the help names each once")
        XCTAssertEqual(Set(missing.map(\.name)), Set(narrow.chordsWithNoShape()))
        XCTAssertTrue(missing.allSatisfy { $0.fretLine == "no shape" && $0.frets == nil })
        XCTAssertTrue(missing.first?.spoken.hasSuffix("no shape between these frets, so it rests") ?? false)
    }

    /// An augmented triad is the same shape in every inversion, so its chip names none (D1).
    func testAnAugmentedChipNamesNoInversion() throws {
        let chips = TriadRun(tonic: 0, source: .progression,
                             progression: progression("I–I+", [.init(0), .init(0, .augmented)]),
                             lowFret: 0, highFret: 9).chips()
        let aug = try XCTUnwrap(chips.last)
        XCTAssertNil(aug.inversion)
        XCTAssertNotNil(aug.frets)
        XCTAssertFalse(aug.shapeLine.contains("inv"))
    }

    /// Up the neck a progression plays three passes; each after the first starts apart.
    func testALaterPassStartsApart() {
        let chips = loop(placement: .upTheNeck).chips()
        XCTAssertEqual(chips.count, 12)
        XCTAssertEqual(chips.indices.filter { chips[$0].startsPass }, [4, 8])
        XCTAssertEqual(chips[4].pass, 1)
        XCTAssertTrue(chips[8].spoken.hasPrefix("Pass 3, C, I, "))
    }
}
