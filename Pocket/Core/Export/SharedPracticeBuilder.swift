import Foundation

/// Turns one live `Routine` into the payload of a `.redmoonpractice` file (ADR 0188 S1).
///
/// `@MainActor` for `ArchiveBuilder`'s reason and no other: reading a `@Model` is main-actor work and
/// neither a model nor a `ModelContext` is `Sendable`. What it returns is a plain value, so the
/// encoding happens wherever the share sheet asks for it.
///
/// ### What this is not
///
/// It is not an export of a routine. An export records what the player has done; a share hands over
/// what they *made*, to somebody who has done none of it. Every difference below is one or the other
/// of those two sentences.
@MainActor
enum SharedPracticeBuilder {

    /// Build the file's payload for `routine`.
    ///
    /// Reuses `ArchiveBuilder`'s record mapping wholesale and then subtracts, rather than mapping a
    /// second time by hand. That is on purpose: a field added to `ExerciseRecord` reaches this path
    /// automatically, and the only way it can be wrong is by being carried when it should not be —
    /// which is a decision, visible here as a line, instead of an omission nobody notices.
    static func routine(_ routine: Routine, appVersion: String,
                        exportedAt: Date = .now) -> SharedPractice {
        let blocks = routine.orderedItems

        var record = ArchiveBuilder.routineRecord(routine)
        // Facts about the sender's practice, not about the routine (D4). `lastPracticed` would tell
        // the receiver they ran a session they have never seen; the pin and the preset slug are about
        // a row in a library that is not theirs.
        record.lastPracticed = nil
        record.isFavorite = false
        record.presetSlug = nil
        // Where the sender kept it is not part of the routine (ADR 0210 D8) — the same call
        // `shareable(_ exercise:)` makes, for the same reason.
        record.folders = nil
        // References do not cross in S1. Half of them are attachments (ADR 0167 phase 2) whose bytes
        // stay on the sender's device, and carrying only the URL-backed half would be a decision
        // ADR 0188's D4 table does not make. A link that ought to travel can be added here in one
        // line once that call is made.
        record.references = []
        record.items = record.items.map(shareable)

        var seen = Set<UUID>()
        let exercises = blocks
            .compactMap(\.exercise)
            .filter { seen.insert($0.uid).inserted }
            // `ArchiveBuilder`'s order for exercises, for its reason: a stable file is one two people
            // can diff. The same drill used by three blocks is written once.
            .sorted { ($0.name, $0.uid.uuidString) < ($1.name, $1.uid.uuidString) }
            .map(shareable)

        return SharedPractice(exportedAt: exportedAt,
                              appVersion: appVersion,
                              routine: record,
                              exercises: exercises,
                              placeholders: blocks.compactMap(placeholder))
    }

    /// Build the file's payload for one drill on its own (ADR 0209 D1).
    ///
    /// Almost nothing to it, and that is the finding rather than an apology for a thin function: the
    /// hard question — what a drill loses when it crosses to somebody who has practised none of it —
    /// was answered once by `shareable(_ exercise:)` for the routine door, and a drill sent on its
    /// own is the same drill under the same argument. Any subtraction added here and not there would
    /// mean the same file said two different things depending on how it was sent.
    ///
    /// `notes` is a parameter rather than read off the model because the sheet that sends a drill
    /// keeps its description in `@State` until Done (ADR 0209 D3). `nil` — the default, and what a
    /// test or any other caller passes — takes the model's own.
    static func exercise(_ exercise: Exercise, appVersion: String,
                         notes: String? = nil, exportedAt: Date = .now) -> SharedPractice {
        var record = shareable(exercise)
        if let notes { record.notes = notes }
        return SharedPractice(kindRaw: SharedPracticeKind.exercise.rawValue,
                              exportedAt: exportedAt,
                              appVersion: appVersion,
                              routine: nil,
                              exercises: [record])
    }

