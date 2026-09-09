@testable import Pocket
import XCTest

/// A drill handed over on its own (ADR 0209) — what the file carries, what it refuses, and what
/// lands.
///
/// Structured as one class rather than the routine door's two because there is far less of it: a
/// drill has no blocks to order, no placeholders and no join keys, which is most of what the routine
/// tests exist to pin down.
///
/// Everything here is pure over values. `materialize` returns **uninserted** models for the reason
/// `docs/swiftdata-gotchas.md` gives — inserting a graph inside the XCTest host traps — so no test
/// below needs a `ModelContext`.
@MainActor
final class ReceivedExerciseTests: XCTestCase {

    private typealias Fixture = ReceivedRoutineFixture

    private static let fixedDate = Date(timeIntervalSince1970: 1_725_000_000.123)

    /// A drill with something in every field a share is supposed to keep, and something in the ones
    /// it is supposed to drop — so a test that asserts a drop cannot pass by the field being empty
    /// on both sides.
    private func drill() -> Exercise {
        let exercise = Exercise(name: "Spider Walk", currentTempo: 62, targetTempo: 120,
                                beatsPerBar: 3, noteValue: 4, subdivision: .eighths,
                                notesPerBeat: 2, rampStepBPM: 4,
                                tags: ["warm-up", "left hand"], notes: "One finger per fret.")
        exercise.targetTempoOverride = 108
        // The sender's own practice, none of which may cross (ADR 0188 D5).
        exercise.mastery = 4
        exercise.masteryTempo = 96
        exercise.commandTempo = 88
        exercise.commandNotesPerBeat = 2
        exercise.lastPracticed = Self.fixedDate
        exercise.isFavorite = true
        exercise.presetSlug = "seeded-spider"
        // A real link, so the assertion that it does not cross is about a subtraction rather than
        // about an array that was empty all along. The record derives `linkedSongIDs` from this
        // relationship (`ArchiveBuilder+Units`), and the song is a file on the sender's phone.
        exercise.linkedSongs = [Song(title: "Slow Bend", duration: 100,
                                     ref: SongRef(id: "slow-bend", source: .localFile,
                                                  bookmark: nil))]
        return exercise
    }

    private func shared(_ exercise: Exercise, notes: String? = nil) -> SharedPractice {
        SharedPracticeBuilder.exercise(exercise, appVersion: "1.2 (7)", notes: notes,
                                       exportedAt: Self.fixedDate)
    }

    private func received(_ payload: SharedPractice) throws -> ReceivedExercise {
        switch try ReceivedPracticeBuilder.evaluate(data: ArchiveCoding.encode(payload)).get() {
        case let .exercise(value): return value
        case let .routine(value): throw Fixture.UnexpectedKind(name: value.displayName)
        }
    }

    // MARK: - What the file says it is (D1)

    /// The header, and the whole compatibility story in two assertions: the kind names the drill, and
    /// the version is **unchanged**. Bumping it would make routine files written by this build
    /// unreadable on every build already in the wild, for a change that altered no record.
    func testAnExerciseShareNamesItsKindAndLeavesTheSchemaVersionAlone() {
        let payload = shared(drill())

        XCTAssertEqual(payload.kind, .exercise)
        XCTAssertEqual(payload.kindRaw, "exercise")
        XCTAssertEqual(payload.schemaVersion, PracticeArchive.currentSchemaVersion,
                       "A new payload kind must not move the record-shape version")
        XCTAssertNil(payload.routine, "An exercise share carries no sitting around the drill")
        XCTAssertEqual(payload.exercises.count, 1)
        XCTAssertTrue(payload.placeholders.isEmpty)
    }

