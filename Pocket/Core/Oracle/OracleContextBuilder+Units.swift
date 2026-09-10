import Foundation

/// The unit, note and goal halves of the context build (ADR 0187 D6).
///
/// Split from `OracleContextBuilder` for the 400-line rule, and along the seam where the rules
/// differ: the file above holds the budget (R4) and the effort roll-up (R6), which are arithmetic;
/// this one holds what is *allowed to be named* (R1, R2, R3, R5, R7), which is the privacy half.
@MainActor
extension OracleContextBuilder {

    /// A drill or loop reduced to what the context is allowed to know about it.
    ///
    /// The two model types are flattened into one shape here rather than branched over four times
    /// below. **What is absent is the point**: a `Loop` belongs to a `Song`, and neither the song's
    /// title nor its artist nor its file name appears in this struct, so no later edit can reach
    /// them without adding a field and tripping a test (D6 R2).
    struct UnitSnapshot {
        let uid: UUID
        let name: String
        let kind: OracleContext.UnitKind
        let template: String?
        let mastery: Int?
        /// Loops only (ADR 0204). Defaulted so the exercise branch below stays a five-field call and
        /// so a drill can never acquire marks by an edit that forgets to say it did not mean to.
        var snags: [OracleContext.SnagMark] = []
        var droppedSnags: Int = 0
        var spans: [OracleContext.SpanEdit] = []
        var droppedSpans: Int = 0
        var runsInCurrentSpan: Int = 0
    }

    /// The units this reading is about: everything practised in the window, plus everything written
    /// about in it.
    ///
    /// The second half matters. A drill the player wrote a note about but did not log a run for is
    /// exactly the drill a reflection has something to say about, and selecting on the log alone
    /// would drop it.
    ///
    /// Ordered by minutes practised (descending), then name, then `uid` — deterministic to the last
    /// tie, because the handles in D6 R1 are minted from this order.
    static func selectUnits(from source: OracleContextSource,
                            records: [SessionRecord],
                            window: DateInterval) -> [UnitSnapshot] {
        var wanted = Set(records.compactMap(\.unitUID))
        for entry in source.journal where window.contains(entry.createdAt) {
            if let exercise = entry.exercise { wanted.insert(exercise.uid) }
            if let loop = entry.loop { wanted.insert(loop.uid) }
        }
        for take in source.takes where window.contains(take.createdAt) {
            if let exercise = take.exercise { wanted.insert(exercise.uid) }
            if let loop = take.loop { wanted.insert(loop.uid) }
        }

        var snapshots: [UnitSnapshot] = []
        for exercise in source.exercises where wanted.contains(exercise.uid) {
            snapshots.append(UnitSnapshot(uid: exercise.uid,
                                          name: truncate(exercise.name, to: OracleContextBudget.unitNameCap).text,
                                          kind: .exercise,
                                          template: exercise.template.rawValue,
                                          mastery: exercise.mastery))
        }
        for loop in source.loops where wanted.contains(loop.uid) {
            let marks = snagMarks(in: loop)
            // Full history, not `records`: a span that has stood since March did not start standing
            // on Monday, and the epoch counts would otherwise all be counts of this week.
            let epochs = spanEpochs(of: loop, in: source.records)
            snapshots.append(UnitSnapshot(uid: loop.uid,
                                          name: truncate(loop.name, to: OracleContextBudget.unitNameCap).text,
                                          kind: .loop,
                                          template: nil,
                                          mastery: loop.mastery,
                                          snags: marks.kept,
                                          droppedSnags: marks.dropped,
                                          spans: epochs.edits,
                                          droppedSpans: epochs.dropped,
                                          runsInCurrentSpan: epochs.runsInCurrentSpan))
        }

        let minutesByUID = minutes(byUnitIn: records)
        let ordered = snapshots.sorted { lhs, rhs in
            let leftMinutes = minutesByUID[lhs.uid] ?? 0
            let rightMinutes = minutesByUID[rhs.uid] ?? 0
            if leftMinutes != rightMinutes { return leftMinutes > rightMinutes }
            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return lhs.uid.uuidString < rhs.uid.uuidString
        }
        return Array(ordered.prefix(OracleContextBudget.maxUnits))
    }