    /// A block with the ids that mean nothing elsewhere removed (D1).
    ///
    /// `exerciseUID` stays: the exercise travels inline in the same file, so within this payload the
    /// uid is a real join key. `loopUID` and `songSourceID` do not travel with anything, and leaving
    /// them in would invite a receiver to resolve them against its own store — the one thing an
    /// untrusted file must never be allowed to do. What the block pointed at is said in words instead,
    /// by `placeholder(for:)`.
    static func shareable(_ item: RoutineItemRecord) -> RoutineItemRecord {
        var copy = item
        copy.loopUID = nil
        copy.songSourceID = nil
        return copy
    }

    /// A received exercise arrives the way a duplicated one does (D5).
    ///
    /// `Exercise.duplicated(named:)` already drops `mastery`, `lastPracticed`, `isFavorite`,
    /// `presetSlug`, journal and recordings, for reasons that hold at least as strongly across two
    /// people as within one library. This drops **two more** that a same-library duplicate keeps:
    ///
    /// - `commandTempo` / `commandNotesPerBeat`, because ADR 0045 defines the command tempo as a
    ///   *measured* number. Inheriting the sender's would hand the receiver a grade with somebody
    ///   else's name on it, which ADR 0070 rules out on the app's own side and should not permit
    ///   through a side door.
    /// - `linkedSongIDs`, which name songs by `sourceID` — files on the sender's phone (ADR 0148).
    ///
    /// The teacher's *shape* crosses: the drill, the rhythm, the ramp, the notes. The teacher's
    /// *achievement* does not.
    ///
    /// **Nor does the teacher's filing** (ADR 0210 D8). A drill sent on its own arrives unfiled: its
    /// paths are positions in *the sender's* tree — `Students/2026/Beginner/Warm-ups` — and
    /// reproducing that on a stranger's phone would be handing over a filing cabinet along with the
    /// drill. Sharing a whole folder is a different act with a different answer (D11 rebases the tree
    /// onto the shared root rather than dropping it).
    ///
    /// The drill's own `tags` cross exactly as they did before folders existed. An earlier cut added
    /// the folders' leaf names to them, which was harmless while `tags` was a retired column and
    /// stopped being so the moment it was not: it would put the sender's filing vocabulary into the
    /// receiver's tags, on a field they can see and did not write.
    static func shareable(_ exercise: Exercise) -> ExerciseRecord {
        var record = ArchiveBuilder.exerciseRecord(exercise)
        record.folders = nil
        record.lastPracticed = nil
        record.isFavorite = false
        record.presetSlug = nil
        record.mastery = nil
        record.masteryTempo = nil
        record.masteryNotesPerBeat = nil
        record.commandTempo = nil
        record.commandNotesPerBeat = nil
        record.linkedSongIDs = []
        record.references = []
        return record
    }

    /// What a loop or song block was, for a receiver who cannot have it (D4).
    ///
    /// `nil` for everything else — an exercise block carries its unit inline, and a rest has none.
    ///
    /// **An already-orphaned block is the exception it looks like, and only sometimes.** A block
    /// orphaned by a *deletion* has nothing left to name and gets no placeholder, as it always did.
    /// A block that arrived as a named orphan does (`orphanLabel`, the S2 follow-up), so forwarding
    /// a routine somebody sent you keeps the labels rather than degrading them one hop at a time.
    static func placeholder(for item: RoutineItem) -> SharedBlockPlaceholder? {
        let label: String
        if let loop = item.loop {
            label = [loop.name, loop.song?.title]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " — ")
            return SharedBlockPlaceholder(itemUID: item.uid,
                                          label: label.isEmpty ? "Loop" : label)
        }
        if let song = item.song {
            label = song.title.trimmingCharacters(in: .whitespaces)
            return SharedBlockPlaceholder(itemUID: item.uid,
                                          label: label.isEmpty ? "Song" : label)
        }
        if let carried = item.orphanLabel?.trimmingCharacters(in: .whitespaces), !carried.isEmpty {
            return SharedBlockPlaceholder(itemUID: item.uid, label: carried)
        }
        return nil
    }
}
