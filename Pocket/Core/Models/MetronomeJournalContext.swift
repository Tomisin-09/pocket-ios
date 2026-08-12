import Foundation

/// What a **metronome** journal entry is written about (ADR 0160) — a metronome *sitting*, not a unit.
///
/// A plain value type rather than a model, for the same reason `SessionJournalContext` is one: a
/// sitting at the click has no stored identity and doesn't need one. What the entry keeps is a copy of
/// the four values that were in force, so the note still says what it was about long after the screen
/// has moved on.
///
/// **This is the type ADR 0155 §8 said should not exist**, and the reversal is conditional on the
/// snapshot being *complete*. A bare BPM on an ownerless note is a fragment of a unit's context with
/// no unit behind it, which invites the reader to attach it to a drill that was never there. Tempo,
/// meter, subdivision and withdrawal together are a full description of a real thing, on an entry that
/// declares what it is — so there is nowhere wrong left to attach it.
///
/// Pure and Foundation-only (AGENTS.md): the raw-column round trip and the caption are exactly the
/// kind of thing that breaks silently, so both are unit-tested without a `ModelContainer` or an engine.
struct MetronomeJournalContext: Equatable {
    /// The click rate at the moment the composer opened (ADR 0160 §5) — **not** at Save. The automator
    /// keeps ramping behind the sheet, and the moment being described is the one the player reached
    /// for the pencil in.
    let bpm: Int
    let timeSignature: TimeSignature
    let subdivision: Subdivision
    /// The withdrawal **in force**, not the one configured (ADR 0160 §4) — `activeWithdrawal`, with
    /// ADR 0132 §4's exclusions already applied. A player ramping with Deep selected heard a full
    /// click, and the journal records what happened.
    let withdrawal: ClickWithdrawal

    init(bpm: Int, timeSignature: TimeSignature, subdivision: Subdivision,
         withdrawal: ClickWithdrawal) {
        self.bpm = bpm
        self.timeSignature = timeSignature
        self.subdivision = subdivision
        self.withdrawal = withdrawal
    }

    /// Rebuild the context from an entry's raw columns, or `nil` when the entry didn't record one.
    ///
    /// The meter is the only value that must be present — it is stored as the two `Int`s a
    /// `TimeSignature` is built from (never the struct itself; the SwiftData enum/attribute migration
    /// rule, ADR 0160 §2), and without it there is no sitting to describe. The other three degrade to
    /// their defaults rather than failing the whole snapshot: an entry that recorded a meter and a
    /// tempo but predates a later column should still render what it does know.
    ///
    /// **`Subdivision.none` has the raw value `""`.** An empty string is a recorded "no subdivision",
    /// while `nil` is "never recorded" — the two must not collapse into each other, which is why this
    /// reads the optional rather than defaulting the string first.
    init?(beats: Int?, noteValue: Int?, bpm: Int?, subdivisionRaw: String?, withdrawalRaw: String?) {
        guard let beats, let noteValue else { return nil }
        self.bpm = bpm ?? 0
        // Accents are a property of the meter, not of the sitting — the player can't edit them — so
        // they're derived here rather than stored. A preset round-trips with its name and context.
        self.timeSignature = TimeSignature.forStored(beats: beats, noteValue: noteValue,
                                                     accentBeats: [])
        self.subdivision = subdivisionRaw.flatMap(Subdivision.init(rawValue:)) ?? .none
        self.withdrawal = withdrawalRaw.flatMap(ClickWithdrawal.init(rawValue:)) ?? .off
    }

    /// The feed's one-line settings caption — `96 BPM · 4/4 · ♫ · gentle withdrawal`.
    ///
    /// The subdivision is dropped when none was running and the withdrawal when it was off: those are
    /// the defaults, so the great majority of entries would otherwise carry two segments that say
    /// nothing. Tempo and meter always render — they are the sitting.
    var summary: String {
        var parts = ["\(bpm) BPM", timeSignature.name]
        if subdivision != .none { parts.append(subdivision.glyph) }
        if withdrawal != .off { parts.append("\(withdrawal.label.lowercased()) withdrawal") }
        return parts.joined(separator: " · ")
    }
}
