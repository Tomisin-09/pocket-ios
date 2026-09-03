import Foundation
import SwiftData

// The library half of a restore: songs and everything they cascade to, drills, saved chords, and the
// reference links all three own. See `ArchiveRestoreWriter` for the rules these follow.

@MainActor
extension ArchiveRestoreWriter {

    /// Songs, with their loops, markers and links.
    ///
    /// **The audio does not come back, and cannot.** `SongRecord.audioFileName` names a file the
    /// archive deliberately does not carry — the player's own imported media, which they still have,
    /// and which would multiply the size of a file whose point is the writing. So the name is
    /// restored and the song arrives needing a relink (ADR 0152), with its loops, markers, tempo grid
    /// and every word written about it intact. `RestorePlan.songsNeedingRelink` is what says so before
    /// the restore rather than after.
    ///
    /// `bookmark` is not restored either, and there is nothing to restore: it is installation-scoped
    /// and was never exported, which is the reason ADR 0148 keeps owned copies in the first place.
    static func addSongs(_ records: [SongRecord],
                         existing: RestoreExistingKeys,
                         into landing: inout RestoredLibrary,
                         resolver: inout RestoreResolver) {
        for record in records where !existing.songSourceIDs.contains(record.sourceID) {
            guard resolver.songs[record.sourceID] == nil else { continue }
            let song = Song(title: record.title,
                            artist: record.artist,
                            album: record.album,
                            genre: record.genre,
                            year: record.year,
                            key: record.key,
                            bpm: record.bpm,
                            preciseBPM: record.preciseBPM,
                            downbeatSeconds: record.downbeatSeconds,
                            collections: record.collections,
                            comment: record.comment,
                            duration: record.duration,
                            dateAdded: record.dateAdded,
                            lastPracticed: record.lastPracticed,
                            ref: SongRef(id: record.sourceID, source: .localFile, bookmark: nil),
                            audioFileName: record.audioFileName)
            // Raw, not through `SongRef`. `Song.init` writes `ref.source.rawValue`, and `SongRef.Source`
            // resolves unknown values to `.localFile` — so routing an unrecognised source through the
            // typed initialiser would rewrite it as it landed. The same rule as every other enum
            // column here, and the reason the `ref:` above passes a placeholder source rather than a
            // decoded one.
            song.sourceRaw = record.sourceRaw
            song.extraDownbeatSeconds = record.extraDownbeatSeconds
            song.beatsPerBar = record.beatsPerBar
            song.noteValue = record.noteValue
            song.showsGridlines = record.showsGridlines
            song.lastPracticedSpeed = record.lastPracticedSpeed
            song.loops = record.loops.map(loop)
            song.markers = record.markers.map {
                let marker = Marker(seconds: $0.seconds, label: $0.label)
                marker.uid = $0.uid
                return marker
            }
            song.references = references(record.references)

            landing.songs.append(song)
            resolver.songs[record.sourceID] = song
            for made in song.loops { resolver.loops[made.uid] = made }
        }
    }

    /// One loop, with the `uid` the file gave it.
    ///
    /// **The uid is preserved rather than minted**, which is D1's whole asymmetry: these are the
    /// player's own rows coming home, and the journal entries and takes that point at this loop point
    /// at *this* uid. Minting a new one would restore a library in which nothing written about a loop
    /// still found it.
    private static func loop(from record: LoopRecord) -> Loop {
        let made = Loop(name: record.name, start: record.start, end: record.end,
                        speed: record.speed, repeats: record.repeats)
        made.uid = record.uid
        made.loopTypeRaw = record.loopTypeRaw
        made.tags = record.tags
        made.isFavorite = record.isFavorite
        made.isBackingTrack = record.isBackingTrack
        made.lastPracticedSpeed = record.lastPracticedSpeed
        // Mastery, focus and the measured command tempo all cross. The receive door drops exactly
        // these (D5) because they are a stranger's achievement; a restore is the same player's own,
        // and dropping them would make a backup lose the record of how far they had got.
        made.mastery = record.mastery
        made.masteryAtSpeed = record.masteryAtSpeed
        made.focus = record.focus
        made.commandTempo = record.commandTempo
        made.targetSpeedOverride = record.targetSpeedOverride
        made.automatorEnabled = record.automatorEnabled
        made.automatorTargetSpeed = record.automatorTargetSpeed
        made.automatorStepCount = record.automatorStepCount
        made.automatorLoopsPerStep = record.automatorLoopsPerStep
        made.rampWarmupSteps = record.rampWarmupSteps
        made.rampReachSteps = record.rampReachSteps
        made.rampBackoffSteps = record.rampBackoffSteps
        made.rampRepsPerStep = record.rampRepsPerStep
        made.rampDwellIntervals = record.rampDwellIntervals
        made.includeBackoff = record.includeBackoff
        made.backoffSpeedOverride = record.backoffSpeedOverride
        made.colorIndex = record.colorIndex
        made.customColorHex = record.customColorHex
        made.references = references(record.references)
        return made
    }

