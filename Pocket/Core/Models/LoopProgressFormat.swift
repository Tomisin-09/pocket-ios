import Foundation

/// Formats a loop's **command tempo** (a fraction of original, e.g. `0.85`) for display
/// as a whole-number percent, with a single home for the `nil → "—"` unset fallback
/// (ADR 0039). Centralised because the same `Int((tempo * 100).rounded())%` appears across
/// the edit sheet, the glanceable loop row, and the journal views — and kept pure / UI-free
/// so the rounding (tempo math that breaks silently) is unit-tested per AGENTS.md.
enum LoopProgressFormat {
    /// Command tempo as a whole-number percent of original, or `nil` when unset.
    /// `0.85 → 85`, `1.0 → 100`; half-values round to nearest.
    static func percent(_ commandTempo: Double?) -> Int? {
        commandTempo.map { Int(($0 * 100).rounded()) }
    }

    /// Command tempo as a display string — `"85%"`, or `"—"` when unset.
    static func percentLabel(_ commandTempo: Double?) -> String {
        percent(commandTempo).map { "\($0)%" } ?? "—"
    }

    /// Absolute-BPM label for an **exercise's** command snapshot — "not yet measured" when
    /// un-promoted, and carrying the rhythm it was measured in when the entry recorded one
    /// (ADR 0121). An entry written before that snapshot existed shows the bare BPM: the snapshot is
    /// immutable (ADR 0038), so an unknown rhythm is left unstated rather than filled in from
    /// today's drill.
    ///
    /// **Moved here from `JournalSheet` by ADR 0207 D9.** It had been a `static` on a SwiftUI
    /// `View`, which under Swift 6 makes it `@MainActor` — so the first non-view caller
    /// (`JournalOwner.captureSummary`) failed to compile against a pure string formatter. That is
    /// AGENTS.md's *pure logic stays pure* arriving as a build error rather than as a style note,
    /// and this file is where its sibling `percentLabel` already lived.
    static func bpmLabel(_ bpm: Int?, notesPerBeat: Int? = nil) -> String {
        guard let bpm else { return "not yet measured" }
        guard let notesPerBeat else { return "\(bpm) BPM" }
        return "\(bpm) BPM · \(NoteRate(perBeat: notesPerBeat).compactLabel)"
    }
}