    /// One unit, with its window-scoped effort and its full-history tempo trajectory.
    ///
    /// The two scopes are deliberate and different. Runs and minutes describe **the period being
    /// read**, because that is what the reading is about. The trajectory is drawn from the whole
    /// log, because a tempo history that started before Monday did not start on Monday, and a
    /// window-clipped trajectory would show a line that appears to begin wherever the request did.
    static func unit(_ snapshot: UnitSnapshot,
                     handle: String,
                     records: [SessionRecord],
                     allRecords: [SessionRecord]) -> OracleContext.Unit {
        let mine = records.filter { $0.unitUID == snapshot.uid }
        let minutes = Int((mine.reduce(0) { $0 + $1.durationSeconds } / 60).rounded())
        return OracleContext.Unit(handle: handle,
                                  name: snapshot.name,
                                  kind: snapshot.kind,
                                  template: snapshot.template,
                                  mastery: snapshot.mastery,
                                  tempo: tempo(for: snapshot.uid, in: allRecords),
                                  runs: mine.count,
                                  minutes: minutes,
                                  lastPractisedOn: mine.map(\.startedAt).max(),
                                  snags: snapshot.snags,
                                  droppedSnags: snapshot.droppedSnags,
                                  spans: snapshot.spans,
                                  droppedSpans: snapshot.droppedSpans,
                                  runsInCurrentSpan: snapshot.runsInCurrentSpan)
    }

    // MARK: - Snags and spans (ADR 0204)

    /// The marks inside this loop's **current** span, as offsets from its start (ADR 0204 D1).
    ///
    /// Filtered by **position, not by `Snag.loopUID`** — the rule ADR 0203 D1 settled for the
    /// waveform's fade and `SnagCluster.proposal` has always used. A mark made under a wider version
    /// of this loop, or under a neighbouring one, is still a mark on this passage; the loop it was
    /// tapped under is an accident of which one happened to be armed. Reading it the other way would
    /// put a different set of marks in the payload than the one the player can see on the canvas.
    ///
    /// Full history, not window-scoped, for the reason `tempo` is: a passage that has given trouble
    /// since March did not start giving trouble on Monday, and a window-clipped map would show a
    /// song that appears to have gone wrong only inside the request.
    ///
    /// This reaches `loop.song` — the one place the builder does — and takes **the duration and the
    /// marks, nothing else**. The title, artist and file name are as out of scope after this call as
    /// before it, because `UnitSnapshot` has nowhere to put them (D6 R2).
    static func snagMarks(in loop: Loop) -> (kept: [OracleContext.SnagMark], dropped: Int) {
        guard let song = loop.song, song.duration > 0 else { return ([], 0) }
        let start = loop.startSeconds
        let end = loop.endSeconds
        guard end > start else { return ([], 0) }

        let inside = song.snags.filter { $0.seconds >= start && $0.seconds <= end }
        // Over the cap the **oldest** go, because a passage's recent trouble is the live reading.
        let newestFirst = inside.sorted { lhs, rhs in
            if lhs.markedAt != rhs.markedAt { return lhs.markedAt > rhs.markedAt }
            return lhs.uid.uuidString < rhs.uid.uuidString
        }
        let kept = Array(newestFirst.prefix(OracleContextBudget.maxSnagsPerUnit))
        // Sent in **playing order**, which is the panel's own order (ADR 0202 D2) and the order that
        // makes a cluster legible as a cluster. `uid` breaks the tie and never crosses (D6 R1).
        let marks = kept
            .sorted { lhs, rhs in
                if lhs.seconds != rhs.seconds { return lhs.seconds < rhs.seconds }
                return lhs.uid.uuidString < rhs.uid.uuidString
            }
            .map { OracleContext.SnagMark(atSeconds: $0.seconds - start,
                                          markedOn: $0.markedAt,
                                          speed: $0.speed) }
        return (marks, inside.count - kept.count)
    }

    // What this loop's span has done, oldest first (ADR 0204 D2), now lives next door in
    // `OracleContextBuilder+Shape.swift` as `spanEpochs(of:in:)` — because ADR 0187 D22 needs each
    // row to carry the runs logged while that span stood, which is a join against the practice log
    // and no longer a read of the loop alone.
    //
    // What did not change, and is the half most likely to be undone by accident: the widths are
    // **in seconds**, taken from each row's own recorded `songDuration` rather than the song's
    // current one, because `LoopSpanChange` stores the duration at write time precisely so a span
    // reads back the same after a relink (ADR 0152). Fractions were the alternative and are worse:
    // "0.04 of the song" is unreadable without the song, and the song is exactly what does not
    // travel (D6 R2).

    /// The trajectory, rhythm-scoped, capped from the **old** end (D6 R7).
    ///
    /// `TempoTrajectory.reading` already does the hard half: it covers exactly one note rate, picks
    /// the rate most recently practised, and counts what it set aside instead of dropping it
    /// quietly. Its computed `change` / `first` / `latest` are not read here — R5 and R6 keep
    /// derived values on this side of the wire, and a change in BPM is a derived value one adjective
    /// away from "regressed".
    ///
    /// `nil` when there is no trajectory to draw. A single point is not a trajectory, and the
    /// underlying type already refuses to return one rather than implying a direction from it.
    static func tempo(for unitUID: UUID, in records: [SessionRecord]) -> OracleContext.Tempo? {
        guard let reading = TempoTrajectory.reading(for: unitUID, in: records) else { return nil }
        let points = reading.points.suffix(OracleContextBudget.maxTempoPoints)
        return OracleContext.Tempo(points: points.map { .init(date: $0.date, bpm: $0.bpm) },
                                   notesPerBeat: reading.noteRate?.perBeat,
                                   otherRhythmRuns: reading.otherRhythmRuns)
    }

