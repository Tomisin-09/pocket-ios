import XCTest
@testable import Pocket

/// A Legato drill's **hammer-ons and pull-offs, worked out** (ADR 0251): the pure rule over a drill, the
/// template that decides who articulates, the figure a Legato drill opens on, and the seeded drill. The
/// rule is the one Name the notes joins taps by (ADR 0227 D5), so these pin it against a drill's slots.
final class LegatoJoinsTests: XCTestCase {

    private func note(_ string: Int, _ fret: Int, _ technique: FretTechnique? = nil) -> FretNote {
        FretNote(string: string, fret: fret, technique: technique)
    }

    private func techniques(_ drill: FretboardDrill) -> [FretTechnique?] {
        drill.notes.map { $0?.technique }
    }

    // MARK: - The rule

    func testUpAStringIsAHammerOnAndDownIsAPullOff() {
        let drill = FretboardDrill(notesPerBeat: 4, notes: [note(3, 5), note(3, 7), note(3, 8), note(3, 7)])
        XCTAssertEqual(techniques(drill.withLegatoJoins()), [nil, .hammerOn, .hammerOn, .pullOff])
    }

    func testAStringChangeIsPicked() {
        let drill = FretboardDrill(notesPerBeat: 2, notes: [note(4, 5), note(4, 7), note(3, 5), note(3, 7)])
        XCTAssertEqual(techniques(drill.withLegatoJoins()), [nil, .hammerOn, nil, .hammerOn],
                       "the first note on each string is picked")
    }

    func testARestBreaksTheChain() {
        let drill = FretboardDrill(notesPerBeat: 2, notes: [note(3, 5), nil, note(3, 7)])
        XCTAssertEqual(techniques(drill.withLegatoJoins()), [nil, nil, nil],
                       "a note after a rest is picked: there's nothing sounding to hammer from")
    }

    func testARepeatedFretIsPicked() {
        let drill = FretboardDrill(notesPerBeat: 2, notes: [note(3, 5), note(3, 5)])
        XCTAssertEqual(techniques(drill.withLegatoJoins()), [nil, nil])
    }

    func testTheFirstNoteIsPickedEvenWhenTheLoopWrapsIntoIt() {
        // The cycle ends on the same string below the first note: a pull-off *across the wrap* would
        // read as a hammer-on into note 0. Every loop starts with a pick instead.
        let drill = FretboardDrill(notesPerBeat: 2, notes: [note(3, 7), note(3, 5)])
        XCTAssertEqual(techniques(drill.withLegatoJoins()), [nil, .pullOff])
    }

    func testAnExistingSlideIsKept() {
        // A climbing run's seam (ADR 0083) is a slide; a legato reading doesn't overrule how it's played.
        let drill = FretboardDrill(notesPerBeat: 2, notes: [note(5, 3), note(5, 5, .slide), note(5, 7)])
        XCTAssertEqual(techniques(drill.withLegatoJoins()), [nil, .slide, .hammerOn])
    }

    func testTheRuleIsIdempotent() {
        let drill = FretboardRun.hammerOnPullOff.expanded().withLegatoJoins()
        XCTAssertEqual(drill.withLegatoJoins(), drill)
    }

    func testTheTransientRenderFieldsSurvive() {
        // Pass focus reads `noteGroups`; the labels read `openMidi` and `keySpelling`. None is encoded,
        // so dropping one here would be invisible to every persistence test.
        let drill = FretboardDrill(notesPerBeat: 2, notes: [note(3, 5), note(3, 7)], stringCount: 4,
                                   rootPitchClass: 9, noteGroups: [0, 1],
                                   openMidi: Instrument.bass.engineOpenMidi, keySpelling: .flats)
        let joined = drill.withLegatoJoins()
        XCTAssertEqual(joined.noteGroups, [0, 1])
        XCTAssertEqual(joined.openMidi, Instrument.bass.engineOpenMidi)
        XCTAssertEqual(joined.keySpelling, .flats)
        XCTAssertEqual(joined.rootPitchClass, 9)
        XCTAssertEqual(joined.stringCount, 4)
        XCTAssertEqual(joined.notesPerBeat, 2)
    }

    // MARK: - Who articulates

    func testOnlyLegatoArticulates() {
        let drill = FretboardRun.chromaticWarmup.expanded()
        XCTAssertNotEqual(ExerciseTemplate.legato.articulating(drill), drill)
        for template in ExerciseTemplate.allCases where template != .legato {
            XCTAssertEqual(template.articulating(drill), drill, "\(template) plays its drill as it stands")
        }
    }

