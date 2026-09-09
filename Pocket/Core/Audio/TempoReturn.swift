import Foundation

/// Remembering the speed you dropped from (ADR 0201) — pure, so the one rule that matters is
/// testable without a slider.
///
/// **Dropping the speed already works; coming back never has.** Grep the codebase before this ADR
/// for `previousSpeed`, `restoreSpeed`, `revertTempo` and there are no hits at all: a drop was a
/// one-way cost, paid by hand and undone by hand, which is a good part of why players are reluctant
/// to take one. The research asks them to slow down; the app charged them for it.
enum TempoReturn {

    /// How far the speed must fall before it counts as *dropping* rather than nudging. A pill
    /// offered after a hair's-width slider wobble would be noise, and noise beside the tempo
    /// readout is worse than nothing.
    static let minimumDrop = 0.05

    /// The speed worth remembering after a **user-driven** change from `old` to `new`.
    ///
    /// - The **first** drop wins. Dragging a slider from 1.0 through 0.9 to 0.72 is one gesture and
    ///   one intent, and the speed worth returning to is where it started, not the last value the
    ///   drag happened to pass through.
    /// - Getting back on your own clears it. Once the speed is at or above what was remembered, the
    ///   offer has been taken by hand and the pill has nothing left to say.
    /// - Everything else leaves it alone, including a drop that carries on downwards.
    static func remembered(_ current: Double?, movingFrom old: Double, to new: Double) -> Double? {
        if let current, new >= current - 1e-9 { return nil }
        if new < old - minimumDrop { return current ?? old }
        return current
    }
}
