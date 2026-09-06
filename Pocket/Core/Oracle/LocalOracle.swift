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
/// Facts, in the order they happened, and the player's own words. Minutes, days, sittings, run
/// counts, tempo points with the rhythm they were measured in, and the goals the player wrote
/// down. That is the whole vocabulary.
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
        if let spend = whereItWent(context) { written.append(OracleReadingText.Paragraph(spend)) }
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

    /// The period, and what happened in it. Days and sittings are counted; nothing is compared.
    ///
    /// A week with nothing in it gets a sentence that says so **without an adverb**. "You did not
    /// practise" is a fact; "you only practised once" is a verdict, and D12 catches the second form
    /// in the model's prose precisely because it is so easy to write.
    func opening(_ context: OracleContext) -> String {
        let span = "\(dayLabel(context.windowStart)) to \(dayLabel(lastDay(of: context)))"
        let effort = context.effort
        guard effort.runs > 0 else {
            return "The week of \(span) has nothing logged against it. "
                + "That is all this says — a week with no runs in it is not a week this can read."
        }
        let days = count(effort.daysPractised.count, singular: "day", plural: "days")
        let sittings = count(effort.sittings, singular: "sitting", plural: "sittings")
        return "The week of \(span): \(minutes(effort.minutes)) of practice, "
            + "over \(days) and \(sittings)."
    }

    /// Where the time went, largest first. Names units, states minutes, draws no conclusion.
    func whereItWent(_ context: OracleContext) -> String? {
        let worked = context.units.filter { $0.minutes > 0 || $0.runs > 0 }
        guard !worked.isEmpty else { return nil }
        let named = worked.prefix(3).map { "\($0.name) (\(minutes($0.minutes)))" }
        let rest = worked.count - named.count
        var line = "Most of it went to " + list(Array(named)) + "."
        if rest > 0 {
            line += " \(count(rest, singular: "other thing", plural: "other things")) had time too."
        }
        return line
    }

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

    private func minutes(_ total: Int) -> String {
        guard total >= 60 else { return count(total, singular: "minute", plural: "minutes") }
        let hours = total / 60
        let rest = total % 60
        let hoursLabel = count(hours, singular: "hour", plural: "hours")
        guard rest > 0 else { return hoursLabel }
        return "\(hoursLabel) \(rest) min"
    }

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
