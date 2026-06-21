import SwiftUI

/// The identity colour for a loop (ADR 0023): a deterministic palette slot by
/// start-order, so each loop reads as its own hue wherever it's drawn. Centralised
/// here so the waveform, the minimap, and the transport bar's active-loop strip
/// (pocket-040) all resolve the same hue from the same `LoopColors.slot` logic
/// instead of each re-deriving it.
enum LoopColor {
    /// The colour to draw — precedence: a free custom colour (`customColorHex`), then a
    /// palette override (`colorIndex`), then derived by start-order (ADR 0023 / 0031).
    static func color(for loop: Loop, among loops: [Loop]) -> Color {
        if let hex = loop.customColorHex, let custom = HexColor.color(from: hex) { return custom }
        let slot = LoopColors.resolvedSlot(override: loop.colorIndex, for: loop.uid,
                                           among: intervals(of: loops),
                                           paletteCount: PocketColor.loopPalette.count)
        return PocketColor.loopPalette[slot]
    }

    /// The start-order colour ignoring any override — what the "Auto" swatch shows.
    static func derivedColor(for loop: Loop, among loops: [Loop]) -> Color {
        let slot = LoopColors.slot(for: loop.uid, among: intervals(of: loops),
                                   paletteCount: PocketColor.loopPalette.count)
        return PocketColor.loopPalette[slot]
    }

    private static func intervals(of loops: [Loop]) -> [LoopLanes.Interval] {
        loops.map { LoopLanes.Interval(id: $0.uid, start: $0.start, end: $0.end) }
    }
}
