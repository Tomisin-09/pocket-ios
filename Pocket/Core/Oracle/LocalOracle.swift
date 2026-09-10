import Foundation

/// The reading, written on the device from the context and nothing else (ADR 0187, S1).
///
/// ADR 0092 §A2 requires every AI surface to have a deterministic local fallback, so this exists
/// regardless. Building it **first** costs nothing and buys everything: every safety mechanism —
/// the cadence gate, the pain and distress branches, the tone guard, the whole DTO — is exercised
/// by real players before a single token is spent, and the eval fixtures of D17 come out of it.
/// It is also the entire feature in S1, where no build has a proxy address to call.
///
/// ### What it is allowed to say
///
/// Facts, in the order they happened, and the player's own words. What was worked on, the order it
/// was taken in within a sitting, what a loop's span did and how often it was re-entered, tempo
/// points with the rhythm they were measured in, and the goals the player wrote down. That is the
/// whole vocabulary.
///
/// **Minutes are not in it, and their absence is the decision** (ADR 0187 D22). They were the
/// opening paragraph until 2026-09, on two grounds that point the same way. Volume is the weakest
/// thing the app knows — in the closest study to this problem, Duke, Simmons & Cash's *It's Not How
/// Much; It's How*, the highest-rated performers did not differ from the rest in time spent, in
/// repetitions, or in complete run-throughs; they differed in how they handled the parts they got
/// wrong. And volume is the most shame-adjacent thing the app knows: D12 bans the adjective, but
/// *"12 minutes over 2 days"* has an implied denominator no matcher can strip, and the reader
/// supplies *only* themselves.
///
/// `PracticeLog` still counts minutes and the Practice log still shows them. They stopped being the
/// opening paragraph, which is the only place they were doing damage.
///
/// ### What it will not say, and why it cannot drift into saying it
///
/// No verdict, no comparison to a previous week, no target, no encouragement to do more (ADR 0070;
/// ADR 0016 keeps clean-before-fast the player's own call). This is not enforced by care — the
/// suite asserts that everything this type generates passes `OracleToneGuard`, so a future edit
/// that reaches for "you've been consistent" fails a test rather than shipping.
///
/// The one thing it is *for*, beyond stating facts, is handing back what the player wrote. A quoted
/// note is marked `isQuotedFromPlayer` and the guard does not read it — see
/// `OracleReadingText.Paragraph` for why that distinction has to be structural.
///
/// Pure and `Sendable`: `now`, the `Calendar` and the `Locale` are all injected, so two runs over
/// the same context produce the same words.
struct LocalOracle: OracleReading {

    var calendar: Calendar = .current
    var locale: Locale = .current

    func reading(for request: OracleReadingRequest) async throws -> OracleReadingText {
        OracleReadingText(paragraphs: paragraphs(for: request.context), source: .local)
    }

    /// Synchronous and non-throwing, because every other caller in this feature needs it that way:
    /// the coordinator falls back to it after a tone trip, and a fallback that can itself fail is
    /// not a fallback.
    func paragraphs(for context: OracleContext) -> [OracleReadingText.Paragraph] {
        var written: [OracleReadingText.Paragraph] = [OracleReadingText.Paragraph(opening(context))]
        if let order = orderTaken(context) { written.append(OracleReadingText.Paragraph(order)) }
        for line in spanLines(context) { written.append(OracleReadingText.Paragraph(line)) }
        let tempos = tempoLines(context)
        if !tempos.isEmpty {
            written.append(OracleReadingText.Paragraph(Self.tempoLead))
            for line in tempos { written.append(OracleReadingText.Paragraph(line)) }
        }
        if let quote = quotedNote(context) {
            written.append(OracleReadingText.Paragraph(quote.lead))
            written.append(OracleReadingText.Paragraph(quote.text, isQuotedFromPlayer: true))
        }
        if let goals = goalLine(context) { written.append(OracleReadingText.Paragraph(goals)) }
        return written
    }

    // MARK: - The paragraphs

