import Foundation

/// The exercise's **note rate** and the labels/comparisons derived from it (device pass 2026-07-29).
///
/// An exercise carries *two* independent note-rate axes and nothing syncs them: `subdivision` (the
/// metronome **click**, set at creation and read-only afterwards) and the content's own
/// `notesPerBeat` (what the player **plays** — editable at any time through the Advanced → Rhythm
/// dropdown). A hand-authored sixteenth-note scale run therefore sits at `subdivision == .none`
/// alongside `notesPerBeat == 4`. Unifying the two into one stored source of truth — and binding a
/// measured command tempo to the rhythm it was earned at — is its own change with its own ADR; this
/// file only makes the rate **visible** and makes cross-exercise comparison honest, which needs no
/// schema change at all.
///
/// Resolution order is content-first: the content's rate is what the player actually plays, and it's
/// the axis the Rhythm dropdown moves. The click subdivision is the fallback for the templates that
/// declare no content rate (a metronome-only warm-up like the seeded *Spider Walk*, whose
/// `.sixteenths` click is the only rhythm it states). When neither declares one — a chord-changing
/// drill on a plain quarter-note click — the rate is genuinely **unknown**, not "quarters", so it is
/// `nil` and no surface invents a label for it.
extension Exercise {

    /// The rate the **content** declares, or `nil` for a template that has none (chords are held for
    /// beats, not subdivided; the metronome renderer has no notes of its own). Each accessor already
    /// gates on `kind`, but the switch is exhaustive so a new template can't silently inherit a wrong
    /// rate.
    var contentNoteRate: NoteRate? {
        switch kind {
        case .fretboard: fretboardContent.map { NoteRate(perBeat: $0.notesPerBeat) }
        case .strumming: strumPattern.map { NoteRate(perBeat: $0.slotsPerBeat) }
        case .strumChords: strumChordSheet.map { NoteRate(perBeat: $0.strumPattern.slotsPerBeat) }
        case .chords, .metronome: nil
        }
    }

    /// The exercise's **effective** note rate: the content's own where it declares one, else the
    /// metronome subdivision where that states a real one, else `nil` (nothing declares a rhythm —
    /// see the type note above; a label is shown only when this is non-`nil`).
    var noteRate: NoteRate? {
        if let contentNoteRate { return contentNoteRate }
        guard subdivision != .none else { return nil }
        return NoteRate(perBeat: subdivision.ticksPerBeat)
    }

    /// Notes per minute at a given tempo — the **comparison** number, derived and never stored. An
    /// exercise with no declared rhythm counts one note per beat, so it compares as its bare BPM
    /// rather than dropping out of the ordering.
    func notesPerMinute(atBPM bpm: Int) -> Int {
        (noteRate ?? .quarters).notesPerMinute(atBPM: bpm)
    }

    /// Notes per minute at the effective command tempo — what the library's Command sort ranks on, so
    /// *Spider Walk* (80 @ sixteenths = 320) no longer reads as a near-neighbour of *Chord Changes*
    /// (70 @ quarters = 70).
    var commandNotesPerMinute: Int { notesPerMinute(atBPM: command) }

    /// The command → reach line every list row shows, with the rhythm the tempos are measured in
    /// ("Command 80 → 96 BPM · 16ths"). One property rather than four hand-built strings, so the
    /// library, the routine block row, the add-unit picker and the up-next card can't drift apart.
    /// The suffix is omitted when no rhythm is declared — an absent label means "not stated", never
    /// "quarters".
    var commandProgressLabel: String {
        let tempos = "Command \(command) → \(reachTempo) BPM"
        guard let noteRate else { return tempos }
        return "\(tempos) · \(noteRate.compactLabel)"
    }
}
