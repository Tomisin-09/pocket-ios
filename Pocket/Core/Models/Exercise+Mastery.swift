import Foundation

/// `Exercise`'s **practice record** — the self-rated mastery, the conditions that rating was taken
/// under (ADR 0169), and the last-practised stamp the planner's dueness reads. Split out of
/// `Exercise.swift`, which sits against the 400-line cap CI's `--strict` lint enforces; the two
/// freeform gates ride along because they describe how a run is *performed*, not what the drill is.
///
/// Mastery and command tempo remain two axes (ADR 0036) — nothing here derives one from the other.
/// See `MasteryReading` for the rule, and `Loop`'s mirror of it in `Loop+Mastery.swift`.
extension Exercise {

    /// Journal entries newest-first — the order the journal lists them in (mirrors `Loop`).
    var journalByRecent: [JournalEntry] {
        journal.sorted { $0.createdAt > $1.createdAt }
    }

    /// Set the self-rating **and stamp the conditions it was given under** (ADR 0169).
    ///
    /// The single write path, on the model rather than at a call site, for exactly the reason
    /// `promoteCommand` is: every rating runs through here, so the stamp cannot be forgotten by a
    /// new screen. There are five surfaces that rate an exercise or a loop today, and the one that
    /// mattered most — the routine Done screen — writes the rating *and* an accepted promote in one
    /// commit. Stamping at the write, before any revision lands, is what makes that ordering
    /// truthful: the rating records the tempo it was earned at, and the promote then moves the
    /// command off it, which sets it aside as the *last* rating rather than today's (ADR 0250).
    ///
    /// Clearing the rating (`nil`) clears the stamp — conditions with nothing to condition are
    /// noise, and leaving them would let a later re-rate inherit an unrelated tempo.
    ///
    /// **An unchanged value writes nothing** (ADR 0250). Every completion screen pre-fills the dots
    /// and hands them back on Continue whether or not they were touched, so without this a blank
    /// row after a command move would wipe the set-aside rating, and a pre-filled one would re-stamp
    /// an old number at a tempo it was never given at. Nothing is lost: a current rating is always
    /// at today's command (`moveCommand` sees to it), so re-stamping it would change nothing.
    func rateMastery(_ value: Int?) {
        guard value != mastery else { return }
        mastery = value
        previousMastery = nil   // a rating given now supersedes the one the last move set aside
        guard value != nil else {
            masteryTempo = nil
            masteryNotesPerBeat = nil
            return
        }
        masteryTempo = command
        masteryNotesPerBeat = noteRate?.perBeat
    }

    /// Write the command and **set aside a rating the move leaves behind** (ADR 0250) — the one
    /// path `promoteCommand` and `settleCommand` write `commandTempo` through, so no screen that
    /// moves the command can forget it.
    ///
    /// A stamped rating is set aside when the stamp no longer matches (`masteryIsStale`); an
    /// unstamped one (pre-0169) when the effective command actually changed. Never on a write that
    /// lands where it already was — `ExerciseRunView.persist` promotes on every Save and Start, and
    /// a first promote turns the fallback into a measured command at the same value.
    func moveCommand(to tempo: Int?) {
        let setsAside = ratingWouldBeSetAside(movingTo: tempo)
        commandTempo = tempo
        if setsAside { setRatingAside() }
    }

    /// Whether writing `tempo` as the command would set the current rating aside — `moveCommand`'s
    /// rule, asked ahead of the write. Mirrors `Loop.ratingWouldBeSetAside(movingTo:)`.
    func ratingWouldBeSetAside(movingTo tempo: Int?) -> Bool {
        guard mastery != nil else { return false }
        let after = tempo ?? currentTempo
        guard masteryTempo != nil else { return after != command }
        return MasteryReading.isStale(ratedAt: masteryTempo, ratedRhythm: masteryNotesPerBeat,
                                      command: after, rhythm: noteRate?.perBeat)
    }

    /// Move the current rating to `previousMastery`, keeping its stamp, so the drill reads unrated
    /// at its new tempo and "Last rated…" can still be said (ADR 0250). Idempotent.
    func setRatingAside() {
        guard let mastery else { return }
        previousMastery = mastery
        self.mastery = nil
    }

    /// Whether the **current** rating's conditions have since moved — the command tempo or the
    /// rhythm has left where it was taken. An unstamped rating (pre-0169) is **not** stale: it doesn't
    /// know its conditions, which is not the same as knowing they changed. With no current rating
    /// there is nothing to be stale; a set-aside one is history, not a claim about now.
    var masteryIsStale: Bool {
        guard mastery != nil else { return false }
        return MasteryReading.isStale(ratedAt: masteryTempo, ratedRhythm: masteryNotesPerBeat,
                                      command: command, rhythm: noteRate?.perBeat)
    }

    /// What a read-back surface captions the mastery row with — "Rated at 90 BPM · 8ths", "Last
    /// rated 5 at 70 BPM · 8ths" for a set-aside rating, or `nil` when there is nothing to report.
    /// Reports the rhythm the rating was taken in, not today's, for the reason
    /// `commandProgressLabel` reports the *bound* rhythm: the caption describes a measurement and
    /// must not re-badge itself.
    var masteryReading: MasteryReading.Display? {
        let rhythm = masteryNotesPerBeat.map { " · \(NoteRate(perBeat: $0).compactLabel)" } ?? ""
        let conditions = masteryTempo.map { "\($0) BPM" + rhythm }
        if let mastery {
            guard let conditions else { return nil }
            return MasteryReading.Display(rating: mastery, conditions: conditions,
                                          isStale: masteryIsStale)
        }
        guard let previousMastery else { return nil }
        return MasteryReading.Display(rating: previousMastery, conditions: conditions,
                                      isStale: false, isPrevious: true)
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