    /// The period, and **what** was in it — named, never measured (ADR 0187 D22).
    ///
    /// This paragraph opened on minutes, days and sittings until D22 replaced it. What it says now
    /// is the same kind of fact the rest of the reading is made of: these are the things you worked
    /// on. No total, no denominator, nothing that needs a second value to mean anything.
    ///
    /// A week with nothing in it gets a sentence that says so **without an adverb**. "You did not
    /// practise" is a fact; "you only practised once" is a verdict, and D12 catches the second form
    /// in the model's prose precisely because it is so easy to write.
    func opening(_ context: OracleContext) -> String {
        let span = "\(dayLabel(context.windowStart)) to \(dayLabel(lastDay(of: context)))"
        guard context.effort.runs > 0 else {
            return "The week of \(span) has nothing logged against it. "
                + "That is all this says — a week with no runs in it is not a week this can read."
        }
        let worked = context.units.filter { $0.runs > 0 }
        // Runs, but none of them naming a drill this reading can see: a row that carries no unit,
        // or one whose unit fell past `maxUnits`. It says what it has rather than guessing why —
        // "the drills were deleted" would be a claim the payload cannot support.
        guard !worked.isEmpty else {
            return "The week of \(span) has runs logged against it, "
                + "but none of them naming something this can read back to you."
        }
        let named = worked.prefix(Self.maxNamedUnits).map(\.name)
        var line = "The week of \(span). You worked on " + list(Array(named)) + "."
        let rest = worked.count - named.count
        if rest > 0 {
            line += " And \(count(rest, singular: "other", plural: "others"))."
        }
        return line
    }

    /// Three. Past that the opening stops naming a week and starts listing a library.
    static let maxNamedUnits = 3

    /// The order things were taken in, inside one sitting (ADR 0187 D22).
    ///
    /// **The most recent sitting that has an order to describe** — one with at least two steps in
    /// it. A single-item sitting is a fact already covered by the opening, and printing every
    /// sitting turns a reflection into a log the player can already read on the Practice log.
    ///
    /// The word this paragraph exists for is *again*. Coming back to something later in the same
    /// sitting is the shape D22 is after, and it is invisible in every other view the app has: the
    /// practice log sorts by time but shows one row per run, and `units` here is ordered by minutes.
    /// Consecutive repeats were already collapsed by the builder, so a repeat that survives to here
    /// is a genuine return.
    func orderTaken(_ context: OracleContext) -> String? {
        let names = nameByHandle(context)
        guard let sitting = context.sittings.last(where: { $0.handles.count >= 2 }) else { return nil }
        let steps = sitting.handles.compactMap { names[$0] }
        guard steps.count >= 2 else { return nil }

        var seen: Set<String> = []
        let told = steps.map { name -> String in
            defer { seen.insert(name) }
            return seen.contains(name) ? "\(name) again" : name
        }
        return "On \(dayLabel(sitting.startedOn)) you took " + told.joined(separator: ", then ") + "."
    }

    /// What a loop's span did, and how often it was played at that width (ADR 0187 D22, ADR 0204).
    ///
    /// Both widths are stated and neither is subtracted, for the reason the tempo lines state both
    /// tempos: a difference has a direction somebody then has an opinion about. There is no
    /// *narrowed* or *widened* here either, even though the app derives that classification
    /// elsewhere — "from 34 seconds to 6" carries the direction without the app having put an
    /// adjective on it first.
    ///
    /// Only the **most recent** edit per loop. A span's whole history is a trajectory, and this
    /// paragraph is about where it arrived.
    func spanLines(_ context: OracleContext) -> [String] {
        context.units
            .filter { $0.kind == .loop }
            .compactMap { unit -> String? in
                guard let edit = unit.spans.last else { return nil }
                // Chronological, so it reads as the sequence it was: this many runs at that width,
                // then the change, then this many since. Naming the loop and then saying "the loop"
                // again — the first draft — is the app talking about itself instead of the week.
                var line = "\(unit.name): "
                if edit.runsInPreviousSpan > 0 {
                    line += "\(count(edit.runsInPreviousSpan, singular: "run", plural: "runs")) "
                        + "at \(seconds(edit.fromSeconds)), then on \(dayLabel(edit.changedOn)) "
                        + "you took it to \(seconds(edit.toSeconds))"
                } else {
                    line += "\(seconds(edit.fromSeconds)) until \(dayLabel(edit.changedOn)), "
                        + "then \(seconds(edit.toSeconds))"
                }
                if unit.runsInCurrentSpan > 0 {
                    line += ", and \(count(unit.runsInCurrentSpan, singular: "run", plural: "runs")) since"
                }
                line += "."
                if unit.droppedSpans > 0 {
                    line += " Earlier changes to it are not in this reading."
                }
                return line
            }
            .prefix(Self.maxSpanLines)
            .map { $0 }
    }

    /// Two. The same instinct as `maxTempoLines`, one paragraph earlier.
    static let maxSpanLines = 2

