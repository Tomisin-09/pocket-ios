import Foundation
import XCTest
@testable import Pocket

/// The routine a `.redmoonpractice` file is built from, shared by the two receiving test files
/// (ADR 0188 S2).
///
/// One fixture rather than one per file, because the version gate and the hydration are two halves of
/// the same door: a fixture that drifted between them would let a field be asserted as *carried* in
/// one file and as *dropped* in the other, which is precisely the failure a share is most likely to
/// have.
///
/// Every model here is built and left **uninserted** — the house rule for model tests in this host
/// (inserting a graph traps, `docs/swiftdata-gotchas.md`) and the reason both builders return values
/// rather than writing anything.
@MainActor
enum ReceivedRoutineFixture {

    /// Pinned to a whole second, for `SharedPracticeTests`' reason: the file carries dates to the
    /// millisecond, so a `Date.now` fixture cannot survive a round trip and the round-trip test would
    /// fail on the format working exactly as designed.
    static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// A drill with a value in every field the receiving side has an opinion about — the shape it
    /// should carry, and the sender's history it should not.
    static func exercise(named name: String = "Spider Walk") -> Exercise {
        let exercise = Exercise(name: name,
                                currentTempo: 96,
                                targetTempo: 144,
                                beatsPerBar: 6,
                                noteValue: 8,
                                accentBeats: [0, 3],
                                notesPerBeat: 3,
                                template: .scales,
                                instrument: .bass,
                                rampStepBPM: 7,
                                rampIntervalCount: 8,
                                rampIntervalUnit: .seconds,
                                dwellIntervals: 6,
                                includeBackoff: false,
                                rampReachSteps: 2,
                                rampBackoffSteps: 1,
                                backoffTempoOverride: 70,
                                tags: ["picking"],
                                notes: "Keep the thumb behind the neck.")
        exercise.targetTempoOverride = 160
        exercise.clickEnabled = true
        exercise.clickBPM = 54
        exercise.awayFromInstrument = true
        exercise.mastery = 4
        exercise.masteryTempo = 132
        exercise.commandTempo = 128
        exercise.commandNotesPerBeat = 4
        exercise.lastPracticed = Date(timeIntervalSince1970: 1_000)
        exercise.isFavorite = true
        exercise.presetSlug = "spider-walk"
        return exercise
    }

    /// A routine with one exercise block, one loop block and a rest — enough for the placeholder, the
    /// orphan and the untouched rest to each have something to be.
    static func routine() -> (routine: Routine, exercise: Exercise) {
        let routine = Routine(name: "Morning warm-up", dateAdded: fixedDate)
        routine.notes = "The bits of week 3 that actually needed work."
        routine.lastPracticed = Date(timeIntervalSince1970: 2_000)
        routine.isFavorite = true
        routine.presetSlug = "morning-warm-up"

        let drill = exercise()
        let song = Song(title: "Slow Bend", artist: "Jack Trader", duration: 200,
                        amplitudes: Array(repeating: 0.5, count: 512),
                        ref: SongRef(id: "song-1", source: .localFile, bookmark: nil),
                        audioFileName: "song-1.wav")
        let loop = Loop(name: "Chorus", start: 10, end: 20, speed: 0.8, repeats: 4)
        loop.song = song

        let block = RoutineItem.item(drill, order: 0)
        block.reps = 3
        block.plannedMinutes = 12
        block.recordsTake = true
        routine.items = [block, RoutineItem.item(loop, order: 1), RoutineItem.rest(order: 2)]
        return (routine, drill)
    }

    /// What S1 would hand to the share sheet for this routine.
    static func shared(_ routine: Routine) -> SharedPractice {
        SharedPracticeBuilder.routine(routine, appVersion: "1.2 (7)", exportedAt: fixedDate)
    }

    /// A file's bytes, written by the same encoder the share sheet uses.
    static func encoded(_ payload: SharedPractice) throws -> Data {
        try ArchiveCoding.encode(payload)
    }

    /// A payload read back through the real door.
    static func received(_ payload: SharedPractice) throws -> ReceivedRoutine {
        try ReceivedRoutineBuilder.evaluate(data: try encoded(payload)).get()
    }

    /// A file the door was expected to refuse. **Throws rather than skipping** if it was accepted: a
    /// skipped test reads as green, which is the one thing a refusal test must not do.
    static func failure(of data: Data) throws -> ReceiveFailure {
        switch ReceivedRoutineBuilder.evaluate(data: data) {
        case let .success(value): throw UnexpectedlyReadable(name: value.displayName)
        case let .failure(reason): return reason
        }
    }

    struct UnexpectedlyReadable: Error {
        let name: String
    }
}
