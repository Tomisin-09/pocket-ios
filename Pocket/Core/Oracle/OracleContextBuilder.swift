import Foundation

/// Turns the live store into an `OracleContext` under the seven rules of ADR 0187 D6.
///
/// **Every rule here is a test, not a habit** — the ADR 0181 D3 pattern. The rules, restated so
/// that changing this file means changing a numbered decision:
///
/// 1. No `uid`s cross. Units get per-request handles (`u1`, `u2`) and the map stays client-side.
/// 2. No song titles, artist names, file names or attachment names.
/// 3. No `artistName`. If a reading addresses the player by name, the **client** interpolates it.
/// 4. Every free-text field truncated to a stated cap, with a total payload budget. Over budget,
///    drop oldest whole notes — never silently clip the set.
/// 5. Stored properties only, never computed ones.
/// 6. No computed judgement crosses. Effort is counts, minutes and dates.
/// 7. A tempo never travels without its note rate, and `otherRhythmRuns` travels with it.
///
/// `@MainActor`, because reading a `@Model` is main-actor work and neither a model nor a
/// `ModelContext` is `Sendable`. What it returns *is* `Sendable`, which is the point: the request
/// is encoded and sent off the main actor with nothing but plain values in hand.
///
/// ### Determinism
///
/// Every collection is sorted, and none of them by chance. Two builds over an unchanged store must
/// produce identical output, or an eval fixture (D17) cannot be asserted against and a handle map
/// cannot be reasoned about. `uid` breaks every tie — never `persistentModelID` (ADR 0090).
@MainActor
enum OracleContextBuilder {

    /// The context, plus the half of R1 that stays behind.
    struct Build {
        let context: OracleContext
        /// `handle` → the real `uid`. **Never sent, and never encoded** — this is the client-side
        /// half of D6 R1, and the reason a hallucinated unit in a proposal is a dictionary miss
        /// rather than a judgement call (D7).
        let handles: [String: UUID]
    }

    /// Build the context for one reading.
    ///
    /// `window` is the period being read (D15). `now` is injected rather than read, so the whole
    /// builder is a pure function of its inputs and a test does not race the clock.
    static func build(from source: OracleContextSource,
                      window: DateInterval,
                      promptVersion: String,
                      now: Date = .now,
                      calendar: Calendar = .current) -> Build {

        let records = PracticeLog.records(in: window, from: source.records)
        let units = selectUnits(from: source, records: records, window: window)

        var handles: [String: UUID] = [:]
        var handleByUID: [UUID: String] = [:]
        for (index, unit) in units.enumerated() {
            let handle = "u\(index + 1)"
            handles[handle] = unit.uid
            handleByUID[unit.uid] = handle
        }

        var context = OracleContext(promptVersion: promptVersion,
                                    generatedAt: now,
                                    windowStart: window.start,
                                    windowEnd: window.end)
        context.units = units.map { unit in
            self.unit(unit, handle: handleByUID[unit.uid] ?? "", records: records, allRecords: source.records)
        }
        context.goals = goalLines(from: source)
        context.effort = effort(from: records, calendar: calendar)

        let allNotes = notes(from: source, window: window, handleByUID: handleByUID)
        let spentOnUnitsAndGoals = context.units.reduce(0) { $0 + $1.name.count }
            + context.goals.reduce(0) { $0 + $1.title.count }
        let (kept, dropped) = fitToBudget(allNotes, alreadySpent: spentOnUnitsAndGoals)
        context.notes = kept
        context.droppedNotes = dropped

        return Build(context: context, handles: handles)
    }

    // MARK: - R4, the budget

    /// Fit the notes inside `OracleContextBudget.totalFreeTextBudget`, **dropping oldest whole
    /// notes** until they fit (D6 R4).
    ///
    /// The alternative — clipping every note a little further — is rejected because it leaves the
    /// set looking complete while the sentences inside it stop mid-word. A model handed forty
    /// half-notes reads forty half-thoughts; a model handed twelve whole ones and told twenty-eight
    /// were dropped reads twelve thoughts and one caveat. Only the second is honest.
    ///
    /// Returns the kept notes **oldest-first**, which is reading order: a reflection over a period
    /// runs forwards through it.
    static func fitToBudget(_ notes: [OracleContext.Note],
                            alreadySpent: Int) -> (kept: [OracleContext.Note], dropped: Int) {
        // Newest-first so the drop falls off the far end, then reversed back for the caller.
        var newestFirst = notes.sorted { lhs, rhs in
            if lhs.writtenOn != rhs.writtenOn { return lhs.writtenOn > rhs.writtenOn }
            return lhs.text < rhs.text
        }
        if newestFirst.count > OracleContextBudget.maxNotes {
            newestFirst = Array(newestFirst.prefix(OracleContextBudget.maxNotes))
        }

        var spent = alreadySpent
        var kept: [OracleContext.Note] = []
        for note in newestFirst {
            let cost = note.text.count
            guard spent + cost <= OracleContextBudget.totalFreeTextBudget else { continue }
            spent += cost
            kept.append(note)
        }
        return (kept.reversed(), notes.count - kept.count)
    }

    /// Truncate one free-text field to a stated cap (D6 R4), reporting whether it had to.
    ///
    /// Cuts on a character count rather than a word boundary deliberately: a boundary-aware cut is
    /// locale-dependent, and this value has to be identical on every device for a fixture to hold.
    static func truncate(_ text: String, to cap: Int) -> (text: String, wasTruncated: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > cap else { return (trimmed, false) }
        return (String(trimmed.prefix(cap)), true)
    }

    // MARK: - R6, effort

    /// Counts, minutes and dates. **Nothing derived** (D6 R6).
    ///
    /// There is no streak here, no consistency score, no days-since, no delta and no average, and
    /// none of them is an oversight. `PracticeLog` already refuses to compute a target, a
    /// denominator or a streak; this is the boundary where that refusal has to hold on the way out
    /// of the app, because the receiving end will happily compute one from whatever it is given.
    /// Handing over a list of days is handing over a fact. Handing over "5 of the last 7" is
    /// handing over a grade with a number attached.
    static func effort(from records: [SessionRecord], calendar: Calendar) -> OracleContext.Effort {
        var effort = OracleContext.Effort()
        effort.runs = records.count
        effort.minutes = Int((records.reduce(0) { $0 + $1.durationSeconds } / 60).rounded())
        let days = Set(records.map { calendar.startOfDay(for: $0.startedAt) })
        effort.daysPractised = days.sorted()
        effort.sittings = sittings(in: records)
        return effort
    }

    /// Sittings as `PracticeLog` counts them — a gap of `PracticeLog.sittingGap` starts a new one.
    /// Counted here rather than borrowed so the builder stays a pure function of `records`.
    private static func sittings(in records: [SessionRecord]) -> Int {
        let ordered = records.sorted { $0.startedAt < $1.startedAt }
        guard var previousEnd = ordered.first?.endedAt else { return 0 }
        var count = 1
        for record in ordered.dropFirst() {
            if record.startedAt.timeIntervalSince(previousEnd) >= PracticeLog.sittingGap { count += 1 }
            previousEnd = max(previousEnd, record.endedAt)
        }
        return count
    }
}