    func testALegatoExerciseReadsItsJoinsAndTheSameContentUnderWarmUpDoesNot() {
        let content = FretboardContent.run(.chromaticWarmup)
        let legato = Exercise(name: "Legato", template: .legato)
        legato.setFretboardContent(content)
        let warmup = Exercise(name: "Warm-up", template: .warmup)
        warmup.setFretboardContent(content)

        XCTAssertTrue(legato.fretboardDrill?.notes.contains { $0?.technique == .hammerOn } ?? false)
        XCTAssertTrue(legato.fretboardDrill?.notes.contains { $0?.technique == .pullOff } ?? false)
        XCTAssertEqual(warmup.fretboardDrill, content.drill, "a warm-up stays picked")
    }

    func testADrawnLegatoDrillReadsItsJoinsToo() {
        let drawn = FretboardDrill(notesPerBeat: 2, notes: [note(2, 5), note(2, 7), nil, nil])
        let legato = Exercise(name: "Drawn", template: .legato)
        legato.setFretboardContent(.custom(drawn))
        XCTAssertEqual(legato.fretboardDrill.map(techniques), [nil, .hammerOn, nil, nil])
    }

    // MARK: - The figure a Legato drill opens on

    func testTheFigureIsPickHammerHammerPullOnEveryStringAndEachStringIsABar() {
        let drill = ExerciseTemplate.legato.articulating(FretboardRun.hammerOnPullOff.expanded())
        XCTAssertEqual(drill.noteCount, 44, "24 up, 20 back")
        XCTAssertEqual(drill.notesPerBeat, 1, "quarters, so the cues can be followed")
        XCTAssertEqual(drill.lengthInBeats, 44, "eleven bars of 4/4, one string each")
        for start in stride(from: 0, to: drill.noteCount, by: 4) {
            let group = Array(drill.notes[start..<start + 4])
            XCTAssertEqual(group.map { $0?.fret }, [5, 6, 8, 6], "string group at \(start)")
            XCTAssertEqual(Set(group.map { $0?.string }).count, 1, "one string per bar, at \(start)")
            XCTAssertEqual(group.map { $0?.technique }, [nil, .hammerOn, .hammerOn, .pullOff],
                           "pick, hammer, hammer, pull at \(start)")
        }
    }

    func testTheFigureOnBassStaysOnTheFourStrings() {
        let drill = FretboardRun.hammerOnPullOff.expanded(instrument: .bass)
        XCTAssertEqual(drill.stringCount, 4)
        XCTAssertTrue(drill.notes.allSatisfy { ($0?.string ?? 0) < 4 })
    }

    func testANewLegatoDrillOpensOnTheFigureAndTheOtherRunFamiliesDoNot() {
        XCTAssertEqual(ExerciseTemplate.legato.defaultFretboardContent, .run(.hammerOnPullOff))
        XCTAssertEqual(ExerciseTemplate.legato.starterRun, .hammerOnPullOff)
        for template in [ExerciseTemplate.warmup, .picking, .fingerstyle] {
            XCTAssertEqual(template.starterRun, .chromaticWarmup, "\(template)")
        }
        // A template with no run at all still gives the editor something to start from.
        XCTAssertEqual(ExerciseTemplate.basic.starterRun, .chromaticWarmup)
    }

    // MARK: - The seeded drill

    func testTheSeededLegatoDrillShipsTheFigureInQuarters() throws {
        let spec = try XCTUnwrap(PracticePresets.allSpecs.first { $0.slug == "legato" })
        XCTAssertEqual(spec.fretboard, .run(.hammerOnPullOff))
        XCTAssertNil(spec.noteRate, "the payload states the rate (ADR 0121)")
        XCTAssertTrue(PracticePresets.firstRunSlugs.contains("legato"), "still in the first-run set")

        let exercise = try XCTUnwrap(PracticePresets.makeExercises([spec]).first)
        XCTAssertEqual(exercise.noteRate?.perBeat, 1, "quarters — the payload's rate, not the old spec's")
        XCTAssertEqual(exercise.commandNotesPerBeat, 1, "the command binds to the content's rhythm")
        XCTAssertTrue(exercise.fretboardDrill?.notes.contains { $0?.technique == .hammerOn } ?? false)
    }

    // MARK: - The board's letters

    func testTheCueSpellsAJoinTheWayTheTabDoes() {
        XCTAssertEqual(LegatoCue.letter(for: .hammerOn), "h")
        XCTAssertEqual(LegatoCue.letter(for: .pullOff), "p")
        XCTAssertNil(LegatoCue.letter(for: .slide))
        XCTAssertNil(LegatoCue.letter(for: .pick))
    }
}
