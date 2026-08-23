import Foundation

// The rest of `ArchiveBuilder`'s mapping — exercises, routines, goals, journal and takes. Split from
// the main file only because SwiftLint caps a file at 400 lines; the ordering and identity rules are
// stated once, on `ArchiveBuilder` itself.
extension ArchiveBuilder {

    // MARK: - Exercises

    static func exerciseRecord(_ exercise: Exercise) -> ExerciseRecord {
        ExerciseRecord(
            uid: exercise.uid,
            name: exercise.name,
            notes: exercise.notes,
            tags: exercise.tags.sorted(),
            presetSlug: exercise.presetSlug,
            isFavorite: exercise.isFavorite,
            dateAdded: exercise.dateAdded,
            lastPracticed: exercise.lastPracticed,
            currentTempo: exercise.currentTempo,
            commandTempo: exercise.commandTempo,
            targetTempo: exercise.targetTempo,
            targetTempoOverride: exercise.targetTempoOverride,
            beatsPerBar: exercise.beatsPerBar,
            noteValue: exercise.noteValue,
            accentBeats: exercise.accentBeats,
            subdivisionRaw: exercise.subdivisionRaw,
            notesPerBeat: exercise.notesPerBeat,
            commandNotesPerBeat: exercise.commandNotesPerBeat,
            templateRaw: exercise.templateRaw,
            instrumentRaw: exercise.instrumentRaw,
            // Decoded, not base64. Untyped, so a payload shape this build does not know still travels.
            template: JSONValue.decoding(exercise.templatePayload),
            rampStepBPM: exercise.rampStepBPM,
            rampIntervalCount: exercise.rampIntervalCount,
            rampIntervalUnitRaw: exercise.rampIntervalUnitRaw,
            dwellIntervals: exercise.dwellIntervals,
            includeBackoff: exercise.includeBackoff,
            rampReachSteps: exercise.rampReachSteps,
            rampBackoffSteps: exercise.rampBackoffSteps,
            backoffTempoOverride: exercise.backoffTempoOverride,
            awayFromInstrument: exercise.awayFromInstrument,
            clickEnabled: exercise.clickEnabled,
            clickBPM: exercise.clickBPM,
            mastery: exercise.mastery,
            masteryTempo: exercise.masteryTempo,
            masteryNotesPerBeat: exercise.masteryNotesPerBeat,
            linkedSongIDs: exercise.linkedSongs.map(\.sourceID).sorted(),
            references: referenceRecords(exercise.references)
        )
    }

    static func savedChordRecord(_ chord: SavedChord) -> SavedChordRecord {
        SavedChordRecord(uid: chord.uid,
                         name: chord.name,
                         createdAt: chord.createdAt,
                         voicing: JSONValue.decoding(chord.voicingData))
    }

    // MARK: - Routines

    static func routineRecord(_ routine: Routine) -> RoutineRecord {
        RoutineRecord(
            uid: routine.uid,
            name: routine.name,
            notes: routine.notes,
            dateAdded: routine.dateAdded,
            lastPracticed: routine.lastPracticed,
            isFavorite: routine.isFavorite,
            presetSlug: routine.presetSlug,
            // `orderedItems` is the model's own play order (ADR 0066 R2) — `order`, with `uid` breaking
            // ties. Reusing it keeps the archive in the sequence the player authored rather than a
            // second opinion about it.
            items: routine.orderedItems.map(routineItemRecord),
            references: referenceRecords(routine.references)
        )
    }

    /// A block, with its unit written as an id rather than nested.
    ///
    /// `canRecordTake` is not exported: it is derived from the unit, and an archive that froze today's
    /// rule would go on asserting it after the rule moved.
    static func routineItemRecord(_ item: RoutineItem) -> RoutineItemRecord {
        RoutineItemRecord(uid: item.uid,
                          order: item.order,
                          kindRaw: item.kindRaw,
                          reps: item.reps,
                          plannedMinutes: item.plannedMinutes,
                          usesAuthoredLength: item.usesAuthoredLength,
                          recordsTake: item.recordsTake,
                          loopRunModeRaw: item.loopRunModeRaw,
                          exerciseUID: item.exercise?.uid,
                          loopUID: item.loop?.uid,
                          songSourceID: item.song?.sourceID)
    }

