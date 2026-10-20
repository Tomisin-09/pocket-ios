import XCTest
@testable import Pocket

/// Dead notes (ADR 0262): a ✕ on a string, alone or beside fretted notes, or *Muted* named by ear. Stored so
/// an older build reads a ✕ as unnamed rather than as a wrong note, placed by the same one-entry-per-string
/// rule as notes, invisible to joins and pitch, and written `x` in tab.
final class MutedNoteTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi   // [64, 59, 55, 50, 45, 40]

    private func note(_ string: Int, _ fret: Int, leadIn: LeadIn? = nil) -> FrettedNote {
        FrettedNote(string: string, fret: fret, leadIn: leadIn)
    }

    private func json(_ label: PieceLabel) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try XCTUnwrap(String(data: encoder.encode(label), encoding: .utf8))
    }

    private func decoded(_ text: String) throws -> PieceLabel {
        try JSONDecoder().decode(PieceLabel.self, from: Data(text.utf8))
    }

    // MARK: - What it is

    func testADeadNoteHasNoPitchAndReadsAsACross() {
        for label in [PieceLabel.muted, .muted(strings: [4, 5])] {
            XCTAssertTrue(label.isMuted)
            XCTAssertNil(label.pitchClass(openMidi: guitar))
            XCTAssertNil(label.midiNote(openMidi: guitar))
            XCTAssertNil(label.earReading(openMidi: guitar))
            XCTAssertEqual(label.name(openMidi: guitar, spelling: .sharps), "✕")
        }
        XCTAssertFalse(PieceLabel.muted.isOnTheNeck, "named by ear: no string")
        XCTAssertTrue(PieceLabel.muted(strings: [4]).isOnTheNeck, "a ✕ is a position, neck work")
    }

    func testAChordStrummedThroughAMutedStringIsItsChord() {
        // C major, x32010, with the low E struck dead.
        let chord = PieceLabel.fretted([note(4, 3), note(3, 2), note(2, 0), note(1, 1), note(0, 0)], muted: [5],
                                       into: nil)
        XCTAssertFalse(chord.isMuted)
        XCTAssertEqual(chord.name(openMidi: guitar, spelling: .sharps), "C")
        XCTAssertEqual(chord.earReading(openMidi: guitar), EarReading(root: 0, kind: .chord(suffix: "")))
        XCTAssertEqual(chord.mutedStrings, [5])
    }

    // MARK: - Coding (D5)

    func testEveryShapeOfMutedRoundTrips() throws {
        let labels: [PieceLabel] = [
            .muted,
            .muted(strings: [3, 4, 5]),
            .fretted([note(1, 5)], muted: [0, 2], into: nil),
            .fretted([note(2, 7), note(1, 8)], muted: [0], into: .slide)
        ]
        let data = try JSONEncoder().encode(labels)
        XCTAssertEqual(try JSONDecoder().decode([PieceLabel].self, from: data), labels)
    }

    func testOnlyCrossesAreTheMutedKindWhichAnOlderBuildReadsAsUnnamed() throws {
        XCTAssertEqual(try json(.muted), #"{"kind":"muted"}"#)
        XCTAssertEqual(try json(.muted(strings: [5, 4])), #"{"kind":"muted","strings":[4,5]}"#)
    }

    func testCrossesBesideNotesAreAKeyAnOlderBuildDrops() throws {
        // The fret and shape keys are written exactly as before, so a build that ignores `muted` keeps the
        // notes that sound.
        XCTAssertEqual(try json(.fretted([note(1, 5)], muted: [2, 0], into: nil)),
                       #"{"fret":5,"kind":"fret","muted":[0,2],"string":1}"#)
        XCTAssertEqual(try json(.fretted([note(1, 5)], into: nil)), #"{"fret":5,"kind":"fret","string":1}"#,
                       "no ✕, no key")
        XCTAssertEqual(try decoded(#"{"fret":5,"kind":"fret","string":1}"#), .fretted(string: 1, fret: 5))
    }

    func testAStringIsFrettedOrMutedNeverBoth() throws {
        let label = try decoded(#"{"kind":"fret","string":1,"fret":5,"muted":[1,2,-1]}"#)
        XCTAssertEqual(label, .fretted([note(1, 5)], muted: [2], into: nil), "the note wins; -1 is no string")
        XCTAssertEqual(try decoded(#"{"kind":"muted","strings":[-2]}"#), .muted, "no string left: by ear")
    }

    func testAPieceWithAKindItDoesntKnowLosesOnlyThatName() throws {
        // What an older build does with `muted`, played here with a kind this build doesn't know.
        let text = #"{"version":1,"taps":[{"seconds":1,"label":{"kind":"future"}},"#
            + #"{"seconds":2,"label":{"kind":"muted"}}]}"#
        let piece = try XCTUnwrap(PieceTranscription.decoded(from: Data(text.utf8)))
        XCTAssertEqual(piece.labels, [nil, PieceLabel.muted])
    }

    // MARK: - Placing a ✕ (D2)

    func testWithChordsOffACrossReplacesAnythingAndMovesOn() {
        let labels: [PieceLabel?] = [.fretted(string: 2, fret: 5), nil]
        let edit = NeckEditing.mute(string: 4, labels: labels, cursor: NeckCursor(active: 0))
        XCTAssertEqual(edit.labels, [.muted(strings: [4]), nil])
        XCTAssertEqual(edit.cursor.active, 1, "on to the next note, as placing does")
    }

    func testTappingTheCrossAlreadyThereConfirmsIt() {
        let outcome = NeckPlacement.mute(string: 4, on: .muted(strings: [4]), ringed: nil, chords: false)
        XCTAssertEqual(outcome.label, .muted(strings: [4]))
    }

    func testWithChordsOnACrossGoesIntoTheChord() {
        let shape = PieceLabel.fretted([note(2, 5), note(1, 5)], into: nil)
        // On an empty string: added.
        let added = NeckPlacement.mute(string: 3, on: shape, ringed: 1, chords: true)
        XCTAssertEqual(added.label, .fretted([note(2, 5), note(1, 5)], muted: [3], into: nil))
        // On a string with a note: the note goes, the ✕ takes its place, the ring moves to a note.
        let swapped = NeckPlacement.mute(string: 1, on: shape, ringed: 1, chords: true)
        XCTAssertEqual(swapped.label, .fretted([note(2, 5)], muted: [1], into: nil))
        XCTAssertEqual(swapped.ringed, 2)
        // On a ✕: it comes out.
        let out = NeckPlacement.mute(string: 3, on: added.label, ringed: 1, chords: true)
        XCTAssertEqual(out.label, shape)
    }

    func testTheLastCrossStays() {
        let outcome = NeckPlacement.mute(string: 4, on: .muted(strings: [4]), ringed: nil, chords: true)
        XCTAssertEqual(outcome.label, .muted(strings: [4]), "all the tap holds")
        let chuck = NeckPlacement.mute(string: 4, on: .muted(strings: [4, 5]), ringed: nil, chords: true)
        XCTAssertEqual(chuck.label, .muted(strings: [5]))
    }

    func testAFretOnAMutedStringPutsItBackOnTheNeck() {
        let chuck = PieceLabel.muted(strings: [3, 4])
        let chords = NeckPlacement.tap(string: 3, fret: 7, on: chuck, ringed: nil, chords: true)
        XCTAssertEqual(chords.label, .fretted([note(3, 7)], muted: [4], into: nil))
        let replaced = NeckPlacement.tap(string: 3, fret: 7, on: chuck, ringed: nil, chords: false)
        XCTAssertEqual(replaced.label, .fretted(string: 3, fret: 7), "Chords off: the note replaces the ✕s")
    }

    func testTheLastNoteCanComeOutWhileACrossIsLeft() {
        let label = PieceLabel.fretted([note(2, 5)], muted: [3], into: nil)
        let outcome = NeckPlacement.tap(string: 2, fret: 5, on: label, ringed: 2, chords: true)
        XCTAssertEqual(outcome.label, .muted(strings: [3]))
    }

    func testACrossWaitsWhileIntoItWantsAFret() {
        let labels: [PieceLabel?] = [.fretted(string: 2, fret: 5)]
        let cursor = NeckCursor(active: 0, awaitingStart: LeadInRequest(join: .slide, direction: nil))
        XCTAssertEqual(NeckEditing.mute(string: 4, labels: labels, cursor: cursor).labels, labels)
    }

    func testMarksAndLeadInsKeepTheCrossesBesideThem() {
        let labels: [PieceLabel?] = [.fretted([note(2, 5)], muted: [3], into: nil)]
        let bent = NeckEditing.mark({ $0.bend = 2 }, labels: labels, cursor: NeckCursor(active: 0))
        XCTAssertEqual(bent, [.fretted([FrettedNote(string: 2, fret: 5, bend: 2)], muted: [3], into: nil)])
        let slid = NeckEditing.slideIn(from: .below, labels: labels, cursor: NeckCursor(active: 0)).labels
        XCTAssertEqual(slid[0]?.mutedStrings, [3])
    }

    // MARK: - Joins (D2)

    func testACrossHasNoWayInAndIsNoTapBefore() {
        let labels: [PieceLabel?] = [.fretted(string: 2, fret: 5), .muted(strings: [2]), .fretted(string: 2, fret: 7)]
        XCTAssertEqual(NeckJoin.blocker(into: 1, of: labels), .muted)
        XCTAssertEqual(NeckJoin.blocker(into: 2, of: labels), .previousMuted)
        XCTAssertEqual(NeckJoin.route(.slide, into: 1, of: labels), .unavailable)
        XCTAssertEqual(NeckJoin.blocker(into: 1, of: [.fretted(string: 2, fret: 5), .muted]), .muted)
    }

    func testAChordSlidesWithItsMutedStringsRidingAlong() {
        // A 9th chord slid up a fret, its low E and high e muted both times.
        let from = PieceLabel.fretted([note(4, 7), note(3, 6), note(2, 7), note(1, 7)], muted: [0, 5], into: nil)
        let to = PieceLabel.fretted([note(4, 8), note(3, 7), note(2, 8), note(1, 8)], muted: [0, 5], into: .slide)
        XCTAssertEqual(NeckJoin.direction(into: 1, of: [from, to]), .upward)
        XCTAssertEqual(NeckJoin.symbol(into: 1, of: [from, to]), "/")
        XCTAssertEqual(NeckJoin.tidied([from, to]), [from, to], "the join still fits, the ✕s are kept")
    }

    // MARK: - Tab (D4)

    func testTabWritesAnXOnEachMutedStringAndNoJoinOnOne() throws {
        let labels: [PieceLabel?] = [
            .fretted([note(2, 5)], muted: [3], into: nil),
            .fretted([note(2, 7)], muted: [3], into: .legato),
            .muted(strings: [1, 2]),
            .muted
        ]
        let tab = try XCTUnwrap(TabLine.render(labels, openMidi: guitar))
        let lines = tab.components(separatedBy: "\n")
        XCTAssertEqual(lines[1], "B|------x--|", "the chuck's x")
        XCTAssertEqual(Set(lines.map(\.count)).count, 1, "every line the same width: \(tab)")
        XCTAssertEqual(lines[2], "G|-5h7--x--|", "the hammer-on joins the notes")
        XCTAssertEqual(lines[3], "D|-x-x-----|", "never an x")
        XCTAssertEqual(TabLine.columns(of: labels, openMidi: guitar).count, 3, "Muted by ear has no string")
    }

    func testTheReadingViewWritesXOnStringsAndAboveThemForMutedByEar() {
        let notes = PieceNotes(labels: [.muted(strings: [4, 5]), .muted, .fretted([note(1, 5)], muted: [0], into: nil)],
                               openMidi: guitar)
        let columns = PieceStaff.columns(of: notes, spelling: .sharps)
        XCTAssertEqual(columns[0].cells.map(\.text), ["x", "x"])
        XCTAssertNil(columns[0].above)
        XCTAssertEqual(columns[1].above, "x", "ASCII in the fixed-width rows")
        XCTAssertTrue(columns[1].cells.isEmpty)
        XCTAssertFalse(columns[1].isQuiet, "named")
        XCTAssertEqual(columns[2].cells.map(\.text), ["x", "5"])
    }

    func testTheSongsTabWritesXAndSaysMuted() throws {
        let piece = PieceTranscription(taps: [.init(seconds: 1, label: .muted(strings: [5])),
                                              .init(seconds: 2, label: .muted)], openMidi: guitar)
        XCTAssertEqual(SongTabLayout.cells(0, of: piece)?.map(\.text), ["x"])
        let byEar = SongTabLayout.column(1, of: piece, piece: UUID(), layer: .notes, spelling: .sharps)
        XCTAssertEqual(byEar.name, "muted", "VoiceOver never hears multiplication x")
        guard case .name(let text) = byEar.mark else { return XCTFail("a name, not a slash") }
        XCTAssertEqual(text, "x")
    }

    // MARK: - Counting (D1, D4)

    func testADeadNoteIsNamedAndSaidInTheLine() {
        let notes = PieceNotes(labels: [.pitchClass(9), .muted, .muted(strings: [4]), nil, .pitchClass(2)],
                               openMidi: guitar)
        XCTAssertEqual(notes.summary(spelling: .sharps), "5 notes. A ✕ ✕ ? D")
        XCTAssertEqual(PieceStaff.meta(of: notes), "5 notes · 1 unnamed")
        XCTAssertEqual(NamingStrip.nextUnnamed(after: 0, in: notes.labels), 3, "skips the ✕s")
    }

    func testChucksDontStopAPartCountingInChords() {
        let strummed = PieceNotes(labels: [.chord(root: 0, suffix: ""), .muted, .chord(root: 7, suffix: ""), .muted])
        XCTAssertEqual(strummed.summary(spelling: .sharps), "4 chords. C ✕ G ✕")
        XCTAssertFalse(PieceNotes(labels: [.muted, .muted]).countsChords, "no chord, nothing to count in chords")
    }

    func testChucksDontMoveAPartOutOfTheMapsChordsLayer() {
        let piece = PieceTranscription(taps: [.init(seconds: 1, label: .chord(root: 0, suffix: "")),
                                              .init(seconds: 2, label: .muted(strings: [3, 4, 5]))],
                                       openMidi: guitar)
        let loop = SongMapInput.LoopInput(uid: UUID(), name: "Verse", start: 0, end: 4, type: .unset, piece: piece,
                                          handTagged: false)
        XCTAssertEqual(SongMapLayout.layer(of: loop), .chords)
    }

    // MARK: - By ear (D3)

    func testMutedSavesAndMovesOn() {
        XCTAssertEqual(EarPick.muted(over: nil), .save(.muted, advance: true))
        XCTAssertEqual(EarPick.muted(over: .pitchClass(3)), .save(.muted, advance: true))
    }

    func testMutedAsksBeforeOverwritingANoteButKeepsTheNecksCrosses() {
        XCTAssertEqual(EarPick.muted(over: .fretted(string: 2, fret: 5)), .askToReplace(.muted))
        XCTAssertEqual(EarPick.muted(over: .muted(strings: [4])), .save(.muted(strings: [4]), advance: true))
    }

    func testAKindHasNothingToChangeOnADeadNote() {
        XCTAssertEqual(EarPick.kind(.chord(suffix: "m"), over: .muted, openMidi: guitar), .none)
        XCTAssertNil(EarKind(namedAs: .muted))
    }

    // MARK: - On the strip, the neck and aloud

    func testAChipSaysACrossByItsString() {
        let mixed = PieceLabel.fretted([note(3, 5), note(2, 5)], muted: [4], into: nil)
        XCTAssertEqual(NamingStrip.chipText(mixed, onTheNeck: true, openMidi: guitar, spelling: .sharps).text,
                       "A✕·D5·G5")
        let chuck = PieceLabel.muted(strings: [2, 3, 4, 5])
        XCTAssertEqual(NamingStrip.chipText(chuck, onTheNeck: true, openMidi: guitar, spelling: .sharps).text, "✕",
                       "four ✕s don't fit a chip")
        let byEar = NamingStrip.chipText(.muted(strings: [4]), onTheNeck: false, openMidi: guitar, spelling: .sharps)
        XCTAssertEqual(byEar.text, "✕")
        XCTAssertFalse(byEar.dim, "By ear reads it as muted")
    }

    func testTheNeighboursDrawTheNearestCrossOnAString() {
        let labels: [PieceLabel?] = [.muted(strings: [4]), .fretted(string: 2, fret: 5), .muted(strings: [4, 5])]
        let marks = NeckNeighbours.mutes(labels, active: 1)
        XCTAssertEqual(marks[4], NeckNeighbours.Mark(tier: .before(1), note: 0), "one behind beats one ahead")
        XCTAssertEqual(marks[5], NeckNeighbours.Mark(tier: .after(1), note: 2))
        XCTAssertNil(marks[2])
    }

    func testWatchingSaysAMutedTapInWords() {
        let labels: [PieceLabel?] = [.muted(strings: [4]), .muted(strings: [3, 4, 5]), .muted]
        let words = labels.indices.map { PieceNeck.words(for: $0, of: labels, openMidi: guitar, spelling: .sharps) }
        XCTAssertEqual(words, ["A string, muted", "Muted, 3 strings", "Muted, named by ear"])
        XCTAssertEqual(PieceNeck.heardMutes(1, of: labels), [3, 4, 5])
        XCTAssertEqual(PieceNeck.mutedStrings(of: labels), [3, 4, 5])
    }

    func testVoiceOverSaysMuted() {
        XCTAssertEqual(PieceLabel.spoken("A✕·D5"), "A muted·D5")
        XCTAssertEqual(PieceLabel.spoken("✕"), "muted")
    }

    func testANewInstrumentClearsCrossesAsItClearsFrets() {
        let guitarTuning = NamingTuning(openMidi: guitar, label: "Guitar · Standard")
        let bass = NamingTuning(openMidi: Instrument.bass.standardTuning.engineOpenMidi, label: "Bass · Standard")
        XCTAssertEqual(guitarTuning.carrying([.muted(strings: [5]), .muted], to: bass), [nil, .muted])
    }
}
