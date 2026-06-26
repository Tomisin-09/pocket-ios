import Foundation

/// A named time signature for the standalone metronome (ADR 0043, slice 3) — the meter
/// plus the **accent pattern** that gives it its feel, with a plain-language context so
/// the picker reads musically ("3/4 · Waltz", "12/8 · Slow blues") rather than as bare
/// numbers.
///
/// `bpm` on the engine is the **click rate** — every beat in the bar sounds at that
/// tempo — and `accentBeats` marks which clicks are emphasised (the accented `ClickVoice`
/// level), so 6/8 reads ONE-two-three-FOUR-five-six. `noteValue` is the denominator,
/// carried for the label and for future subdivision work (slice 5). Pure and
/// Foundation-only so the accent arithmetic is unit-tested (AGENTS.md).
struct TimeSignature: Equatable, Identifiable {
    /// Clicks per bar (the numerator for simple meters; the subdivision count for
    /// compound meters felt in groups).
    let beats: Int
    /// The denominator (4, 8, …) — label and future subdivision feel.
    let noteValue: Int
    /// Indices (0-based, within the bar) of the accented clicks. Always includes 0 (the
    /// downbeat); compound meters add the secondary pulse (e.g. 6/8 → `[0, 3]`).
    let accentBeats: [Int]
    /// Display name, e.g. "4/4".
    let name: String
    /// Plain-language feel, e.g. "Pop · rock".
    let context: String

    var id: String { name }

    /// Whether the click at `index` within the bar is an accented (strong) click. Indices
    /// are taken modulo `beats` so a running beat counter maps in directly.
    func isAccented(beatInBar index: Int) -> Bool {
        guard beats > 0 else { return false }
        return accentBeats.contains(((index % beats) + beats) % beats)
    }

    /// The curated meters offered in the picker, common → less common.
    static let presets: [TimeSignature] = [
        TimeSignature(beats: 4, noteValue: 4, accentBeats: [0], name: "4/4", context: "Pop · rock"),
        TimeSignature(beats: 3, noteValue: 4, accentBeats: [0], name: "3/4", context: "Waltz"),
        TimeSignature(beats: 2, noteValue: 4, accentBeats: [0], name: "2/4", context: "March · polka"),
        TimeSignature(beats: 6, noteValue: 8, accentBeats: [0, 3], name: "6/8", context: "Jig · ballad (in 2)"),
        TimeSignature(beats: 12, noteValue: 8, accentBeats: [0, 3, 6, 9], name: "12/8",
                      context: "Slow blues · doo-wop (in 4)"),
        TimeSignature(beats: 5, noteValue: 4, accentBeats: [0, 3], name: "5/4", context: "Odd meter"),
        TimeSignature(beats: 7, noteValue: 8, accentBeats: [0, 4], name: "7/8", context: "Odd meter")
    ]

    /// The default meter — 4/4.
    static let standard = presets[0]

    /// Reconstruct a signature from a saved exercise's stored fields (ADR 0043, slice 6):
    /// a matching preset (so the name/context come back) when one exists, else a constructed
    /// signature carrying the stored accents and a generic name.
    static func forStored(beats: Int, noteValue: Int, accentBeats: [Int]) -> TimeSignature {
        if let preset = presets.first(where: { $0.beats == beats && $0.noteValue == noteValue }) {
            return preset
        }
        return TimeSignature(beats: max(1, beats), noteValue: max(1, noteValue),
                             accentBeats: accentBeats.isEmpty ? [0] : accentBeats,
                             name: "\(beats)/\(noteValue)", context: "Custom")
    }
}