    /// The drill's shape crosses; the sender's achievement does not. The same subtractions the
    /// routine door already makes, asserted here because this file is reached by a different call.
    func testTheShapeCrossesAndThePracticeDoesNot() throws {
        let record = try XCTUnwrap(shared(drill()).exercises.first)

        XCTAssertEqual(record.name, "Spider Walk")
        XCTAssertEqual(record.currentTempo, 62)
        XCTAssertEqual(record.targetTempo, 120)
        XCTAssertEqual(record.targetTempoOverride, 108, "A pinned reach is a goal, not a measurement")
        XCTAssertEqual(record.beatsPerBar, 3)
        XCTAssertEqual(record.rampStepBPM, 4)
        // Sorted, because `ArchiveBuilder.exerciseRecord` sorts them — a stable file is one two people
        // can diff, which is the same reason the exercises themselves come out in a fixed order.
        XCTAssertEqual(record.tags, ["left hand", "warm-up"])

        XCTAssertNil(record.mastery)
        XCTAssertNil(record.masteryTempo)
        XCTAssertNil(record.commandTempo)
        XCTAssertNil(record.commandNotesPerBeat)
        XCTAssertNil(record.lastPracticed)
        XCTAssertNil(record.presetSlug)
        XCTAssertFalse(record.isFavorite)
        XCTAssertTrue(record.linkedSongIDs.isEmpty)
        XCTAssertTrue(record.references.isEmpty)
    }

    /// The description is `@State` on the sending sheet until Done (ADR 0209 D3). A drill shared while
    /// an edit sits uncommitted must carry the words on screen — otherwise the file quietly holds the
    /// description the sender just replaced, and nothing about it looks wrong.
    func testAnUncommittedDescriptionIsWhatCrosses() throws {
        let record = try XCTUnwrap(shared(drill(), notes: "Stop the moment it buzzes.").exercises.first)

        XCTAssertEqual(record.notes, "Stop the moment it buzzes.")
    }

    /// And with nothing passed, the model's own description — the shape every caller but the sheet
    /// uses.
    func testWithNoOverrideTheModelsDescriptionCrosses() throws {
        let record = try XCTUnwrap(shared(drill()).exercises.first)

        XCTAssertEqual(record.notes, "One finger per fret.")
    }

    // MARK: - Refusals (D4)

    func testAFileThatNamesAnExerciseAndCarriesNoneIsReportedAsIncomplete() throws {
        var payload = shared(drill())
        payload.exercises = []

        XCTAssertEqual(try Fixture.failure(of: try ArchiveCoding.encode(payload)),
                       .incomplete(.exercise))
    }

    /// The version gate runs before the kind, so a drill from a later build is reported as being from
    /// the future rather than as an unknown payload. Both are true; the version is the one the player
    /// can act on.
    func testAnExerciseFromALaterBuildIsRefusedOnItsVersion() throws {
        var payload = shared(drill())
        payload.schemaVersion = SharedPractice.currentSchemaVersion + 1

        XCTAssertEqual(try Fixture.failure(of: try ArchiveCoding.encode(payload)),
                       .futureVersion(message: SchemaVersionGate.refusalMessage))
    }

    /// A file naming two drills is read, not refused. This is the untrusted door: the header says
    /// exercise and the first one is plainly what was meant, so a `count == 1` check would refuse a
    /// perfectly openable file to no one's benefit.
    func testAFileCarryingMoreThanOneDrillTakesTheFirst() throws {
        var payload = shared(drill())
        payload.exercises.append(SharedPracticeBuilder.shareable(Exercise(name: "Second")))

        XCTAssertEqual(try received(payload).displayName, "Spider Walk")
    }

    // MARK: - The preview (D6)

    func testThePreviewReadsTheDrillTheFileHolds() throws {
        let value = try received(shared(drill()))

        XCTAssertEqual(value.displayName, "Spider Walk")
        XCTAssertEqual(value.feel, "3/4 · Eighths")
        XCTAssertEqual(value.tempoPlan, "62 → 108 BPM", "The pinned reach wins over the target")
        XCTAssertEqual(value.appVersion, "1.2 (7)")
        // A fixture date with a **real fractional part**, which is what makes this assertion mean
        // anything: the routine door's equivalent uses a whole second, so it would pass with the
        // fractional-seconds strategy removed entirely.
        //
        // Asserted with tolerance rather than for equality, because the round trip is **not** exact.
        // `ArchiveCoding` writes ISO-8601 to three decimal places and the formatter *truncates*:
        // .123 comes back .122. That is fine for what these dates are — `exportedAt` is shown to the
        // reader, and no comparison anywhere depends on a sub-millisecond edge — but it is a
        // millisecond, not zero, and a test that claimed otherwise would be wrong rather than strict.
        XCTAssertEqual(value.exportedAt.timeIntervalSince1970,
                       Self.fixedDate.timeIntervalSince1970, accuracy: 0.002,
                       "Fractional seconds survive the round trip, to within a millisecond")
    }

