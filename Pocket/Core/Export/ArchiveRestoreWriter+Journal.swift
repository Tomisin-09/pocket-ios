import Foundation
import SwiftData

// What the player wrote and what they recorded, plus the one profile. See `ArchiveRestoreWriter` for
// the rules these follow.

@MainActor
extension ArchiveRestoreWriter {

    /// Journal entries (ADR 0143, ADR 0155).
    ///
    /// The owner columns are restored **in the two different shapes the model keeps them in**, and the
    /// difference is load-bearing: `loop` and `exercise` are relationships that nullify when the unit
    /// goes, so an entry survives its unit as an orphan; `routineUID` is a loose id with the routine's
    /// name snapshotted beside it, so deleting a routine cannot delete a reflection written about it.
    /// Resolving `routineUID` into a relationship here would quietly convert the second into the first
    /// and change what a later deletion does.
    ///
    /// An entry whose loop or exercise is not in this library lands with neither — which is exactly
    /// `.orphan` (ADR 0143's `ownerKind` discriminator), a state the journal already draws, and the
    /// honest one: the words were written, the unit is gone.
    static func addJournal(_ records: [JournalEntryRecord],
                           existing: RestoreExistingKeys,
                           into landing: inout RestoredLibrary,
                           resolver: RestoreResolver) {
        var seen = Set<UUID>()
        for record in records where !existing.journalUIDs.contains(record.uid) {
            guard seen.insert(record.uid).inserted else { continue }
            let entry = JournalEntry(text: record.text,
                                     kind: .note,
                                     masteryAtEntry: record.masteryAtEntry,
                                     commandTempoAtEntry: record.commandTempoAtEntry,
                                     commandBpmAtEntry: record.commandBpmAtEntry,
                                     commandNotesPerBeatAtEntry: record.commandNotesPerBeatAtEntry,
                                     createdAt: record.createdAt)
            entry.uid = record.uid
            // `EntryKind` does have an `init(raw:)`, and the raw column is still what is written: the
            // initialiser above takes a typed kind, so a value this build does not recognise would be
            // resolved and written back normalised. `.note` is a placeholder overwritten on the next
            // line, never a decision about the entry.
            entry.kindRaw = record.kindRaw
            entry.loop = record.loopUID.flatMap { resolver.loops[$0] }
            entry.exercise = record.exerciseUID.flatMap { resolver.exercises[$0] }
            entry.routineUID = record.routineUID
            entry.routineNameAtEntry = record.routineNameAtEntry
            entry.ownerLabelAtEntry = record.ownerLabelAtEntry
            entry.practisedUnitsRaw = jsonString(record.practisedUnits)
            entry.isStandalone = record.isStandalone
            entry.isMetronome = record.isMetronome
            entry.metronomeBpmAtEntry = record.metronomeBpmAtEntry
            entry.metronomeBeatsAtEntry = record.metronomeBeatsAtEntry
            entry.metronomeNoteValueAtEntry = record.metronomeNoteValueAtEntry
            entry.metronomeSubdivisionRaw = record.metronomeSubdivisionRaw
            entry.metronomeWithdrawalRaw = record.metronomeWithdrawalRaw
            landing.journal.append(entry)
        }
    }

    /// Takes and the moments pinned inside them (ADR 0069, ADR 0175).
    ///
    /// The row lands whether or not its audio is in the zip, and that is deliberate rather than
    /// permissive. An archive exported without take audio still carries every take's title, note and
    /// moments; so does one whose file was already missing at export time
    /// (`ExportedArchive.takesMissing`). Refusing the row would throw away the writing to punish the
    /// absence of the recording — and ADR 0151 keeps a take's row when its loop is deleted for the
    /// same reason. `RestorePlan.takeAudioMissing` is what tells the player which ones those are.
    static func addTakes(_ records: [RecordingRecord],
                         existing: RestoreExistingKeys,
                         into landing: inout RestoredLibrary,
                         resolver: RestoreResolver) {
        var seen = Set<UUID>()
        for record in records where !existing.takeUIDs.contains(record.uid) {
            guard seen.insert(record.uid).inserted else { continue }
            let take = Recording(fileName: record.fileName,
                                 duration: record.duration,
                                 uid: record.uid,
                                 createdAt: record.createdAt,
                                 loop: record.loopUID.flatMap { resolver.loops[$0] },
                                 exercise: record.exerciseUID.flatMap { resolver.exercises[$0] },
                                 song: record.songSourceID.flatMap { resolver.songs[$0] })
            take.title = record.title
            take.note = record.note
            take.ownerLabelAtTake = record.ownerLabelAtTake
            let moments = record.moments.map { moment in
                TakeNote(time: moment.time, text: moment.text, uid: moment.uid, createdAt: moment.createdAt)
            }
            landing.takes.append((take, moments))
        }
    }

    /// The local artist profile (ADR 0113). At most one exists, so this lands only into a library that
    /// has none — a second would be a row the app has no way to choose between.
    static func addProfile(_ record: ProfileRecord?,
                           existing: RestoreExistingKeys,
                           into landing: inout RestoredLibrary) {
        guard let record, !existing.hasProfile else { return }
        let profile = Profile(uid: record.uid, artistName: record.artistName, createdAt: record.createdAt)
        // Every one of these is a raw column on the model too, backing an enum whose cases may be added
        // to. They are exported as stored and restored as stored, for the reason `ProfileRecord` gives.
        profile.experienceRaw = record.experienceRaw
        profile.genresRaw = record.genresRaw
        profile.dreamRaw = record.dreamRaw
        profile.minutesPerDayRaw = record.minutesPerDayRaw
        profile.preferredInstrumentRaw = record.preferredInstrumentRaw
        landing.profile = profile
    }

    /// A nested `JSONValue` back into the JSON **string** column it came out of.
    ///
    /// `JournalEntry.practisedUnitsRaw` is a `String?`, not `Data` — `SessionUnitRef.encode` wrote it —
    /// so this is the mirror of `JSONValue.decoding(json:)` rather than of `decoding(_:)`.
    static func jsonString(_ value: JSONValue?) -> String? {
        guard let value, let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
