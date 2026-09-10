import Foundation

/// The **shape** half of the context build (ADR 0187 D22) — the order units were taken in, and how
/// long a span stood before it was moved.
///
/// Split from `OracleContextBuilder+Units` along the seam D22 draws. The file next door answers
/// *what is allowed to be named*; this one answers *what happened, in what order*, which is the
/// material the revised mirror opens on. Both are pure functions of records and models, and both
/// are `@MainActor` for the same reason: a `@Model` is not `Sendable`, and what comes out is.
///
/// ### The rule these functions exist to satisfy
///
/// D22, restated: a **structural fact** names *what and where*; an **evaluation** names *how much,
/// relative to something else*. If a value is meaningless without a second value, it is a
/// comparison and it does not cross. Nothing here computes a rate, a ratio, an average or a delta,
/// and the two counts that do cross — runs per span epoch — are counts of a thing that happened,
/// not of a thing that was expected.
@MainActor
extension OracleContextBuilder {

    // MARK: - The order units were taken in

    /// Runs grouped into sittings, oldest first, each group in the order its runs started.
    ///
    /// The rule is `PracticeLog`'s: a gap of `PracticeLog.sittingGap` since the **previous run's
    /// end** starts a new sitting. Measuring from the end rather than the start is what keeps a
    /// long block followed immediately by another from splitting in two, and `PracticeLogTests`
    /// pins it.
    ///
    /// Reimplemented here rather than borrowed because `PracticeLog.Sitting` carries `startedAt`,
    /// `endedAt`, `seconds` and `runCount` and **no member list** — it was built to summarise a
    /// sitting, and this needs to walk one.
    static func sittingGroups(in records: [SessionRecord]) -> [[SessionRecord]] {
        let ordered = records.sorted { lhs, rhs in
            if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        guard var previousEnd = ordered.first?.endedAt else { return [] }

        var groups: [[SessionRecord]] = [[]]
        for record in ordered {
            if !(groups[groups.count - 1].isEmpty),
               record.startedAt.timeIntervalSince(previousEnd) >= PracticeLog.sittingGap {
                groups.append([])
            }
            groups[groups.count - 1].append(record)
            previousEnd = max(previousEnd, record.endedAt)
        }
        return groups
    }

    /// The sittings, as sequences of D6 R1 handles (D22).
    ///
    /// Three shaping decisions, each of which changes what the reading can say:
    ///
    /// 1. **Consecutive repeats collapse; a return does not.** A routine block logs one row per
    ///    run, so three runs of a warm-up in a row would print as *"the warm-up, the warm-up, the
    ///    warm-up"* — which is volume wearing the clothes of order. `A A A B A` becomes `A B A`,
    ///    and the second `A` survives because coming *back* to something is the shape D22 is
    ///    after. The run count itself is untouched on `Unit.runs`.
    /// 2. **A run whose unit is not in the context is dropped, not blanked.** Routine-level rows
    ///    carry no `unitUID`, and a unit past `maxUnits` has no handle; either way there is no
    ///    honest token to print, and a gap character would invite the reader to guess at one.
    /// 3. **A sitting with nothing nameable left is dropped entirely** — an empty sequence says
    ///    nothing and reads as a fault.
    static func sittings(from groups: [[SessionRecord]],
                         handleByUID: [UUID: String]) -> [OracleContext.Sitting] {
        let built: [OracleContext.Sitting] = groups.compactMap { group in
            guard let startedOn = group.first?.startedAt else { return nil }
            var handles: [String] = []
            for record in group {
                guard let uid = record.unitUID, let handle = handleByUID[uid] else { continue }
                guard handle != handles.last else { continue }
                handles.append(handle)
            }
            guard !handles.isEmpty else { return nil }
            return OracleContext.Sitting(startedOn: startedOn,
                                         handles: Array(handles.prefix(OracleContextBudget.maxUnitsPerSitting)))
        }
        // Dropped from the **old** end: a week is read forwards from where the player is now, so
        // the recent sittings are the ones worth keeping (the `maxTempoPoints` rule).
        return Array(built.suffix(OracleContextBudget.maxSittings))
    }

    // MARK: - How long a span stood

    /// A loop's span history with the runs that happened inside each version of it (ADR 0204 D2,
    /// ADR 0187 D22).
    ///
    /// ### The join
    ///
    /// Every `LoopSpanChange.changedAt` **closes an epoch**. The runs belonging to the epoch a row
    /// closed are those logged against this loop between the previous row's `changedAt` and this
    /// one's; the runs since the last row belong to the epoch still open, which has no row to sit
    /// on and is returned separately. `LoopSpanChange` already stores both widths precisely so a
    /// row stands alone (ADR 0199), and attaching the count to the row keeps that property.
    ///
    /// ### Two edges this does not pretend to have solved
    ///
    /// ADR 0199 writes **no row at loop creation**, so the oldest epoch has no start marker and its
    /// count reaches back to the first run ever logged. A loop that predates 0199 has no rows at
    /// all, and so is all current epoch. Both are honest — a count of runs that happened is still a
    /// count of runs that happened — but neither is a window.
    ///
    /// Rows with no recorded `songDuration` cannot be expressed in seconds and are dropped, as they
    /// were before D22. They now **count toward `dropped`**: a row that vanishes takes its epoch's
    /// runs with it, and a list that looked complete would silently pour three epochs of runs into
    /// two.
    static func spanEpochs(of loop: Loop, in allRecords: [SessionRecord]) -> SpanEpochs {
        let runs = allRecords
            .filter { $0.unitUID == loop.uid }
            .map(\.startedAt)
            .sorted()

        // Oldest first: an epoch is bounded by the row before it, so the walk has to run forwards.
        let oldestFirst = loop.spanChanges.sorted { lhs, rhs in
            if lhs.changedAt != rhs.changedAt { return lhs.changedAt < rhs.changedAt }
            return lhs.uid.uuidString < rhs.uid.uuidString
        }

        var edits: [OracleContext.SpanEdit] = []
        var dropped = 0
        var epochStart = Date.distantPast
        for change in oldestFirst {
            let closedAt = change.changedAt
            let inEpoch = runs.filter { $0 >= epochStart && $0 < closedAt }.count
            // The epoch closes whether or not the row survives — an unusable row still marks the
            // moment the span moved. Its runs are then genuinely lost, which is what `dropped` is
            // for: they must not silently join the next epoch's count.
            epochStart = closedAt
            guard (change.songDuration ?? 0) > 0,
                  let after = change.widthSeconds,
                  let before = change.previousWidthSeconds else {
                dropped += 1
                continue
            }
            edits.append(OracleContext.SpanEdit(changedOn: closedAt,
                                                fromSeconds: before,
                                                toSeconds: after,
                                                speed: change.speed,
                                                runsInPreviousSpan: inEpoch))
        }

        let current = runs.filter { $0 >= epochStart }.count
        // Over the cap the **oldest** rows go — a span history is a trajectory, read from where it
        // is now (`maxSpanEditsPerUnit` says why it differs from the snag map).
        let kept = edits.suffix(OracleContextBudget.maxSpanEditsPerUnit)
        return SpanEpochs(edits: Array(kept),
                          dropped: dropped + (edits.count - kept.count),
                          runsInCurrentSpan: current)
    }

    /// What `spanEpochs(of:in:)` returns — three values that only mean anything together.
    ///
    /// A named type rather than a tuple because the third is easy to mistake for the second: one
    /// counts *edits that did not make it into the payload*, the other counts *runs since the last
    /// edit that did*. Labelled fields make a call site that swaps them fail to compile.
    struct SpanEpochs {
        let edits: [OracleContext.SpanEdit]
        let dropped: Int
        let runsInCurrentSpan: Int
    }
}