    /// The one sentence that keeps the tempo lines honest.
    ///
    /// A trajectory is drawn from the **whole log**, not the week — a tempo history that started in
    /// July did not start on Monday, and clipping it to the window would show a line that appears to
    /// begin wherever the request did. But that means the dates in those lines sit outside the week
    /// the paragraph above just named, which on screen reads as a mistake unless something says so.
    /// This says so, once, rather than qualifying every line.
    static let tempoLead = "Tempos below cover each drill's whole history, not only this week."

    /// One line per unit with a trajectory, with the note rate attached (ADR 0121, D6 R7).
    ///
    /// The two tempos are stated, never subtracted. "76, and later 96" is a pair of facts; "up 20"
    /// is a delta, and a delta has a direction the player did not ask anyone to have an opinion
    /// about. `otherRhythmRuns` is surfaced for the same reason the underlying type surfaces it —
    /// so a partial history admits it instead of quietly showing a shorter one.
    ///
    /// **A drill whose tempo has not moved gets a different sentence.** The two-number form
    /// degenerates into *"played at 72 on 22 Jul, and at 72 on 28 Aug"*, which states one fact
    /// twice and reads as a bug. Saying it **held** at 72 is the same fact said once — and it is
    /// still a fact, not a verdict: nothing here calls a steady tempo a plateau, which is exactly
    /// the word D12's tempo band exists to catch.
    ///
    /// Capped at three lines. Beyond that the reading stops being a reflection and becomes a table.
    func tempoLines(_ context: OracleContext) -> [String] {
        context.units.prefix(Self.maxTempoLines * 2).compactMap { unit in
            guard let tempo = unit.tempo, let first = tempo.points.first,
                  let latest = tempo.points.last, tempo.points.count >= 2 else { return nil }
            let rate = tempo.notesPerBeat.map { NoteRate(perBeat: $0).compactLabel } ?? "no stated rhythm"
            var line: String
            if first.bpm == latest.bpm {
                line = "\(unit.name) has held at \(first.bpm) in \(rate), "
                    + "from \(dayLabel(first.date)) to \(dayLabel(latest.date))."
            } else {
                line = "\(unit.name) was played at \(first.bpm) on \(dayLabel(first.date)), "
                    + "and at \(latest.bpm) on \(dayLabel(latest.date)), both in \(rate)."
            }
            if let settle = steppedDown(tempo.points, alreadyStated: latest.bpm) { line += " " + settle }
            if tempo.otherRhythmRuns > 0 {
                line += " \(count(tempo.otherRhythmRuns, singular: "run", plural: "runs")) "
                    + "at other rhythms sit outside that line."
            }
            return line
        }
        .prefix(Self.maxTempoLines)
        .map { $0 }
    }

    /// Three. A reading is prose, and a fourth tempo line turns it into a table.
    static let maxTempoLines = 3

