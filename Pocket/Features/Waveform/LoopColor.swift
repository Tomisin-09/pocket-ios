import SwiftUI

/// The identity colour for a loop (ADR 0023): a deterministic palette slot by
/// start-order, so each loop reads as its own hue wherever it's drawn. Centralised
/// here so the waveform, the minimap, and the transport bar's active-loop strip
/// (pocket-040) all resolve the same hue from the same `LoopColors.slot` logic
/// instead of each re-deriving it.
enum LoopColor {
    static func color(for loop: Loop, among loops: [Loop]) -> Color {
        let intervals = loops.map { LoopLanes.Interval(id: $0.uid, start: $0.start, end: $0.end) }
        let slot = LoopColors.slot(for: loop.uid, among: intervals,
                                   paletteCount: PocketColor.loopPalette.count)
        return PocketColor.loopPalette[slot]
    }
}
