import Foundation
import SwiftData

/// What a checked `.redmoonpractice` file turned out to hold (ADR 0209 D4).
///
/// The reader's return type, and the reason there is still **one** inbound door rather than two. A
/// second `evaluate` for exercises would have meant a second version gate, a second decode and a
/// second place for the trust asymmetry to be got wrong; branching here instead means the host reads
/// the bytes once and switches on a value.
enum ReceivedPractice: Equatable {
    case routine(ReceivedRoutine)
    case exercise(ReceivedExercise)
}

/// A single shared drill that has been read, checked, and **not yet written anywhere**
/// (ADR 0209 D6) — the exercise twin of `ReceivedRoutine`, and the same contract: every number and
/// label the preview shows is computed here, so what the player was told and what lands cannot
/// disagree.
struct ReceivedExercise: Equatable {
    var exercise: ExerciseRecord

    /// The build and the moment the sender wrote it. On this door that is the only provenance there
    /// is, which is why it is shown rather than merely stored.
    var appVersion: String
    var exportedAt: Date

    /// What to call it on screen. Falls back the way `ReceivedRoutine.displayName` does — a drill can
    /// legitimately be saved unnamed, and an empty heading reads as a broken file.
    var displayName: String {
        let name = exercise.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Practice exercise" : name
    }

    /// The drill's template, or `nil` if the file names one this build does not know.
    ///
    /// Optional rather than `?? .basic`, and the preview draws nothing rather than a wrong chip: a
    /// drill authored on a later build's template arrives with a payload nothing here can render, and
    /// calling it "Basic" on the confirmation screen would be the one place the app tells the player
    /// something untrue about a file. The raw value still survives into the model
    /// (`ReceivedRoutineBuilder.exercise(from:)`), so a build that understands it will.
    var template: ExerciseTemplate? { ExerciseTemplate(rawValue: exercise.templateRaw) }

    /// The meter, as the drill states it — "4/4", and the subdivision beside it where there is one.
    var feel: String {
        let meter = "\(exercise.beatsPerBar)/\(exercise.noteValue)"
        guard let subdivision = Subdivision(rawValue: exercise.subdivisionRaw) else { return meter }
        return "\(meter) · \(subdivision.label)"
    }

    /// Where the drill starts and what it is aiming at, in one line.
    ///
    /// `targetTempoOverride` wins where the author pinned one — it is a goal somebody set, not a
    /// number anybody measured, which is why it crosses at all (ADR 0188 D5).
    var tempoPlan: String {
        let target = exercise.targetTempoOverride ?? exercise.targetTempo
        return "\(exercise.currentTempo) → \(target) BPM"
    }
}

/// The models a received drill becomes, **uninserted** (ADR 0209 D4).
///
/// A type rather than a bare `Exercise` so this door reads like the routine's: `materialize` returns
/// something you then `insert(into:)`, and the one place that touches the store is the host. It also
/// leaves somewhere for a drill's own dependencies to go if any are ever allowed to cross.
struct HydratedExercise {
    var exercise: Exercise

    /// Write it into `context`. One row, and no ordering problem to get wrong — the asymmetry with
    /// `HydratedRoutine.insert` is the point of having looked.
    @MainActor
    func insert(into context: ModelContext) {
        context.insert(exercise)
    }
}

/// Reads a `.redmoonpractice` file far enough to know what is in it (ADR 0209 D4) — the one entry
/// point both inbound doors go through, for both payload kinds.
///
/// Everything that must happen before a payload is believed happens here, once: the decode, the
/// version gate, and the kind. What follows is delegated to whichever builder owns that payload.
///
/// `@MainActor` only to sit alongside the builders it calls into; nothing in `evaluate` touches a
/// model or a context, which is what keeps every branch reachable from a test with no picker, no
/// document type and no simulator.
@MainActor
enum ReceivedPracticeBuilder {

    /// Read a file's bytes and decide whether there is anything to offer the player
    /// (ADR 0188 D2/D9, ADR 0209 D4).
    static func evaluate(data: Data) -> Result<ReceivedPractice, ReceiveFailure> {
        guard let payload = try? ArchiveCoding.decode(SharedPractice.self, from: data) else {
            return .failure(.corrupt)
        }
        // Version first, before anything else is believed about the contents (ADR 0188 D2). A file
        // from the future may well decode — the records are additive — and the fields this build
        // cannot see are precisely the ones that would make the import wrong.
        if case let .refuse(message) = SchemaVersionGate.evaluate(fileVersion: payload.schemaVersion) {
            return .failure(.futureVersion(message: message))
        }
        // The kind **after** the version, so a file from a later build that also names a later
        // payload is reported as being from the future rather than as an unknown kind. Both are true;
        // the version is the one the player can do something about.
        switch payload.kind {
        case .routine:
            return ReceivedRoutineBuilder.received(payload).map(ReceivedPractice.routine)
        case .exercise:
            return received(payload).map(ReceivedPractice.exercise)
        case nil:
            return .failure(.unsupportedKind)
        }
    }

    /// The exercise half of a checked file.
    ///
    /// **`first`, not "exactly one".** A sender writes a single drill (`SharedPracticeBuilder`), but
    /// this is the untrusted door: a file carrying two would be refused by a `count == 1` check for
    /// no benefit to anybody, when the header says exercise and the first one is plainly what was
    /// meant. Empty is the real failure, and it is the one reported.
    static func received(_ payload: SharedPractice) -> Result<ReceivedExercise, ReceiveFailure> {
        guard let record = payload.exercises.first else { return .failure(.incomplete(.exercise)) }
        return .success(ReceivedExercise(exercise: record,
                                         appVersion: payload.appVersion,
                                         exportedAt: payload.exportedAt))
    }

    /// Build the model a received drill becomes — **uninserted**, for the same reason the routine
    /// door returns one: inserting a graph inside the XCTest host traps
    /// (`docs/swiftdata-gotchas.md`), so a builder that inserted could not be tested at all.
    ///
    /// Hands straight off to `ReceivedRoutineBuilder.exercise(from:)`. A drill that arrives on its
    /// own is the same drill that arrives inside a routine, and ADR 0188 D5 already decided what it
    /// keeps: the shape, the rhythm, the ramp and the words; none of the sender's practice.
    static func materialize(_ received: ReceivedExercise) -> HydratedExercise {
        HydratedExercise(exercise: ReceivedRoutineBuilder.exercise(from: received.exercise))
    }
}
