import Foundation

/// How many **notes are played per beat** — the missing half of a tempo. "80 BPM" means four
/// different things at quarters / eighths / triplets / sixteenths, so a BPM shown on its own is
/// only half the fact, and two exercises' command tempos can't honestly be compared without it
/// (device pass 2026-07-29).
///
/// Deliberately **not** `Subdivision`: that models the metronome's *click* density (`.none` reads
/// "one click per beat"), whereas this models what the **player** plays, which is why `perBeat == 1`
/// reads "Quarters" here. The two axes exist independently today — `Exercise.subdivision` is set at
/// creation and read-only, while the content's own `notesPerBeat` is editable afterwards through the
/// Rhythm dropdown — and `Exercise.noteRate` is the one place that resolves them into this.
///
/// **Scope (settled at triage):** notes-per-minute is a *comparison aid*, never a difficulty score.
/// It normalises one variable so two exercises sort honestly; it does not say which is harder
/// (triplets at 80 and sixteenths at 60 are both 240 npm and are not equally demanding), and it must
/// never grow into a derived "level" or a cross-exercise ranking presented as ability — that would be
/// grading the player, which ADR 0070 rules out. It describes, sorts and labels; it never judges.
///
/// Pure and UI-free so the arithmetic and the labels stay unit-tested (AGENTS.md).
struct NoteRate: Equatable, Hashable {
    /// Notes sounded per beat, at least 1 — clamped in `init` so no call site can divide the beat
    /// into zero notes or invert the comparison with a negative.
    let perBeat: Int

    init(perBeat: Int) {
        self.perBeat = max(1, perBeat)
    }

    static let quarters = NoteRate(perBeat: 1)
    static let eighths = NoteRate(perBeat: 2)
    static let triplets = NoteRate(perBeat: 3)
    static let sixteenths = NoteRate(perBeat: 4)

    /// The full name, matching the **Rhythm** dropdown's vocabulary in the fretboard editors
    /// (renamed from "Subdivision" there, 2026-07-28) so one word means one thing across the app.
    /// A rate outside the authored 1–4 table — only reachable from a decoded blob — describes itself
    /// rather than being rounded to a lie.
    var label: String {
        switch perBeat {
        case 1: "Quarters"
        case 2: "Eighths"
        case 3: "Triplets"
        case 4: "Sixteenths"
        default: "\(perBeat) per beat"
        }
    }

    /// The compact form for a line that already carries a tempo — "80 BPM · 16ths". Lower-case
    /// because it trails a value rather than titling a field.
    var compactLabel: String {
        switch perBeat {
        case 1: "quarters"
        case 2: "8ths"
        case 3: "triplets"
        case 4: "16ths"
        default: "\(perBeat)/beat"
        }
    }

    /// Notes per minute at a given tempo — `BPM × perBeat`. The **derived** comparison number: it is
    /// never stored (a denormalisation that would go stale the moment Rhythm changed) and never shown
    /// as a headline, since BPM is the number the musician actually sets.
    func notesPerMinute(atBPM bpm: Int) -> Int { max(0, bpm) * perBeat }
}
