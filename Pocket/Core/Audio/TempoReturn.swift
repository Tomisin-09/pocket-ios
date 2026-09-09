import Foundation

/// Remembering the speed you dropped from (ADR 0201, revised by ADR 0202) — pure, so the one rule
/// that matters is testable without a slider.
///
/// **Dropping the speed already works; coming back never has.** Grep the codebase before ADR 0201
/// for `previousSpeed`, `restoreSpeed`, `revertTempo` and there are no hits at all: a drop was a
/// one-way cost, paid by hand and undone by hand, which is a good part of why players are reluctant
/// to take one. The research asks them to slow down; the app charged them for it.
///
/// **The rule is anchored to a gesture, not to consecutive writes** (ADR 0202 D4). The speed slider
/// is continuous and writes on every frame of a drag, so a per-write comparison sees a run of
/// hair's-width steps and never finds a drop at all — the pill could only ever appear from a preset
/// pill or a typed value. Anchoring to where the player's hand *started* fixes that, and it is also
/// what makes going back **one rung** expressible.
enum TempoReturn {

    /// How far the speed must fall, across one gesture, before it counts as *dropping* rather than
    /// nudging. A pill offered after a hair's-width slider wobble would be noise, and noise beside
    /// the tempo readout is worse than nothing.
    static let minimumDrop = 0.05

    /// The speed worth remembering, given where this gesture started and where the speed is now.
    ///
    /// - `gestureStart` is the settled speed the player last left alone — captured when they grabbed
    ///   the slider, tapped a preset or opened numeric entry, not the previous frame of a drag.
    /// - **One rung, not the top of the ladder.** A second drop offers the speed it started from,
    ///   replacing the first drop's. Isolating a passage is a ladder and coming back down it a rung
    ///   at a time is the point — the same reason `SpanHistory.widenTarget` walks back one span
    ///   rather than leaping to the widest one ever recorded (ADR 0201 D2).
    /// - **Getting back on your own clears it.** Once the speed is at or above what was remembered,
    ///   the offer has been taken by hand and the pill has nothing left to say.
    static func remembered(_ current: Double?, gestureStart: Double, now: Double) -> Double? {
        guard now < gestureStart - minimumDrop else {
            // Not a drop: a nudge, a climb, or a return. Retire the offer once it has been reached.
            if let current, now >= current - 1e-9 { return nil }
            return current
        }
        return gestureStart
    }
}
