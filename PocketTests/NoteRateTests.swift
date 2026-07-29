import XCTest
@testable import Pocket

/// `NoteRate` + the `Exercise.noteRate` resolution (device pass 2026-07-29). The arithmetic and the
/// **precedence between the two note-rate axes** are exactly the logic that would otherwise break
/// silently — a wrong rate produces a plausible-looking label and a wrong sort, with nothing to
/// notice it — so both are covered here. The `@Model` is exercised as a plain in-memory object, never
/// inserted (`ExerciseTests`' discipline).
final class NoteRateTests: XCTestCase {

    // MARK: - The value type

    func testPerBeatIsClampedToAtLeastOne() {
        XCTAssertEqual(NoteRate(perBeat: 0).perBeat, 1)
        XCTAssertEqual(NoteRate(perBeat: -4).perBeat, 1)
    }

    func testLabelsMatchTheRhythmDropdownVocabulary() {
        XCTAssertEqual(NoteRate.quarters.label, "Quarters")
        XCTAssertEqual(NoteRate.eighths.label, "Eighths")
        XCTAssertEqual(NoteRate.triplets.label, "Triplets")
        XCTAssertEqual(NoteRate.sixteenths.label, "Sixteenths")
    }

    /// A rate outside the authored table describes itself rather than being rounded into one of the
    /// four — the label must never claim a rhythm the content isn't in.
    func testUnknownRateDescribesItself() {
        XCTAssertEqual(NoteRate(perBeat: 6).label, "6 per beat")
        XCTAssertEqual(NoteRate(perBeat: 6).compactLabel, "6/beat")
    }

    func testCompactLabelsAreTheTrailingForm() {
        XCTAssertEqual(NoteRate.quarters.compactLabel, "quarters")
        XCTAssertEqual(NoteRate.eighths.compactLabel, "8ths")
        XCTAssertEqual(NoteRate.sixteenths.compactLabel, "16ths")
    }

    func testNotesPerMinuteIsTempoTimesRate() {
        XCTAssertEqual(NoteRate.sixteenths.notesPerMinute(atBPM: 80), 320)
        XCTAssertEqual(NoteRate.quarters.notesPerMinute(atBPM: 70), 70)
        // Triplets at 80 and sixteenths at 60 are both 240 — the same note speed, deliberately *not*
        // a claim that they are equally hard (the scope decision on the type).
        XCTAssertEqual(NoteRate.triplets.notesPerMinute(atBPM: 80), 240)
        XCTAssertEqual(NoteRate.sixteenths.notesPerMinute(atBPM: 60), 240)
    }

    func testNotesPerMinuteNeverGoesNegative() {
        XCTAssertEqual(NoteRate.eighths.notesPerMinute(atBPM: -20), 0)
    }

    // MARK: - Resolution on an exercise

    /// The content's rate wins over the click: the Rhythm dropdown is what the player moves, and it's
    /// what the notes are actually played at.
    func testContentRateWinsOverTheClickSubdivision() {
        let exercise = Exercise(subdivision: .none, template: .scales)
        exercise.setFretboardContent(.custom(FretboardDrill(notesPerBeat: 4, notes: [nil, nil, nil, nil])))
        XCTAssertEqual(exercise.noteRate, .sixteenths)
        XCTAssertEqual(exercise.commandNotesPerMinute, exercise.command * 4)
    }

    /// The seeded *Spider Walk* shape: a metronome-rendered warm-up whose only stated rhythm is the
    /// click subdivision.
    func testClickSubdivisionIsTheFallbackWhenContentDeclaresNoRate() {
        let exercise = Exercise(commandTempo: 80, subdivision: .sixteenths, template: .warmup)
        XCTAssertNil(exercise.contentNoteRate)
        XCTAssertEqual(exercise.noteRate, .sixteenths)
        XCTAssertEqual(exercise.commandNotesPerMinute, 320)
    }

    /// The seeded *Chord Changes* shape: nothing declares a rhythm, so the rate is unknown rather
    /// than silently "quarters" — that's what keeps the row from labelling a fact it doesn't have.
    func testNoDeclaredRhythmResolvesToNil() {
        let exercise = Exercise(commandTempo: 70, subdivision: .none, template: .chords)
        XCTAssertNil(exercise.noteRate)
        XCTAssertEqual(exercise.commandNotesPerMinute, 70, "an unknown rhythm still compares as bare BPM")
    }

    func testStrumPatternSlotsPerBeatIsTheRate() {
        let exercise = Exercise(template: .strumming)
        exercise.setStrumPattern(.folk)
        XCTAssertEqual(exercise.noteRate, NoteRate(perBeat: StrumPattern.folk.slotsPerBeat))
    }

    func testStrumChordSheetTakesItsRateFromTheGroove() {
        let exercise = Exercise(template: .strumChords)
        exercise.setStrumChordSheet(.popGroove)
        XCTAssertEqual(exercise.noteRate,
                       NoteRate(perBeat: StrumChordSheet.popGroove.strumPattern.slotsPerBeat))
    }

    /// A fretboard-template exercise carrying no payload falls all the way through to the click, the
    /// same as any other rhythm-less drill — the payload accessors return `nil`, not a default rate.
    func testFretboardTemplateWithNoPayloadFallsBackToTheClick() {
        let exercise = Exercise(subdivision: .triplets, template: .scales)
        XCTAssertNil(exercise.contentNoteRate)
        XCTAssertEqual(exercise.noteRate, .triplets)
    }

    // MARK: - The shared row label

    func testCommandProgressLabelCarriesTheRhythm() {
        let exercise = Exercise(commandTempo: 80, subdivision: .sixteenths, template: .warmup)
        XCTAssertEqual(exercise.commandProgressLabel,
                       "Command 80 → \(exercise.reachTempo) BPM · 16ths")
    }

    func testCommandProgressLabelOmitsAnUndeclaredRhythm() {
        let exercise = Exercise(commandTempo: 70, subdivision: .none, template: .chords)
        XCTAssertEqual(exercise.commandProgressLabel, "Command 70 → \(exercise.reachTempo) BPM")
    }
}
