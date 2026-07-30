import SwiftData
import XCTest
@testable import Pocket

/// `NewExercisePlan.finalise(in:)` — the **one** insert path both hosts of `NewExerciseSheet` run:
/// Practice's `+` and the metronome automator's "Save as exercise" seam.
///
/// Worth its own file because of how this seam fails. The sheet was always shared but the insert
/// wasn't, so each host wrote its own — and a field the plan gained could simply go unread on one of
/// them. That is invisible three ways over: ignoring a struct field is legal Swift (the compiler
/// flags a struct's missing *writers*, never its missing *readers*), the shared form still renders
/// the control so the feature looks present, and nobody exercises the automator path by hand. The
/// song link shipped in exactly that state. These tests cover the shared function, so they now stand
/// for both hosts at once — which is the whole point of collapsing the two inserts into one.
///
/// Uses a real in-memory `ModelContainer` rather than bare `@Model` objects because half of what
/// `finalise` does is ordering that only a context can show: `linkedSongs` is a relationship, and
/// assigning it before the insert is a silent no-op.
@MainActor
final class ExercisePlanFinaliseTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // The insert emits `exerciseCreated` (ADR 0120); pin consent off so a unit run can never
        // reach a sink, whatever the host app's stored setting happens to be.
        Analytics.consentGranted = { false }
    }

    override func tearDown() {
        Analytics.consentGranted = { AppSettings.analyticsEnabled }
        super.tearDown()
    }

    /// The ADR 0111 regression, pinned once for both hosts: songs picked on the create sheet reach
    /// the stored drill. Previously true of the library and quietly false of the automator.
    func testPickedSongsLinkToTheCreatedExercise() throws {
        let context = try makeContext()
        let song = makeSong("Little Wing")
        context.insert(song)
        try context.save()

        let exercise = try XCTUnwrap(makePlan(name: "Thumb-over changes", songs: [song])
            .finalise(in: context))
        try context.save()

        XCTAssertEqual(exercise.linkedSongs.map(\.title), ["Little Wing"])
        let stored = try XCTUnwrap(context.fetch(FetchDescriptor<Song>()).first)
        XCTAssertEqual(stored.linkedExercises.map(\.name), ["Thumb-over changes"],
                       "the inverse populates, so the song's repertoire view shows the new drill")
    }

    /// The instrument axis (ADR 0116) rides onto the exercise. The automator used to read
    /// `plan.instrument` for its analytics event and drop it on the floor for the model, so a bass
    /// player's breakdown was saved as a guitar drill.
    func testInstrumentRidesOntoTheCreatedExercise() throws {
        let context = try makeContext()

        let exercise = try XCTUnwrap(makePlan(name: "Bass run", instrument: .bass).finalise(in: context))

        XCTAssertEqual(exercise.instrument, .bass)
    }

    /// The command is anchored on the entered tempo (ADR 0046) and bound to the rhythm the authored
    /// content states (ADR 0121) — the bind runs *after* the payload is encoded, or there is no
    /// rhythm to read yet.
    func testAuthoredPayloadIsEncodedAndTheCommandBindsToItsRhythm() throws {
        let context = try makeContext()
        let eighths = StrumPattern(slotsPerBeat: 2, slots: [.down, .up, .down, .up])

        let exercise = try XCTUnwrap(makePlan(name: "Folk strum", command: 96,
                                              template: .strumming, strum: eighths)
            .finalise(in: context))

        XCTAssertEqual(exercise.strumPattern, eighths)
        XCTAssertEqual(exercise.commandTempo, 96)
        XCTAssertEqual(exercise.commandNoteRate?.perBeat, 2,
                       "the command is measured at the pattern's rhythm, not left unstated")
    }

    /// A nameless plan creates nothing at all — the guard lives on the shared path so it can't be
    /// one host's private belt-and-braces.
    func testAnEmptyNameCreatesNothing() throws {
        let context = try makeContext()

        XCTAssertNil(makePlan(name: "").finalise(in: context))

        XCTAssertTrue(try context.fetch(FetchDescriptor<Exercise>()).isEmpty)
    }

    // MARK: - Helpers

    private func makePlan(name: String,
                          command: Int = 90,
                          template: ExerciseTemplate = .basic,
                          instrument: Instrument = .guitar,
                          strum: StrumPattern? = nil,
                          songs: [Song] = []) -> NewExercisePlan {
        NewExercisePlan(name: name, command: command, signature: .standard, template: template,
                        instrument: instrument, strum: strum, fretboard: nil, chords: nil,
                        strumChords: nil, songs: songs)
    }

    private func makeSong(_ title: String) -> Song {
        Song(title: title, duration: 100, ref: SongRef(id: title, source: .localFile, bookmark: nil))
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, configurations: config)
        return ModelContext(container)
    }
}
