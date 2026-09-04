import Foundation
@testable import Pocket

/// Archive records, built once so every restore test argues about behaviour rather than about field
/// lists (ADR 0188 S3).
///
/// These are the **DTOs**, not models: they are what a `practice.json` holds, so a test can state the
/// file it is restoring without standing up a store to export from. Values are deliberately
/// distinctive — a tempo of 97, a mastery of 4 — so an assertion that a field survived cannot pass on
/// a coincidence with a default.
enum ArchiveFixture {

    static let date = Date(timeIntervalSince1970: 1_700_000_000)

    static func song(sourceID: String,
                     loops: [LoopRecord] = [],
                     references: [ReferenceLinkRecord] = []) -> SongRecord {
        SongRecord(sourceID: sourceID,
                   sourceRaw: "localFile",
                   title: "Slow Bend",
                   artist: "Jack Trader",
                   album: "Long Way Round",
                   genre: "Blues",
                   year: 1971,
                   key: "A",
                   comment: "The one with the turnaround.",
                   collections: ["Set list"],
                   bpm: 92,
                   preciseBPM: 92.4,
                   downbeatSeconds: 1.25,
                   extraDownbeatSeconds: [61.5],
                   beatsPerBar: 4,
                   noteValue: 4,
                   showsGridlines: true,
                   duration: 214.5,
                   dateAdded: date,
                   lastPracticed: date,
                   lastPracticedSpeed: 0.85,
                   audioFileName: "\(sourceID).m4a",
                   loops: loops,
                   markers: [MarkerRecord(uid: UUID(), seconds: 12.5, label: "Chorus")],
                   references: references)
    }

    static func loop(uid: UUID, references: [ReferenceLinkRecord] = []) -> LoopRecord {
        LoopRecord(uid: uid,
                   name: "Turnaround",
                   start: 0.25,
                   end: 0.4,
                   speed: 0.8,
                   repeats: 6,
                   loopTypeRaw: "phrase",
                   tags: ["bends"],
                   isFavorite: true,
                   isBackingTrack: false,
                   lastPracticedSpeed: 0.75,
                   mastery: 3,
                   masteryAtSpeed: 0.8,
                   focus: 2,
                   commandTempo: 88.5,
                   targetSpeedOverride: 0.95,
                   automatorEnabled: true,
                   automatorTargetSpeed: 1.0,
                   automatorStepCount: 5,
                   automatorLoopsPerStep: 3,
                   rampWarmupSteps: 1,
                   rampReachSteps: 4,
                   rampBackoffSteps: 2,
                   rampRepsPerStep: 3,
                   rampDwellIntervals: 2,
                   includeBackoff: true,
                   backoffSpeedOverride: 0.7,
                   colorIndex: 3,
                   customColorHex: "FF8800",
                   references: references)
    }

    static func exercise(uid: UUID, references: [ReferenceLinkRecord] = []) -> ExerciseRecord {
        ExerciseRecord(uid: uid,
                       name: "Spider walk",
                       notes: "Slow, even, no buzz.",
                       tags: ["warm-up"],
                       presetSlug: "spider-walk",
                       isFavorite: true,
                       dateAdded: date,
                       lastPracticed: date,
                       currentTempo: 97,
                       commandTempo: 104,
                       targetTempo: 120,
                       targetTempoOverride: 132,
                       beatsPerBar: 4,
                       noteValue: 4,
                       accentBeats: [0, 2],
                       subdivisionRaw: "eighth",
                       notesPerBeat: 2,
                       commandNotesPerBeat: 2,
                       templateRaw: "fretboard",
                       instrumentRaw: "guitar",
                       template: nil,
                       rampStepBPM: 4,
                       rampIntervalCount: 2,
                       rampIntervalUnitRaw: "bars",
                       dwellIntervals: 1,
                       includeBackoff: true,
                       rampReachSteps: 5,
                       rampBackoffSteps: 2,
                       backoffTempoOverride: 84,
                       awayFromInstrument: false,
                       clickEnabled: true,
                       clickBPM: 90,
                       mastery: 4,
                       masteryTempo: 108,
                       masteryNotesPerBeat: 2,
                       linkedSongIDs: ["song-1"],
                       references: references)
    }

    static func routine(uid: UUID, items: [RoutineItemRecord] = []) -> RoutineRecord {
        RoutineRecord(uid: uid,
                      name: "Morning warm-up",
                      notes: "The bits of week 3 that needed work.",
                      dateAdded: date,
                      lastPracticed: date,
                      isFavorite: true,
                      presetSlug: nil,
                      items: items,
                      references: [])
    }

    static func block(uid: UUID = UUID(),
                      order: Int,
                      kindRaw: String = "focused",
                      exerciseUID: UUID? = nil,
                      loopUID: UUID? = nil,
                      songSourceID: String? = nil,
                      orphanLabel: String? = nil) -> RoutineItemRecord {
        RoutineItemRecord(uid: uid,
                          order: order,
                          kindRaw: kindRaw,
                          reps: 3,
                          plannedMinutes: 12,
                          usesAuthoredLength: false,
                          recordsTake: true,
                          loopRunModeRaw: "practice",
                          exerciseUID: exerciseUID,
                          loopUID: loopUID,
                          songSourceID: songSourceID,
                          orphanLabel: orphanLabel)
    }

    static func take(uid: UUID,
                     fileName: String,
                     loopUID: UUID? = nil,
                     exerciseUID: UUID? = nil,
                     songSourceID: String? = nil) -> RecordingRecord {
        RecordingRecord(uid: uid,
                        createdAt: date,
                        duration: 42.5,
                        title: "Second pass",
                        note: "Rushed the turnaround.",
                        fileName: fileName,
                        ownerLabelAtTake: "Turnaround",
                        loopUID: loopUID,
                        exerciseUID: exerciseUID,
                        songSourceID: songSourceID,
                        moments: [TakeNoteRecord(uid: UUID(), time: 12.0, text: "here", createdAt: date)])
    }

    static func journalEntry(uid: UUID,
                             loopUID: UUID? = nil,
                             exerciseUID: UUID? = nil,
                             routineUID: UUID? = nil) -> JournalEntryRecord {
        JournalEntryRecord(uid: uid,
                           createdAt: date,
                           text: "Cleaner at 80.",
                           kindRaw: "note",
                           masteryAtEntry: 3,
                           commandTempoAtEntry: 0.8,
                           commandBpmAtEntry: 88,
                           commandNotesPerBeatAtEntry: 2,
                           loopUID: loopUID,
                           exerciseUID: exerciseUID,
                           routineUID: routineUID,
                           routineNameAtEntry: routineUID == nil ? nil : "Morning warm-up",
                           ownerLabelAtEntry: "Turnaround",
                           practisedUnits: nil,
                           isStandalone: false,
                           isMetronome: false,
                           metronomeBpmAtEntry: nil,
                           metronomeBeatsAtEntry: nil,
                           metronomeNoteValueAtEntry: nil,
                           metronomeSubdivisionRaw: nil,
                           metronomeWithdrawalRaw: nil)
    }

    static func reference(uid: UUID, attachmentFileName: String = "") -> ReferenceLinkRecord {
        ReferenceLinkRecord(uid: uid,
                            title: "Transcription",
                            note: "Bar 17 onwards.",
                            urlString: attachmentFileName.isEmpty ? "https://example.com/tab" : "",
                            order: 0,
                            dateAdded: date,
                            kindRaw: attachmentFileName.isEmpty ? "link" : "image",
                            attachmentFileName: attachmentFileName)
    }
}
