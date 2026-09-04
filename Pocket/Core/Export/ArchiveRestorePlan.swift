import Foundation

/// What is already in the library, by the keys an archive is joined on (ADR 0188 D1).
///
/// Read from the store once, on the main actor, and then handed to a pure planner. That split is the
/// same one `ArchiveBuilder` makes on the way out and for the same reason: the rule about what lands
/// is the part worth testing, and a rule that can only be exercised through a `ModelContext` is a rule
/// that gets tested against an in-memory container which does not behave like the real one.
///
/// **Songs are keyed on `sourceID`, everything else on `uid`** — `Song` is the one model with no uid
/// (`PracticeArchive`'s identity note), and `sourceID` is the name its audio file carries.
struct RestoreExistingKeys: Sendable, Equatable {
    var songSourceIDs: Set<String> = []
    var exerciseUIDs: Set<UUID> = []
    var savedChordUIDs: Set<UUID> = []
    var routineUIDs: Set<UUID> = []
    var goalUIDs: Set<UUID> = []
    var longTermGoalUIDs: Set<UUID> = []
    var runUIDs: Set<UUID> = []
    var journalUIDs: Set<UUID> = []
    var takeUIDs: Set<UUID> = []
    var hasProfile: Bool = false
}

/// What a restore will do, worked out before it does any of it (ADR 0188 D9).
///
/// Every number the confirmation sheet shows comes from here, and so does every decision the writer
/// makes. That is deliberate and is the same rule `ReceivedRoutine` follows: if the preview counted
/// one way and the write walked the records another, the preview would be a second opinion rather
/// than a promise.
struct RestorePlan: Sendable, Equatable {

    /// One row of the summary.
    struct Line: Sendable, Equatable, Identifiable {
        var kind: Kind
        /// Rows in the archive this library does not have.
        var landing: Int
        /// Rows the library already has, which will be **left exactly as they are** (D1, D6).
        var alreadyPresent: Int

        var id: Kind { kind }
        var total: Int { landing + alreadyPresent }
    }

    /// The kinds a restore counts, in the order the summary reads them.
    ///
    /// Their names are the app's own words for these things, not the model type names: a player has
    /// a *practice log*, not `PracticeRun`s (ADR 0176 renamed that screen, and the copy follows it).
    enum Kind: String, Sendable, CaseIterable, Identifiable {
        case songs, exercises, savedChords, routines, goals, longTermGoals, practiceLog, journal, takes

        var id: String { rawValue }

        var label: String {
            switch self {
            case .songs: return "Songs"
            case .exercises: return "Exercises"
            case .savedChords: return "Saved chords"
            case .routines: return "Routines"
            case .goals: return "Goals"
            case .longTermGoals: return "Long-term goals"
            case .practiceLog: return "Practice log"
            case .journal: return "Journal entries"
            case .takes: return "Takes"
            }
        }
    }

    /// Every kind that appears in the archive at all. Kinds the file has none of are left out rather
    /// than shown as zero — a summary of an archive from a player who keeps no journal should not
    /// spend a line saying so.
    var lines: [Line] = []

    /// Take audio that will be written out of the zip.
    var takeAudioLanding: Int = 0

    /// Takes that are landing as rows with no audio behind them.
    ///
    /// Not an error and worth saying: an export taken without audio, or one whose file was already
    /// gone (`ExportedArchive.takesMissing`), restores the take's note and its moments and cannot
    /// restore the recording. Silence here would look like a bug the first time a player noticed.
    var takeAudioMissing: Int = 0

    /// Songs landing whose audio this archive never carried — which is **every** song in it.
    ///
    /// Song audio is deliberately not exported (`SongRecord.audioFileName`): it is the player's own
    /// imported media, which they still have, and copying a library of it would multiply the size of
    /// a file whose point is the writing. So a restored song arrives with its loops, markers, tempo
    /// grid and notes intact and no audio attached, and the player relinks it (ADR 0152). This count
    /// exists so the sheet can say that before the restore rather than after.
    var songsNeedingRelink: Int = 0

