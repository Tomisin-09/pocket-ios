import XCTest
@testable import Pocket

/// What crosses when a routine is handed to somebody else, and — more importantly — what does not
/// (ADR 0188 S1).
///
/// Every model here is built and left **uninserted**, the house rule for model tests in this host
/// (inserting traps) and the shape `SharedPracticeBuilder` is designed for: it reads plain models and
/// returns a plain value.
///
/// The assertions come in two kinds and both are needed. Value-tree checks say what the builder
/// produced; text checks say what reached the **file**, which is the thing that actually leaves the
/// device. A field can be dropped from one and survive in the other — that is the failure a share is
/// most likely to have, so the exclusions are asserted against the encoded bytes.
@MainActor
final class SharedPracticeTests: XCTestCase {

    // MARK: - Fixtures

    private func makeSong(title: String = "Slow Bend", sourceID: String = "song-1") -> Song {
        Song(title: title,
             artist: "Jack Trader",
             duration: 200,
             amplitudes: Array(repeating: 0.5, count: 512),
             ref: SongRef(id: sourceID, source: .localFile, bookmark: nil),
             audioFileName: "\(sourceID).wav")
    }

    /// Pinned, and to a whole second on purpose. The file carries dates to the **millisecond** (see
    /// `ArchiveCoding.dateStyle`), so a fixture built on `Date.now` — which has microsecond precision
    /// — cannot survive a round trip, and the round-trip test would fail on the format working
    /// exactly as designed.
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// An exercise carrying everything a sender has *earned* on it, so the drops have something to drop.
    private func makeExercise(named name: String = "Spider Walk") -> Exercise {
        let exercise = Exercise(name: name)
        exercise.dateAdded = fixedDate
        exercise.mastery = 4
        exercise.masteryTempo = 132
        exercise.masteryNotesPerBeat = 4
        exercise.commandTempo = 128
        exercise.commandNotesPerBeat = 4
        exercise.lastPracticed = Date(timeIntervalSince1970: 1_000)
        exercise.isFavorite = true
        exercise.presetSlug = "spider-walk"
        exercise.notes = "Keep the thumb behind the neck."
        return exercise
    }

    private func share(_ routine: Routine) -> SharedPractice {
        SharedPracticeBuilder.routine(routine,
                                      appVersion: "1.2 (5)",
                                      exportedAt: Date(timeIntervalSince1970: 0))
    }

    private func encodedJSON(_ payload: SharedPractice) throws -> String {
        try XCTUnwrap(String(bytes: ArchiveCoding.encode(payload), encoding: .utf8))
    }

    /// The pieces a test needs to reach back into after building the routine below.
    private struct Fixture {
        let routine: Routine
        let exercise: Exercise
        let loop: Loop
        let song: Song
    }

    /// A routine with one exercise block, one loop block, one song block and a rest — one of each thing
    /// the rules below have something to say about.
    private func makeRoutine() -> Fixture {
        let routine = Routine(name: "Morning warm-up", dateAdded: fixedDate)
        routine.notes = "The bits of week 3 that actually needed work."
        routine.lastPracticed = Date(timeIntervalSince1970: 2_000)
        routine.isFavorite = true
        routine.presetSlug = "morning-warm-up"

        let exercise = makeExercise()
        let song = makeSong()
        let loop = Loop(name: "Chorus", start: 10, end: 20, speed: 0.8, repeats: 4)
        loop.song = song

        routine.items = [RoutineItem.item(exercise, order: 0),
                         RoutineItem.item(loop, order: 1),
                         RoutineItem.item(song, order: 2),
                         RoutineItem.rest(order: 3)]
        return Fixture(routine: routine, exercise: exercise, loop: loop, song: song)
    }

    // MARK: - The shape crosses

    func testTheRoutineAndItsBlocksCross() {
        let routine = makeRoutine().routine

        let shared = share(routine)

        XCTAssertEqual(shared.kind, .routine)
        XCTAssertEqual(shared.schemaVersion, PracticeArchive.currentSchemaVersion,
                       "A share and an archive carry the same record shapes, so they share one version")
        XCTAssertEqual(shared.routine?.name, "Morning warm-up")
        XCTAssertEqual(shared.routine?.notes, "The bits of week 3 that actually needed work.")
        XCTAssertEqual(shared.routine?.items.count, 4, "Every block crossed, the rest included")
        XCTAssertEqual(shared.routine?.items.map(\.order), [0, 1, 2, 3])
    }

    /// A block points at its unit by live relationship and the archive invents ids at DTO time, so a
    /// file that only named uids would resolve to nothing on another device.
    func testAnExerciseTravelsInlineAndItsBlockStillPointsAtIt() throws {
        let fixture = makeRoutine()
        let routine = fixture.routine
        let exercise = fixture.exercise

        let shared = share(routine)

        XCTAssertEqual(shared.exercises.map(\.name), ["Spider Walk"])
        XCTAssertEqual(shared.exercises.first?.uid, exercise.uid)
        let block = try XCTUnwrap(shared.routine?.items.first { $0.exerciseUID != nil })
        XCTAssertEqual(block.exerciseUID, exercise.uid,
                       "The block's id is the join to the exercise carried in the same file")
    }

