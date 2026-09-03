import Foundation
import SwiftData

// The session half of a restore: routines and their blocks, both kinds of goal, and the practice log.

@MainActor
extension ArchiveRestoreWriter {

    /// Routines, with their blocks pointing back at the units they name.
    ///
    /// A block resolves against **everything** — the rows this restore is adding and the rows the
    /// library already had — which is why the resolver is filled in before this runs. A restore into a
    /// library that already holds the exercise must produce a routine pointing at *that* exercise:
    /// building a second copy would duplicate a drill the player still has, and resolving to nothing
    /// would fabricate an orphan out of a link the archive recorded perfectly well.
    static func addRoutines(_ records: [RoutineRecord],
                            existing: RestoreExistingKeys,
                            into landing: inout RestoredLibrary,
                            resolver: RestoreResolver) {
        var seen = Set<UUID>()
        for record in records where !existing.routineUIDs.contains(record.uid) {
            guard seen.insert(record.uid).inserted else { continue }
            let routine = Routine(name: record.name, dateAdded: record.dateAdded)
            routine.uid = record.uid
            routine.notes = record.notes
            routine.lastPracticed = record.lastPracticed
            routine.isFavorite = record.isFavorite
            routine.presetSlug = record.presetSlug
            routine.references = references(record.references)

            let items = record.items
                .sorted { ($0.order, $0.uid.uuidString) < ($1.order, $1.uid.uuidString) }
                .map { block(from: $0, resolver: resolver) }
            landing.routines.append((routine, items))
        }
    }

    /// One block.
    ///
    /// **`order` is kept, not renumbered.** S2 renumbers a received routine from zero, for
    /// `Routine.duplicated(named:)`'s reason — a stranger's file may carry drift there is no reason to
    /// inherit. A restore is the opposite case: these are the player's own numbers, and rewriting them
    /// would mean an archive could not reproduce the library it was taken from, which is the one thing
    /// a backup has to do.
    ///
    /// A block whose unit does not resolve lands as `RoutineItem.isOrphaned` with the label the file
    /// gave it — the additive `orphanLabel` the S2 follow-up added, and, as that slice's note
    /// predicted, the only label source this door has.
    private static func block(from record: RoutineItemRecord, resolver: RestoreResolver) -> RoutineItem {
        let item = RoutineItem(order: record.order)
        item.uid = record.uid
        // Raw, not `RoutineItemKind(raw:)`: a kind this build does not recognise would fold to `.rest`
        // and be written back as one, turning a drill block from a later version into a silent gap.
        item.kindRaw = record.kindRaw
        item.reps = record.reps
        item.plannedMinutes = record.plannedMinutes
        item.usesAuthoredLength = record.usesAuthoredLength
        item.recordsTake = record.recordsTake
        item.loopRunModeRaw = record.loopRunModeRaw
        if let uid = record.exerciseUID { item.exercise = resolver.exercises[uid] }
        if let uid = record.loopUID { item.loop = resolver.loops[uid] }
        if let sourceID = record.songSourceID { item.song = resolver.songs[sourceID] }
        // Only onto a block that resolved nothing — a label sitting on a block that *does* resolve
        // would be a fact about it that is not true, waiting for a future reader to trust it.
        if item.exercise == nil && item.loop == nil && item.song == nil {
            item.orphanLabel = record.orphanLabel
        }
        return item
    }

    /// Both kinds of goal (ADR 0113, ADR 0171).
    ///
    /// A goal whose target song is not in the library lands **without** one rather than not landing:
    /// the title is the goal, and the song is a pointer that sharpens it. Dropping the row would lose
    /// what the player wrote because of a link that no longer resolves.
    static func addGoals(_ archive: PracticeArchive,
                         existing: RestoreExistingKeys,
                         into landing: inout RestoredLibrary,
                         resolver: RestoreResolver) {
        var seen = Set<UUID>()
        for record in archive.goals where !existing.goalUIDs.contains(record.uid) {
            guard seen.insert(record.uid).inserted else { continue }
            let goal = Goal(title: record.title,
                            weight: record.weight,
                            skillIDs: record.skillIDs,
                            targetSong: record.targetSongID.flatMap { resolver.songs[$0] },
                            isMet: record.isMet,
                            dateAdded: record.dateAdded)
            goal.uid = record.uid
            landing.goals.append(goal)
        }
        for record in archive.longTermGoals where !existing.longTermGoalUIDs.contains(record.uid) {
            guard seen.insert(record.uid).inserted else { continue }
            let goal = LongTermGoal(title: record.title,
                                    skillIDs: record.skillIDs,
                                    order: record.order,
                                    targetSong: record.targetSongID.flatMap { resolver.songs[$0] },
                                    isMet: record.isMet,
                                    dateAdded: record.dateAdded)
            goal.uid = record.uid
            landing.longTermGoals.append(goal)
        }
    }

    /// The practice log — one row per unit-run (ADR 0117).
    ///
    /// `unitUID` and `routineUID` are **loose ids by design**, not relationships, so nothing is
    /// resolved here and a run whose unit has since been deleted restores exactly as it was exported.
    /// That is the same reason the log survives deleting a routine in the live app.
    static func addRuns(_ records: [SessionRecord],
                        existing: RestoreExistingKeys,
                        into landing: inout RestoredLibrary) {
        var seen = Set<UUID>()
        for record in records where !existing.runUIDs.contains(record.id) {
            guard seen.insert(record.id).inserted else { continue }
            landing.runs.append(PracticeRun(uid: record.id,
                                            startedAt: record.startedAt,
                                            durationSeconds: record.durationSeconds,
                                            kind: record.kind,
                                            unitUID: record.unitUID,
                                            routineUID: record.routineUID,
                                            tempoBPM: record.tempoBPM,
                                            tempoPercent: record.tempoPercent,
                                            notesPerBeat: record.notesPerBeat))
        }
    }
}
