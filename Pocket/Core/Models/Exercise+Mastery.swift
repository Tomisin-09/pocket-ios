import Foundation

/// `Exercise`'s **practice record** — the self-rated mastery, the conditions that rating was taken
/// under (ADR 0169), and the last-practised stamp the planner's dueness reads. Split out of
/// `Exercise.swift`, which sits against the 400-line cap CI's `--strict` lint enforces; the two
/// freeform gates ride along because they describe how a run is *performed*, not what the drill is.
///
/// Mastery and command tempo remain two axes (ADR 0036) — nothing here derives one from the other.
/// See `MasteryReading` for the rule, and `Loop`'s mirror of it in `Loop+Mastery.swift`.
extension Exercise {

    /// Set the self-rating **and stamp the conditions it was given under** (ADR 0169).
    ///
    /// The single write path, on the model rather than at a call site, for exactly the reason
    /// `promoteCommand` is: every rating runs through here, so the stamp cannot be forgotten by a
    /// new screen. There are five surfaces that rate an exercise or a loop today, and the one that
    /// mattered most — the routine Done screen — writes the rating *and* an accepted promote in one
    /// commit. Stamping at the write, before any revision lands, is what makes that ordering
    /// truthful: the rating records the tempo it was earned at, and the promote then moves the
    /// command off it, which is precisely the staleness the planner needs to see.
    ///
    /// Clearing the rating (`nil`) clears the stamp — conditions with nothing to condition are
    /// noise, and leaving them would let a later re-rate inherit an unrelated tempo.
    func rateMastery(_ value: Int?) {
        mastery = value
        guard value != nil else {
            masteryTempo = nil
            masteryNotesPerBeat = nil
            return
        }
        masteryTempo = command
        masteryNotesPerBeat = noteRate?.perBeat
    }

    /// Whether the rating's conditions have since moved — the command tempo or the rhythm has left
    /// where the rating was taken. An unstamped rating (pre-0169) is **not** stale: it doesn't know
    /// its conditions, which is not the same as knowing they changed.
    var masteryIsStale: Bool {
        MasteryReading.isStale(ratedAt: masteryTempo, ratedRhythm: masteryNotesPerBeat,
                               command: command, rhythm: noteRate?.perBeat)
    }

    /// What a read-back surface captions the mastery row with — "Rated at 90 BPM · 8ths", or `nil`
    /// when there is no rating or no stamp to report. Reports the rhythm the rating was taken in,
    /// not today's, for the reason `commandProgressLabel` reports the *bound* rhythm: the caption
    /// describes a measurement and must not re-badge itself.
    var masteryReading: MasteryReading.Display? {
        guard let mastery, let masteryTempo else { return nil }
        let rhythm = masteryNotesPerBeat.map { " · \(NoteRate(perBeat: $0).compactLabel)" } ?? ""
        return MasteryReading.Display(rating: mastery,
                                      conditions: "\(masteryTempo) BPM" + rhythm,
                                      isStale: masteryIsStale)
    }

    /// Mark this exercise practised **now** — stamps `lastPracticed` so the planner's dueness
    /// (focused axis) and LRU rotation (warm-up axis) both advance. Called from the run path
    /// when a run actually starts; deliberately does *not* touch `mastery` (self-rated only).
    func markPracticed(_ date: Date = .now) { lastPracticed = date }

    /// Whether this unit can honestly be practised with nothing in your hands (ADR 0139 O6). Gated on
    /// the template as well as the flag, so a value left behind on an exercise whose template somehow
    /// isn't freeform can never leak into a constrained session — the declaration is meaningful only
    /// where the app doesn't model the content.
    var declaresAwayFromInstrument: Bool { template == .freeform && awayFromInstrument }

    /// Whether this block should tick while it runs. Gated on the template for the same reason as
    /// `declaresAwayFromInstrument`: the click settings are only meaningful where the app models
    /// nothing, and every other template drives its click from the ramp instead.
    var playsFreeformClick: Bool { template == .freeform && clickEnabled }
}