    // MARK: - Notes

    /// Journal entries and take notes written inside the window, as one feed.
    ///
    /// They are one feed on the screen already (ADR 0190) and they are one feed here for the same
    /// reason: what the player wrote about a session and what they wrote against a recording of it
    /// are the same kind of material. A take's `title` and `fileName` do **not** cross (D6 R2) —
    /// only what was written.
    ///
    /// Empty text is skipped rather than sent as a blank line: a note with nothing in it is a row
    /// on a screen, not a thought to reflect on.
    static func notes(from source: OracleContextSource,
                      window: DateInterval,
                      handleByUID: [UUID: String]) -> [OracleContext.Note] {
        var notes: [OracleContext.Note] = []

        for entry in source.journal where window.contains(entry.createdAt) {
            let cut = truncate(entry.text, to: OracleContextBudget.noteTextCap)
            guard !cut.text.isEmpty else { continue }
            notes.append(OracleContext.Note(writtenOn: entry.createdAt,
                                            text: cut.text,
                                            unitHandle: handle(for: entry, in: handleByUID),
                                            kind: entry.kindRaw,
                                            wasTruncated: cut.wasTruncated))
        }

        for take in source.takes where window.contains(take.createdAt) {
            let cut = truncate(take.note ?? "", to: OracleContextBudget.noteTextCap)
            guard !cut.text.isEmpty else { continue }
            notes.append(OracleContext.Note(writtenOn: take.createdAt,
                                            text: cut.text,
                                            unitHandle: handle(for: take, in: handleByUID),
                                            kind: OracleContext.takeNoteKind,
                                            wasTruncated: cut.wasTruncated))
        }

        return notes
    }

    private static func handle(for entry: JournalEntry, in handleByUID: [UUID: String]) -> String? {
        if let exercise = entry.exercise { return handleByUID[exercise.uid] }
        if let loop = entry.loop { return handleByUID[loop.uid] }
        return nil
    }

    private static func handle(for take: Recording, in handleByUID: [UUID: String]) -> String? {
        if let exercise = take.exercise { return handleByUID[exercise.uid] }
        if let loop = take.loop { return handleByUID[loop.uid] }
        return nil
    }

    // MARK: - Goals

    /// Both horizons, session goals first, each in the order the app itself ranks them.
    ///
    /// `window` is unused and the parameter is not taken: neither `Goal` nor `LongTermGoal` records
    /// *when* it was met, only that it was, so a `metInWindow` flag could only ever have been
    /// `false`. A field that is always false is worse than an absent one — it reads as evidence.
    ///
    /// `Goal.weight` is **not** sent. It is a planner input — the number that decides how often a
    /// goal's skills come up — and reading it as importance is exactly the misreading that would
    /// turn "you weighted this 0.4" into a comment about commitment. A long-term goal's `order` is
    /// sent, because ADR 0171 makes rank the player's own stated priority.
    static func goalLines(from source: OracleContextSource) -> [OracleContext.GoalLine] {
        var lines: [OracleContext.GoalLine] = []
        for goal in source.goals.sorted(by: { $0.dateAdded < $1.dateAdded }) {
            let title = truncate(goal.title, to: OracleContextBudget.goalTitleCap).text
            guard !title.isEmpty else { continue }
            lines.append(OracleContext.GoalLine(title: title,
                                                rank: nil,
                                                isMet: goal.isMet,
                                                horizon: .session))
        }
        for goal in source.longTermGoals.sorted(by: { $0.order < $1.order }) {
            let title = truncate(goal.title, to: OracleContextBudget.goalTitleCap).text
            guard !title.isEmpty else { continue }
            lines.append(OracleContext.GoalLine(title: title,
                                                rank: goal.order,
                                                isMet: goal.isMet,
                                                horizon: .longTerm))
        }
        return lines
    }

    // MARK: - Shared

    private static func minutes(byUnitIn records: [SessionRecord]) -> [UUID: Int] {
        var seconds: [UUID: Double] = [:]
        for record in records {
            guard let unitUID = record.unitUID else { continue }
            seconds[unitUID, default: 0] += record.durationSeconds
        }
        return seconds.mapValues { Int(($0 / 60).rounded()) }
    }
}