    /// The most recent time a drill's tempo went **down**, stated as the pair it is (ADR 0187 D22).
    ///
    /// ### Why this is inferred rather than recorded
    ///
    /// Nothing persists a settle. `Exercise.settleCommand(to:)` and `Loop.settleCommand(to:)`
    /// overwrite `commandTempo` in place — the situation ADR 0199 fixed for spans and has never
    /// fixed for tempo. But `PracticeLogWriter` logs the **command** tempo per run, before the Done
    /// screen's promote or settle lands, so a settle shows up as the next run's point being lower.
    /// That is the whole mechanism, and it is why this reads the series rather than a column.
    ///
    /// The consequence to keep in mind before trusting it too far: a lower point means the command
    /// tempo was lower at that run, which a settle causes and is not the only thing that can.
    /// The sentence therefore says what the numbers say and nothing about why.
    ///
    /// ### Why a pair, and never an adjective
    ///
    /// A step-down is definitionally relative to the tempo before it, which brushes D22's own test
    /// — *if a value is meaningless without a second value, it is a comparison.* D22 names ramp
    /// step-downs as a structural fact anyway, so this is a stated exception, and the way it stays
    /// one is by carrying **both numbers**. A `steppedDown` flag, or the word *backed off*, would be
    /// the derived judgement D6 R5 keeps on this side of the wire — and *backwards* is in D12's
    /// table for exactly that reason.
    ///
    /// **Exercises only, in practice.** `TempoTrajectory.reading` filters to `.exercise` and a loop
    /// logs `tempoPercent` rather than `tempoBPM` — a different axis, not a missing value — so a
    /// loop has no `Tempo` here at all. D22's worked example pairs a span with a tempo; in this
    /// app that is two units and two sentences, and building a loop percent trajectory to make it
    /// one is a bigger change than the sentence is worth.
    /// - Parameter alreadyStated: the BPM the sentence before this one has already named, so the
    ///   clause does not say the same number twice. Found by reading a drawn reading, not by a
    ///   test: *"played at 68 on 30 Jul, and at 60 on 3 Sep… On 1 Sep it went from 76 to 60 and
    ///   stayed there"* states 60 twice and introduces 76 with no date, so a reader meets a number
    ///   from nowhere and a fact they have already been told. Same family as the `held at 72` bug,
    ///   and found the same way.
    func steppedDown(_ points: [OracleContext.TempoPoint], alreadyStated: Int? = nil) -> String? {
        guard points.count >= 2 else { return nil }
        // The **most recent** downward step, not the largest: the reading is about where the drill
        // is now, and the biggest backward move of the summer is a different sentence.
        var stepIndex: Int?
        for index in 1..<points.count where points[index].bpm < points[index - 1].bpm {
            stepIndex = index
        }
        guard let index = stepIndex else { return nil }

        let before = points[index - 1]
        let landed = points[index]
        let after = points[index...]
        // "and stayed there" needs a *later* point that agrees. With nothing after the step there
        // is no staying to report, only a last reading that happened to be lower.
        let stayed = after.count > 1 && after.allSatisfy { $0.bpm == landed.bpm }

        // The landing is where the drill still is, and the sentence above has just said so. Then
        // the only thing left to add is the step it came down from — dated, so the number arrives
        // attached to a day rather than out of the air.
        if landed.bpm == alreadyStated {
            return "It was at \(before.bpm) on \(dayLabel(before.date)) before that."
        }
        let tail = stayed ? " and stayed there" : ""
        return "On \(dayLabel(landed.date)) it went from \(before.bpm) to \(landed.bpm)\(tail)."
    }

    /// The player's own words, handed back.
    ///
    /// The **longest** note in the window, not the most recent: length is the only proxy available
    /// here for "the one they had most to say about", and it needs no judgement about content. A
    /// truncated note is skipped — quoting half a thought back at someone is worse than quoting
    /// none of it.
    func quotedNote(_ context: OracleContext) -> (lead: String, text: String)? {
        let whole = context.notes.filter { !$0.wasTruncated && $0.text.count >= 40 }
        guard let longest = whole.max(by: { ($0.text.count, $0.writtenOn) < ($1.text.count, $1.writtenOn) })
        else { return nil }
        return ("On \(dayLabel(longest.writtenOn)) you wrote:", longest.text)
    }

    /// What the player said they were after. Stated, never scored against.
    func goalLine(_ context: OracleContext) -> String? {
        let open = context.goals.filter { !$0.isMet }
        guard !open.isEmpty else { return nil }
        return "Still written down: " + list(open.prefix(3).map(\.title)) + "."
    }

    // MARK: - Wording

    /// The last day *inside* the window. `DateInterval.end` is exclusive, so naming it directly
    /// would print the Monday after the week the reading is about.
    private func lastDay(of context: OracleContext) -> Date {
        context.windowEnd.addingTimeInterval(-1)
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    /// D6 R1 handle → the unit's name, for the one paragraph that reads the sittings.
    ///
    /// A handle with no unit behind it is simply absent from the map and the step is dropped by the
    /// caller. That is not defensive coding for its own sake: `maxUnits` caps the unit list, so a
    /// sitting can legitimately name a unit that did not make the payload.
    private func nameByHandle(_ context: OracleContext) -> [String: String] {
        Dictionary(context.units.map { ($0.handle, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    /// A span width, in whole seconds. Loop spans are short enough that a minutes form would round
    /// the interesting cases — a six-second passage — into nothing.
    private func seconds(_ interval: TimeInterval) -> String {
        count(Int(interval.rounded()), singular: "second", plural: "seconds")
    }

    // The `minutes(_:)` formatter — "2 hours 10 min" — was deleted by ADR 0187 D22 along with its
    // two call sites, rather than left here unused. `OracleContext.effort.minutes` is still sent
    // and `PracticeLog` still counts it; what is gone is this type's ability to *phrase* it. A
    // future author who wants a total in the reading has to write the formatter back, which is a
    // deliberate act and a reviewable diff, instead of reaching for one already sitting in the file.

    private func count(_ value: Int, singular: String, plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }

    /// "a", "a and b", "a, b and c" — no Oxford comma, matching the app's own copy.
    private func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " and " + (items.last ?? "")
        }
    }
}