    /// An unnamed drill gets a name rather than an empty heading — the same fallback the routine
    /// preview makes, because a drill can legitimately be saved unnamed too.
    func testAnUnnamedDrillStillHasSomethingToCallIt() throws {
        let value = try received(shared(Exercise(name: "   ")))

        XCTAssertEqual(value.displayName, "Practice exercise")
    }

    /// A template this build cannot name draws **nothing** rather than a wrong chip. The confirmation
    /// screen is the last place that should tell the player something untrue about the file — and the
    /// raw value still survives into the model, for a build that understands it.
    func testATemplateThisBuildCannotNameIsNotGuessedAt() throws {
        var payload = shared(drill())
        payload.exercises[0].templateRaw = "hologram"

        let value = try received(payload)

        XCTAssertNil(value.template)
        XCTAssertEqual(ReceivedPracticeBuilder.materialize(value).exercise.templateRaw, "hologram",
                       "The raw column survives verbatim for a build that knows it")
    }

    // MARK: - What lands (D4)

    func testTheDrillThatLandsIsTheShapeWithNoneOfTheHistory() throws {
        let landing = ReceivedPracticeBuilder.materialize(try received(shared(drill())))

        XCTAssertEqual(landing.exercise.name, "Spider Walk")
        XCTAssertEqual(landing.exercise.currentTempo, 62)
        XCTAssertEqual(landing.exercise.targetTempoOverride, 108)
        XCTAssertEqual(landing.exercise.beatsPerBar, 3)
        XCTAssertEqual(landing.exercise.notes, "One finger per fret.")
        XCTAssertNil(landing.exercise.mastery)
        XCTAssertNil(landing.exercise.commandTempo)
        XCTAssertNil(landing.exercise.lastPracticed)
        XCTAssertFalse(landing.exercise.isFavorite)
        XCTAssertTrue(landing.exercise.linkedSongs.isEmpty,
                      "The sender's songs are files on their phone — there is nothing to point at")
    }

    /// A received drill is a **new** row, never a claim on one of the sender's. The uid in the file is
    /// a join key inside that payload and means nothing here.
    func testTheLandedDrillMintsItsOwnIdentity() throws {
        let original = drill()
        let value = try received(shared(original))

        let landing = ReceivedPracticeBuilder.materialize(value)

        XCTAssertNotEqual(landing.exercise.uid, original.uid)
        XCTAssertNotEqual(landing.exercise.uid, value.exercise.uid)
    }

    /// Opening the same file twice produces two drills, on purpose — nothing about a received file
    /// updates anything already in the library.
    func testTheSameFileTwiceMakesTwoDrills() throws {
        let value = try received(shared(drill()))

        let first = ReceivedPracticeBuilder.materialize(value)
        let second = ReceivedPracticeBuilder.materialize(value)

        XCTAssertNotEqual(first.exercise.uid, second.exercise.uid)
    }

    /// The whole loop through the real encoder and the real decoder — the only test that would notice
    /// the sending and receiving halves disagreeing about the format.
    func testARealSharedFileRoundTripsBackIntoADrill() throws {
        let bytes = try ArchiveCoding.encode(shared(drill()))

        guard case let .success(.exercise(value)) = ReceivedPracticeBuilder.evaluate(data: bytes) else {
            return XCTFail("A file this app just wrote could not be read back as an exercise")
        }

        XCTAssertEqual(value.displayName, "Spider Walk")
        XCTAssertEqual(value.exportedAt.timeIntervalSince1970,
                       Self.fixedDate.timeIntervalSince1970, accuracy: 0.002)
    }

    /// The file name is derived from what the player called the drill, and an unnamed one says
    /// "exercise" rather than inheriting the routine door's "routine" — the file would otherwise lie
    /// about its contents before anybody opened it.
    func testAnUnnamedDrillsFileIsNotCalledARoutine() {
        XCTAssertEqual(SharedPracticeFile.fileName(for: "  ", fallback: "exercise"),
                       "exercise.redmoonpractice")
        XCTAssertEqual(SharedPracticeFile.fileName(for: "Spider Walk!!", fallback: "exercise"),
                       "Spider-Walk.redmoonpractice")
    }
}