    /// The same drill used by three blocks is one entry in the file, not three.
    func testAnExerciseUsedTwiceIsWrittenOnce() {
        let routine = Routine(name: "Doubled", dateAdded: fixedDate)
        let exercise = makeExercise()
        routine.items = [RoutineItem.item(exercise, order: 0), RoutineItem.item(exercise, order: 1)]

        let shared = share(routine)

        XCTAssertEqual(shared.exercises.count, 1)
        XCTAssertEqual(shared.routine?.items.compactMap(\.exerciseUID), [exercise.uid, exercise.uid])
    }

    // MARK: - The sender's practice does not cross (D4)

    func testTheSendersOwnPracticeIsLeftBehind() throws {
        let routine = makeRoutine().routine

        let shared = share(routine)
        let record = try XCTUnwrap(shared.routine)

        XCTAssertNil(record.lastPracticed, "The receiver has not run this session")
        XCTAssertFalse(record.isFavorite, "A pin is about a row in a library that is not theirs")
        XCTAssertNil(record.presetSlug, "Provenance is where the sender's copy came from")
    }

    // MARK: - The sender's achievement does not cross (D5)

    /// Asserted against the encoded file, not the value tree: a number dropped from the struct and
    /// still present in the JSON is the failure that matters, and only this direction catches it.
    func testNoMeasuredNumberReachesTheFile() throws {
        let routine = makeRoutine().routine

        let shared = share(routine)
        let record = try XCTUnwrap(shared.exercises.first)
        let json = try encodedJSON(shared)

        // Positive control. Without it, an empty encode would pass every assertion below.
        XCTAssertTrue(json.contains("\"Spider Walk\""), "The exercise did not encode; the checks below are vacuous")

        XCTAssertNil(record.mastery)
        XCTAssertNil(record.masteryTempo)
        XCTAssertNil(record.masteryNotesPerBeat)
        XCTAssertNil(record.commandTempo, "A command tempo is a measured number (ADR 0045/0070)")
        XCTAssertNil(record.commandNotesPerBeat)
        XCTAssertNil(record.lastPracticed)
        XCTAssertFalse(record.isFavorite)
        XCTAssertNil(record.presetSlug)

        XCTAssertFalse(json.contains("\"mastery\" : 4"), "A mastery rating reached the file")
        XCTAssertFalse(json.contains("\"commandTempo\" : 128"), "A command tempo reached the file")
        XCTAssertFalse(json.contains("spider-walk"), "The preset slug reached the file")
    }

    /// `linkedSongIDs` names songs by `sourceID` — files on the sender's phone.
    func testAnExercisesLinkedSongsDoNotCross() throws {
        let routine = Routine(name: "Linked", dateAdded: fixedDate)
        let exercise = makeExercise()
        exercise.linkedSongs = [makeSong()]
        routine.items = [RoutineItem.item(exercise, order: 0)]

        let shared = share(routine)
        let json = try encodedJSON(shared)

        XCTAssertEqual(shared.exercises.first?.linkedSongIDs, [])
        XCTAssertFalse(json.contains("song-1"), "A song id on the sender's phone reached the file")
    }

    // MARK: - What cannot travel is named, not dropped (D4)

    func testALoopBlockCrossesAsANamedPlaceholderRatherThanAnId() throws {
        let fixture = makeRoutine()
        let routine = fixture.routine
        let loop = fixture.loop

        let shared = share(routine)
        let block = try XCTUnwrap(shared.routine?.items.first { $0.order == 1 })
        let placeholder = try XCTUnwrap(shared.placeholders.first { $0.itemUID == block.uid })

        XCTAssertNil(block.loopUID, "A loop id is meaningless without the song that owns it")
        XCTAssertEqual(placeholder.label, "Chorus — Slow Bend",
                       "The block says what it was, so the receiver can fill it in")
        XCTAssertEqual(loop.name, "Chorus", "Fixture check — the label is built from the live loop")
    }

    func testASongBlockCrossesAsANamedPlaceholder() throws {
        let routine = makeRoutine().routine

        let shared = share(routine)
        let block = try XCTUnwrap(shared.routine?.items.first { $0.order == 2 })
        let placeholder = try XCTUnwrap(shared.placeholders.first { $0.itemUID == block.uid })

        XCTAssertNil(block.songSourceID)
        XCTAssertEqual(placeholder.label, "Slow Bend")
    }

