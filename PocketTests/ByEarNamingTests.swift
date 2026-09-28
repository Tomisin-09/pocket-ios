import XCTest
@testable import Pocket

/// Naming by ear (ADR 0227 D6, D7): the kinds grouped by how many notes they hold, the one-way read of a
/// placed note, what a tap on a name or a kind does, which sheet opens, and the strip's next gap.
final class ByEarNamingTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi   // [64, 59, 55, 50, 45, 40]

    // MARK: - Kinds

    func testTheKindsAreGroupedByHowManyNotesTheyHold() {
        XCTAssertEqual(EarKind.groups.map(\.title), ["One note", "Two notes", "Three notes", "Four or more"])
        XCTAssertEqual(EarKind.groups[0].kinds, [.note])
        XCTAssertEqual(EarKind.groups[1].kinds, [.chord(suffix: "5")])
        XCTAssertEqual(EarKind.groups[2].kinds.map(\.title), ["maj", "m", "sus4", "sus2", "dim", "aug"])
        XCTAssertEqual(EarKind.groups[3].kinds.first, .chord(suffix: "7"), "the commonest seventh leads")
    }

    func testEveryQualityIsOfferedExactlyOnce() {
        let offered = EarKind.groups.flatMap(\.kinds).compactMap { kind -> String? in
            if case .chord(let suffix) = kind { return suffix }
            return nil
        }
        XCTAssertEqual(offered.count, Set(offered).count, "no suffix twice, though the catalog lists each 9th twice")
        XCTAssertEqual(Set(offered), Set(PieceLabel.chordQualities.map(\.suffix)), "and none left out")
    }

    func testAKindMakesItsAnswer() {
        XCTAssertEqual(EarKind.note.label(root: 4), .pitchClass(4))
        XCTAssertEqual(EarKind.chord(suffix: "m7").label(root: 9), .chord(root: 9, suffix: "m7"))
        XCTAssertEqual(EarKind(namedAs: .chord(root: 9, suffix: "")), .chord(suffix: ""))
        XCTAssertEqual(EarKind(namedAs: .pitchClass(2)), .note)
        XCTAssertNil(EarKind(namedAs: .fretted(string: 0, fret: 3)), "a placed note is read, never named")
    }

    // MARK: - Reading a placed note

    func testAPlacedNoteReadsAsTheNoteItSounds() {
        XCTAssertEqual(PieceLabel.fretted(string: 2, fret: 2).earReading(openMidi: guitar),
                       EarReading(root: 9, kind: .note))   // A on the G string
        XCTAssertNil(PieceLabel.fretted(string: 7, fret: 2).earReading(openMidi: guitar), "past the strings")
        XCTAssertEqual(PieceLabel.chord(root: 2, suffix: "7").earReading(openMidi: guitar),
                       EarReading(root: 2, kind: .chord(suffix: "7")))
    }

    // MARK: - Tapping a name

    func testANameSavesAndMovesOn() {
        XCTAssertEqual(EarPick.name(9, as: .note, over: nil, openMidi: guitar),
                       .save(.pitchClass(9), advance: true))
        XCTAssertEqual(EarPick.name(9, as: .chord(suffix: "m"), over: .pitchClass(4), openMidi: guitar),
                       .save(.chord(root: 9, suffix: "m"), advance: true), "a name by ear just replaces")
    }

    func testANameOverNeckWorkAsksFirst() {
        let placed = PieceLabel.fretted(string: 2, fret: 2)   // reads as A
        XCTAssertEqual(EarPick.name(0, as: .chord(suffix: "m"), over: placed, openMidi: guitar),
                       .askToReplace(.chord(root: 0, suffix: "m")))
        XCTAssertEqual(EarPick.name(9, as: .chord(suffix: "m"), over: placed, openMidi: guitar),
                       .askToReplace(.chord(root: 9, suffix: "m")), "same root, another kind: still a replace")
    }

    func testPickingWhatTheNeckReadsKeepsTheNeck() {
        let placed = PieceLabel.fretted(string: 2, fret: 2)
        XCTAssertEqual(EarPick.name(9, as: .note, over: placed, openMidi: guitar), .save(placed, advance: true))
    }

    // MARK: - Tapping a kind

    func testAKindChangesTheAnswerWithoutMovingOn() {
        XCTAssertEqual(EarPick.kind(.chord(suffix: "m7"), over: .chord(root: 9, suffix: ""), openMidi: guitar),
                       .save(.chord(root: 9, suffix: "m7"), advance: false))
        XCTAssertEqual(EarPick.kind(.note, over: .chord(root: 9, suffix: "m"), openMidi: guitar),
                       .save(.pitchClass(9), advance: false))
    }

    func testAKindWithNothingToChangeDoesNothing() {
        XCTAssertEqual(EarPick.kind(.chord(suffix: "m"), over: nil, openMidi: guitar), .none, "an empty tap")
        XCTAssertEqual(EarPick.kind(.note, over: .pitchClass(3), openMidi: guitar), .none, "already that kind")
        XCTAssertEqual(EarPick.kind(.note, over: .fretted(string: 2, fret: 2), openMidi: guitar), .none,
                       "the neck already reads as one note")
    }

    func testAKindOverNeckWorkAsksFirst() {
        XCTAssertEqual(EarPick.kind(.chord(suffix: "m"), over: .fretted(string: 2, fret: 2), openMidi: guitar),
                       .askToReplace(.chord(root: 9, suffix: "m")))
    }

    // MARK: - Which sheet opens

    func testANewPassOpensOnTheNeckButAChordLoopOpensByEarOnMajor() {
        XCTAssertEqual(NamingMode.opening(for: [nil, nil], loopType: .lick), .fret)
        XCTAssertEqual(NamingMode.openingKind(for: [nil, nil], loopType: .lick), .note)
        XCTAssertEqual(NamingMode.opening(for: [nil, nil], loopType: .chords), .ear)
        XCTAssertEqual(NamingMode.openingKind(for: [nil, nil], loopType: .chords), .chord(suffix: ""))
    }

    func testANamedPieceOpensOnItsFirstAnswersSheet() {
        XCTAssertEqual(NamingMode.opening(for: [nil, .pitchClass(2)], loopType: .chords), .ear)
        XCTAssertEqual(NamingMode.opening(for: [nil, .fretted(string: 1, fret: 5), .chord(root: 0, suffix: "")],
                                          loopType: .chords), .fret)
        XCTAssertEqual(NamingMode.openingKind(for: [.fretted(string: 1, fret: 5), .chord(root: 0, suffix: "m7")],
                                              loopType: .lick), .chord(suffix: "m7"), "the first kind named by ear")
    }

    // MARK: - The strip

    func testNextUnnamedFindsTheNextGapAndWraps() {
        let labels: [PieceLabel?] = [nil, .pitchClass(1), nil, .pitchClass(3)]
        XCTAssertEqual(NamingStrip.nextUnnamed(after: 0, in: labels), 2)
        XCTAssertEqual(NamingStrip.nextUnnamed(after: 2, in: labels), 0, "wraps round to the start")
        XCTAssertEqual(NamingStrip.nextUnnamed(after: 3, in: labels), 0)
        XCTAssertEqual(NamingStrip.nextUnnamed(after: 1, in: [nil, .pitchClass(1)]), 0)
    }

    func testNextUnnamedIsNilOnceEveryOtherTapIsNamed() {
        XCTAssertNil(NamingStrip.nextUnnamed(after: 0, in: [.pitchClass(1), .pitchClass(2)]))
        XCTAssertNil(NamingStrip.nextUnnamed(after: 0, in: []))
        XCTAssertNil(NamingStrip.nextUnnamed(after: 0, in: [nil]), "the current tap is never next")
        XCTAssertNil(NamingStrip.nextUnnamed(after: 1, in: [.pitchClass(1), nil]))
    }
}
