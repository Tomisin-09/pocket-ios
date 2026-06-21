import Foundation

/// Assigns each saved loop a stable palette *slot* so it draws in its own colour
/// — colour encodes loop **identity** now, with overlap shown by vertical lane
/// (ADR 0023, superseding ADR 0018's colour-is-state rule).
///
/// Pure and UI-free (no SwiftUI) so the deterministic slot assignment is
/// unit-tested in isolation (AGENTS.md); the view maps a slot to an actual
/// `Color` via `PocketColor.loopPalette`. Operates on `LoopLanes.Interval`
/// value structs rather than the SwiftData `Loop` model so it's testable without
/// a model container.
enum LoopColors {

    /// The palette slot for a loop: its position in start-order (ties broken by
    /// end, then id — matching `LoopLanes.pack`) modulo `paletteCount`. Stable
    /// across launches and independent of input order, so a loop keeps its colour
    /// as others are added or removed *before* it, and re-mapped consistently once
    /// the palette wraps. Returns 0 if the id isn't in `intervals` or the palette
    /// is empty.
    static func slot(for id: UUID, among intervals: [LoopLanes.Interval],
                     paletteCount: Int) -> Int {
        guard paletteCount > 0 else { return 0 }
        let ordered = intervals.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.end != $1.end { return $0.end < $1.end }
            return $0.id.uuidString < $1.id.uuidString
        }
        guard let index = ordered.firstIndex(where: { $0.id == id }) else { return 0 }
        return index % paletteCount
    }

    /// The slot to actually draw: a valid manual `override` wins (ADR 0031), else the
    /// derived start-order `slot`. An out-of-range or `nil` override falls back to
    /// derived, so a stale index (e.g. after the palette shrinks) can't crash or blank.
    static func resolvedSlot(override: Int?, for id: UUID,
                             among intervals: [LoopLanes.Interval], paletteCount: Int) -> Int {
        if let override, paletteCount > 0, (0..<paletteCount).contains(override) { return override }
        return slot(for: id, among: intervals, paletteCount: paletteCount)
    }
}