    /// The block count is the thing being protected: a routine that arrives quietly shorter than the
    /// one that was sent is the failure the placeholders exist to prevent.
    func testABlockThatCannotTravelIsStillABlock() {
        let routine = makeRoutine().routine

        let shared = share(routine)

        XCTAssertEqual(shared.routine?.items.count, routine.items.count)
        XCTAssertEqual(shared.placeholders.count, 2, "One for the loop block, one for the song block")
    }

    /// An exercise block carries its unit inline, a rest has none, and neither needs naming.
    func testOnlyLoopAndSongBlocksGetPlaceholders() throws {
        let routine = makeRoutine().routine

        let shared = share(routine)
        let exerciseBlock = try XCTUnwrap(shared.routine?.items.first { $0.order == 0 })
        let restBlock = try XCTUnwrap(shared.routine?.items.first { $0.order == 3 })

        XCTAssertNil(shared.placeholders.first { $0.itemUID == exerciseBlock.uid })
        XCTAssertNil(shared.placeholders.first { $0.itemUID == restBlock.uid })
    }

    /// A block whose unit was already deleted on the sender's device has nothing left to name — and
    /// arrives as the orphan the app already knows how to draw.
    func testAnAlreadyOrphanedBlockGetsNoPlaceholder() {
        let routine = Routine(name: "Orphaned", dateAdded: fixedDate)
        let orphan = RoutineItem(kind: .focused, order: 0)
        routine.items = [orphan]

        let shared = share(routine)

        XCTAssertEqual(shared.routine?.items.count, 1)
        XCTAssertTrue(shared.placeholders.isEmpty)
    }

    /// A take is the one thing ADR 0181 §7 keeps parked behind ADR 0150's legal question, and a share
    /// is exactly the path that would reopen it by accident.
    func testNoRecordingReachesTheFile() throws {
        let routine = makeRoutine().routine

        let json = try encodedJSON(share(routine))

        XCTAssertFalse(json.contains("\"takes\""), "Take rows reached a shared routine")
        XCTAssertFalse(json.contains(".m4a"), "Take audio was named in a shared routine")
    }

    // MARK: - The file itself

    /// The file is round-trippable by the decoder both doors will use — which is the whole reason S1
    /// ships before S2 rather than beside it.
    func testTheFileRoundTripsThroughTheSharedDecoder() throws {
        let routine = makeRoutine().routine
        let shared = share(routine)

        let data = try ArchiveCoding.encode(shared)
        let decoded = try ArchiveCoding.decode(SharedPractice.self, from: data)

        XCTAssertEqual(decoded, shared)
    }

    /// Dates go out with fractional seconds. Foundation's stock `.iso8601` truncates, which moves every
    /// timestamp by up to a second on the way back in.
    func testDatesSurviveToTheMillisecond() throws {
        let routine = makeRoutine().routine
        let moment = Date(timeIntervalSince1970: 1_700_000_000.123)
        let shared = SharedPracticeBuilder.routine(routine, appVersion: "1.2 (5)", exportedAt: moment)

        let decoded = try ArchiveCoding.decode(SharedPractice.self, from: ArchiveCoding.encode(shared))

        XCTAssertEqual(decoded.exportedAt.timeIntervalSince1970, moment.timeIntervalSince1970,
                       accuracy: 0.001)
    }

    /// The discriminator is written as `kind`, and stored raw so a payload a later build names can be
    /// *seen* rather than failing the whole file to decode.
    func testTheKindIsWrittenAsKindAndAnUnknownOneStillDecodes() throws {
        let routine = makeRoutine().routine
        var shared = share(routine)

        XCTAssertTrue(try encodedJSON(shared).contains("\"kind\" : \"routine\""))

        shared.kindRaw = "exercise"
        let decoded = try ArchiveCoding.decode(SharedPractice.self, from: ArchiveCoding.encode(shared))

        XCTAssertEqual(decoded.kindRaw, "exercise")
        XCTAssertNil(decoded.kind, "A payload this build does not know reads as nil, not as a throw")
    }

    // MARK: - The name the receiver sees

    func testTheFileIsNamedAfterTheRoutine() {
        XCTAssertEqual(SharedPracticeFile.fileName(for: "Morning warm-up"),
                       "Morning-warm-up.redmoonpractice")
    }

    func testAwkwardNamesStillProduceAUsableFileName() {
        XCTAssertEqual(SharedPracticeFile.fileName(for: "  Week 3 / bends!!  "),
                       "Week-3-bends.redmoonpractice",
                       "Runs collapse and the edges are trimmed, so no file starts or ends in a hyphen")
        XCTAssertEqual(SharedPracticeFile.fileName(for: ""), "routine.redmoonpractice")
        XCTAssertEqual(SharedPracticeFile.fileName(for: "🎸🎸"), "routine.redmoonpractice",
                       "A name this cannot spell lands somewhere defensible, not on an empty stem")
    }
}