    // MARK: - Goals

    static func goalRecord(_ goal: Goal) -> GoalRecord {
        GoalRecord(uid: goal.uid,
                   title: goal.title,
                   weight: goal.weight,
                   skillIDs: goal.skillIDs.sorted(),
                   targetSongID: goal.targetSong?.sourceID,
                   isMet: goal.isMet,
                   dateAdded: goal.dateAdded)
    }

    static func longTermGoalRecord(_ goal: LongTermGoal) -> LongTermGoalRecord {
        LongTermGoalRecord(uid: goal.uid,
                           title: goal.title,
                           skillIDs: goal.skillIDs.sorted(),
                           order: goal.order,
                           targetSongID: goal.targetSong?.sourceID,
                           isMet: goal.isMet,
                           dateAdded: goal.dateAdded)
    }

    static func profileRecord(_ profile: Profile) -> ProfileRecord {
        ProfileRecord(uid: profile.uid,
                      artistName: profile.artistName,
                      createdAt: profile.createdAt,
                      experienceRaw: profile.experienceRaw,
                      genresRaw: profile.genresRaw,
                      dreamRaw: profile.dreamRaw,
                      minutesPerDayRaw: profile.minutesPerDayRaw,
                      preferredInstrumentRaw: profile.preferredInstrumentRaw)
    }

    // MARK: - Journal and takes

    static func journalRecord(_ entry: JournalEntry) -> JournalEntryRecord {
        JournalEntryRecord(
            uid: entry.uid,
            createdAt: entry.createdAt,
            text: entry.text,
            kindRaw: entry.kindRaw,
            masteryAtEntry: entry.masteryAtEntry,
            commandTempoAtEntry: entry.commandTempoAtEntry,
            commandBpmAtEntry: entry.commandBpmAtEntry,
            commandNotesPerBeatAtEntry: entry.commandNotesPerBeatAtEntry,
            loopUID: entry.loop?.uid,
            exerciseUID: entry.exercise?.uid,
            // A loose id with a snapshotted name beside it, not a relationship (ADR 0143) — both
            // columns cross into the archive as they are.
            routineUID: entry.routineUID,
            routineNameAtEntry: entry.routineNameAtEntry,
            ownerLabelAtEntry: entry.ownerLabelAtEntry,
            practisedUnits: JSONValue.decoding(json: entry.practisedUnitsRaw),
            isStandalone: entry.isStandalone,
            isMetronome: entry.isMetronome,
            metronomeBpmAtEntry: entry.metronomeBpmAtEntry,
            metronomeBeatsAtEntry: entry.metronomeBeatsAtEntry,
            metronomeNoteValueAtEntry: entry.metronomeNoteValueAtEntry,
            metronomeSubdivisionRaw: entry.metronomeSubdivisionRaw,
            metronomeWithdrawalRaw: entry.metronomeWithdrawalRaw
        )
    }

    static func recordingRecord(_ recording: Recording) -> RecordingRecord {
        RecordingRecord(
            uid: recording.uid,
            createdAt: recording.createdAt,
            duration: recording.duration,
            title: recording.title,
            note: recording.note,
            fileName: recording.fileName,
            ownerLabelAtTake: recording.ownerLabelAtTake,
            loopUID: recording.loop?.uid,
            exerciseUID: recording.exercise?.uid,
            songSourceID: recording.song?.sourceID,
            // Moments in playback order — where they sit in the take, which is the order the take
            // screen lists them in and the only one that means anything about the audio.
            moments: recording.moments
                .sorted { ($0.time, $0.uid.uuidString) < ($1.time, $1.uid.uuidString) }
                .map {
                    TakeNoteRecord(uid: $0.uid, time: $0.time, text: $0.text, createdAt: $0.createdAt)
                }
        )
    }
}