    /// Whether the archive carries a profile this library does not have.
    var landsProfile: Bool = false

    /// Whether anything at all would happen.
    var isEmpty: Bool {
        lines.allSatisfy { $0.landing == 0 } && !landsProfile
    }

    /// Everything the archive holds that this library already has.
    var alreadyPresentCount: Int { lines.reduce(0) { $0 + $1.alreadyPresent } }

    /// Everything that will be added.
    var landingCount: Int { lines.reduce(0) { $0 + $1.landing } }
}

extension RestorePlan {

    /// Work out what an archive would do to a library (ADR 0188 D1, D9).
    ///
    /// Pure, and `nonisolated`: it takes the keys already read off the store rather than a context to
    /// read them from, so the skip rule can be tested over plain values.
    ///
    /// **Duplicates inside the file are counted once.** An archive this app wrote cannot contain two
    /// rows with one uid, and this door reads a file that may have been hand-edited or concatenated —
    /// counting a repeat twice would promise a number the writer then does not produce.
    nonisolated static func make(for archive: PracticeArchive,
                                 existing: RestoreExistingKeys,
                                 takeAudio: Set<String>) -> RestorePlan {
        var plan = RestorePlan()

        // Annotated rather than inferred. Nine generic calls in one array literal is the shape that
        // blew CI's type-check budget once already (a long inferred chain, ADR 0113-era) — local
        // Xcode has a bigger budget than CI's, so the annotation is free insurance rather than a
        // response to a measured problem.
        let lines: [Line?] = [
            line(.songs, keys: archive.songs.map(\.sourceID), existing: existing.songSourceIDs),
            line(.exercises, keys: archive.exercises.map(\.uid), existing: existing.exerciseUIDs),
            line(.savedChords, keys: archive.savedChords.map(\.uid), existing: existing.savedChordUIDs),
            line(.routines, keys: archive.routines.map(\.uid), existing: existing.routineUIDs),
            line(.goals, keys: archive.goals.map(\.uid), existing: existing.goalUIDs),
            line(.longTermGoals, keys: archive.longTermGoals.map(\.uid), existing: existing.longTermGoalUIDs),
            line(.practiceLog, keys: archive.practiceRuns.map(\.id), existing: existing.runUIDs),
            line(.journal, keys: archive.journal.map(\.uid), existing: existing.journalUIDs),
            line(.takes, keys: archive.takes.map(\.uid), existing: existing.takeUIDs)
        ]
        plan.lines = lines.compactMap { $0 }

        // Audio is counted only for the takes that are actually landing: a take the library already
        // has keeps the recording it already has, and re-writing the file would be work with no
        // effect at best and a truncated overwrite at worst.
        var seenTakes = Set<UUID>()
        for take in archive.takes where !existing.takeUIDs.contains(take.uid) && seenTakes.insert(take.uid).inserted {
            if takeAudio.contains(take.fileName) { plan.takeAudioLanding += 1 } else { plan.takeAudioMissing += 1 }
        }

        var seenSongs = Set<String>()
        plan.songsNeedingRelink = archive.songs
            .filter { !existing.songSourceIDs.contains($0.sourceID) && seenSongs.insert($0.sourceID).inserted }
            .count

        plan.landsProfile = archive.profile != nil && !existing.hasProfile
        return plan
    }

    /// One summary row, or `nil` when the archive holds none of this kind.
    private nonisolated static func line<Key: Hashable>(_ kind: Kind,
                                                        keys: [Key],
                                                        existing: Set<Key>) -> Line? {
        var seen = Set<Key>()
        var landing = 0
        var present = 0
        for key in keys where seen.insert(key).inserted {
            if existing.contains(key) { present += 1 } else { landing += 1 }
        }
        guard landing + present > 0 else { return nil }
        return Line(kind: kind, landing: landing, alreadyPresent: present)
    }
}
