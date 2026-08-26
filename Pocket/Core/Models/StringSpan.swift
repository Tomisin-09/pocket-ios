import Foundation

/// The rule behind the picking editor's **string-span strip** (ADR 0184): which end of the span a tap
/// on a string moves. Pure and SwiftUI-free, so the behaviour is unit-tested rather than trusted —
/// it's the one piece of the strip that isn't self-evident from looking at it (AGENTS.md).
///
/// Indices are the engine's: `0` = high e … `5` = low E, so a span whose `from` is *greater* than its
/// `to` travels low→high, the way a chromatic warm-up does.
enum StringSpanEdit {
    /// The span a tap on `tapped` produces.
    ///
    /// Tapping a string that is **already an end** collapses the span onto it — the only route back to
    /// a single-string run, which the two menus this replaced could express and a plain two-handle
    /// strip could not. Any other tap moves the **nearer end**, which is forgiving (no handle to grab)
    /// and, more usefully, can never cross the ends over each other: if the tap were beyond the far
    /// end, that end would be the nearer one and would move instead. Direction is therefore only ever
    /// changed deliberately, by Reverse.
    ///
    /// A tie — a tap exactly midway between the two ends — moves `from`. It sits strictly between them,
    /// so either choice is valid and this one keeps the result deterministic.
    static func apply(tapped: Int, from: Int, to: Int) -> (from: Int, to: Int) {
        guard tapped != from, tapped != to else { return (tapped, tapped) }
        return abs(tapped - from) <= abs(tapped - to) ? (tapped, to) : (from, tapped)
    }
}

/// String names for the span controls. The **short** form labels a strip cell, where six names share a
/// row and only a letter fits; the **full** form is what VoiceOver reads and what the span caption
/// spells out. Lowercase `e` is the high E and uppercase `E` the low, as tab and chord charts already
/// spell them — the one place the short form isn't simply the note letter.
///
/// Both read the engine's index order (`0` = high e … `5` = low E) and answer for bass's four strings
/// too (ADR 0116), so the strip needs no instrument branch of its own.
enum NeckStringName {
    private static let guitarShort = ["e", "B", "G", "D", "A", "E"]
    private static let bassShort = ["G", "D", "A", "E"]
    private static let guitarFull = ["high e", "B", "G", "D", "A", "low E"]
    private static let bassFull = ["G", "D", "A", "low E"]

    static func short(_ index: Int, instrument: Instrument = .guitar) -> String {
        let names = instrument == .guitar ? guitarShort : bassShort
        return names.indices.contains(index) ? names[index] : "\(index + 1)"
    }

    static func full(_ index: Int, instrument: Instrument = .guitar) -> String {
        let names = instrument == .guitar ? guitarFull : bassFull
        return names.indices.contains(index) ? names[index] : "String \(index + 1)"
    }
}
