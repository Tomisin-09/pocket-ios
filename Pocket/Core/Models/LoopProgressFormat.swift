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
}