    /// Drills, whole — history included.
    ///
    /// The mirror image of `ReceivedRoutineBuilder.exercise(from:)`, and the difference is the point.
    /// That one drops `mastery`, `lastPracticed`, `isFavorite`, `presetSlug`, `commandTempo` and
    /// `linkedSongIDs` because a teacher's achievement must not arrive wearing the receiver's name
    /// (D5, ADR 0070). This one keeps every one of them, because they are the player's own and a
    /// backup that quietly reset a year of mastery would be worse than no backup.
    static func addExercises(_ records: [ExerciseRecord],
                             existing: RestoreExistingKeys,
                             into landing: inout RestoredLibrary,
                             resolver: inout RestoreResolver) {
        for record in records where !existing.exerciseUIDs.contains(record.uid) {
            guard resolver.exercises[record.uid] == nil else { continue }
            let drill = Exercise(name: record.name,
                                 currentTempo: record.currentTempo,
                                 targetTempo: record.targetTempo,
                                 beatsPerBar: record.beatsPerBar,
                                 noteValue: record.noteValue,
                                 accentBeats: record.accentBeats,
                                 notesPerBeat: record.notesPerBeat,
                                 templatePayload: templateData(record.template),
                                 rampStepBPM: record.rampStepBPM,
                                 rampIntervalCount: record.rampIntervalCount,
                                 dwellIntervals: record.dwellIntervals,
                                 includeBackoff: record.includeBackoff,
                                 rampReachSteps: record.rampReachSteps,
                                 rampBackoffSteps: record.rampBackoffSteps,
                                 backoffTempoOverride: record.backoffTempoOverride,
                                 tags: record.tags,
                                 notes: record.notes)
            drill.uid = record.uid
            drill.dateAdded = record.dateAdded
            drill.lastPracticed = record.lastPracticed
            drill.isFavorite = record.isFavorite
            drill.presetSlug = record.presetSlug
            drill.targetTempoOverride = record.targetTempoOverride
            drill.commandTempo = record.commandTempo
            drill.commandNotesPerBeat = record.commandNotesPerBeat
            drill.mastery = record.mastery
            drill.masteryTempo = record.masteryTempo
            drill.masteryNotesPerBeat = record.masteryNotesPerBeat
            drill.awayFromInstrument = record.awayFromInstrument
            drill.clickEnabled = record.clickEnabled
            drill.clickBPM = record.clickBPM
            // The four enum columns, raw — see `ArchiveRestoreWriter`'s note on why a typed setter
            // would rewrite an unrecognised value as it landed.
            drill.templateRaw = record.templateRaw
            drill.instrumentRaw = record.instrumentRaw
            drill.subdivisionRaw = record.subdivisionRaw
            drill.rampIntervalUnitRaw = record.rampIntervalUnitRaw
            drill.references = references(record.references)

            landing.exercises.append(drill)
            resolver.exercises[record.uid] = drill
        }
    }

    /// Saved chords (ADR 0095). The voicing goes back into the opaque column it came out of.
    ///
    /// A chord whose blob will not re-encode is **skipped rather than landed empty**: `voicingData` is
    /// the whole of a saved chord, and a row with a name and no voicing is a shape the rest of the app
    /// has no reading for. Every other kind here degrades to a usable row; this one has nothing to
    /// degrade to.
    static func addSavedChords(_ records: [SavedChordRecord],
                               existing: RestoreExistingKeys,
                               into landing: inout RestoredLibrary) {
        var seen = Set<UUID>()
        for record in records where !existing.savedChordUIDs.contains(record.uid) {
            guard seen.insert(record.uid).inserted else { continue }
            guard let voicing = record.voicing, let data = try? JSONEncoder().encode(voicing) else { continue }
            landing.savedChords.append(SavedChord(uid: record.uid, name: record.name,
                                                  createdAt: record.createdAt, voicingData: data))
        }
    }

    /// Reference links, with their uids and their attachment names intact.
    ///
    /// **D7's leaf-name rewrite does not apply on this door, and the reason is worth stating.** D7
    /// argues that a new uid forces `attachmentFileName` to be rewritten, because attachments are
    /// `<uid>.<ext>` in one flat directory. That is the *receive* door's problem: it mints uids (D1).
    /// A restore preserves them, so the leaf name is unchanged, and a name that collided would mean a
    /// uid that collided — which the owner's skip has already handled by not building this row at all.
    ///
    /// D7's other half applies in full, and is `ArchiveRestoreFiles`': the row is written before the
    /// file, because ADR 0182's sweep defines an orphan as a file with no row and *Reclaim space* is a
    /// button the player can press at any moment.
    static func references(_ records: [ReferenceLinkRecord]) -> [ReferenceLink] {
        records.map { record in
            let link = ReferenceLink(uid: record.uid,
                                     title: record.title,
                                     note: record.note,
                                     urlString: record.urlString,
                                     attachmentFileName: record.attachmentFileName,
                                     order: record.order,
                                     dateAdded: record.dateAdded)
            link.kindRaw = record.kindRaw
            return link
        }
    }

    /// A drill's authored content, back in the opaque column. Re-encoded with a plain `JSONEncoder`
    /// because that is what wrote it — `ArchiveCoding`'s date strategy governs the archive's own
    /// timestamps, not a nested blob that has none.
    static func templateData(_ value: JSONValue?) -> Data? {
        guard let value else { return nil }
        return try? JSONEncoder().encode(value)
    }
}
