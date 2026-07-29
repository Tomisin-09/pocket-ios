import Foundation
import SwiftData

/// The one-time **note-rate backfill** (ADR 0121), run once at launch beside the preset backfills.
///
/// It exists so that no call site ever has to branch on provenance. After it runs:
///
/// - every drill that stated a rhythm through the retired `subdivision` field states it through
///   `notesPerBeat` instead (the seeded *Spider Walk* keeps its sixteenths);
/// - every **measured** command on a drill that states a rhythm is bound to it, so
///   `commandNotesPerBeat == nil` means exactly one thing — nothing is bound — and never
///   "legacy, unknown, be careful".
///
/// The binding it writes is an **assumption**: it takes the command to have been measured at the
/// drill's current rhythm, which is the only value available and is right for every seeded preset
/// (they ship at one rhythm and are measured against it). That assumption is affordable precisely
/// because the release is being held and there are no users yet — after distribution this would owe
/// a real "unknown provenance" state instead, so if a build ever ships before this runs, revisit it.
enum ExerciseNoteRateBackfill {

    /// `UserDefaults` key guarding the one-time run.
    static let backfillKey = "exerciseNoteRateBackfill.v1"

    /// Stamp `notesPerBeat` and `commandNotesPerBeat` onto every exercise that predates them. Fetch
    /// **all** exercises and filter in memory — never an optional `#Predicate`, which starves the
    /// main thread (the SwiftData optional-predicate freeze). Guarded so it runs at most once; safe
    /// to call on every launch.
    static func runIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: backfillKey) else { return }
        for exercise in (try? context.fetch(FetchDescriptor<Exercise>())) ?? [] {
            apply(to: exercise)
        }
        try? context.save()
        defaults.set(true, forKey: backfillKey)
    }

    /// The per-exercise rule, split out so it is unit-testable without a store. Idempotent: an
    /// exercise that already carries both fields is untouched, so a re-run can't overwrite a rhythm
    /// the player has since answered for.
    static func apply(to exercise: Exercise) {
        // The retired click subdivision was the only rhythm a content-less drill stated; move it.
        // `.none` stated nothing, and stays nothing rather than becoming a defaulted "quarters".
        if exercise.notesPerBeat == nil, exercise.subdivision != .none {
            exercise.notesPerBeat = exercise.subdivision.ticksPerBeat
        }
        // Bind a measured command to whatever rhythm the drill now resolves to (content first).
        if exercise.commandNotesPerBeat == nil, exercise.hasMeasuredCommand {
            exercise.commandNotesPerBeat = exercise.noteRate?.perBeat
        }
    }
}
