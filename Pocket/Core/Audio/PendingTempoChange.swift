import Foundation

/// The next tempo boundary a running ramp is approaching, and how far away it is (ADR 0131).
///
/// A ramp changes tempo the instant its elapsed count crosses a plateau boundary, which lands as a
/// surprise: the player finds out the ground moved by being wrong about it. This is the value the
/// **warning** is derived from — a ramp reports *how far* and *to what*, and never decides what counts
/// as "soon", because that needs the live tempo and meter the ramp does not carry.
///
/// Pure and UI-free so the boundary arithmetic (the tempo math that breaks silently, AGENTS.md) is
/// unit-tested rather than eyeballed on device.
struct PendingTempoChange: Equatable {
    /// The tempo the ramp is holding now — BPM, or percent-of-original for a loop ramp.
    var from: Int
    /// The tempo it moves to. `nil` ⇒ the ramp **ends** at this boundary, which warns like any other
    /// (ADR 0131 §4): being dropped out of a run mid-phrase is the same defect as being sped up.
    var to: Int?
    /// How much of the current plateau is left, in the ramp's own interval unit. A `Double` — unlike
    /// the plateau cursor's `Int` — because the warning lives *inside* the final interval.
    var unitsRemaining: Double
    /// The whole length of the plateau now holding, same unit. Carried so the consumer can clamp the
    /// window without re-walking the ramp.
    var plateauUnits: Double
    /// Whether the unit is bars or seconds (a loop ramp reuses `.bars`, reinterpreted as passes).
    var unit: MetronomeIntervalUnit

    /// Whether the change is upward. A boundary that ends the ramp is not a rise.
    var isRise: Bool { (to ?? from) > from }

    /// The warning window in this change's own unit: **at most one bar, and never more than half the
    /// plateau** (ADR 0131 §2).
    ///
    /// A bar is the maximum because it is the unit the player already counts in, and because it scales
    /// with the music — four seconds at 60 BPM, 1.2 at 200 — where a fixed number of seconds would be
    /// a yawn at the bottom of a ramp and useless at the top.
    ///
    /// The half-plateau clamp is what stops the feature being visibly broken at the low end. The
    /// shortest possible plateau is one interval, so on a bar-unit ramp with `intervalCount == 1` an
    /// unclamped one-bar window covers the plateau *entirely* — the indicator never turns off, and a
    /// warning that is always on is a readout, not a warning. The defaults hide this
    /// (`automatorDefaultBars` is 4, so the window is a quarter of the plateau), which is exactly why
    /// it would otherwise reach the device.
    func window(bpm: Int, beatsPerBar: Int) -> Double {
        let oneBar: Double
        switch unit {
        case .bars: oneBar = 1
        case .seconds: oneBar = Double(max(1, beatsPerBar)) * 60.0 / Double(max(1, bpm))
        }
        return min(oneBar, plateauUnits / 2)
    }

    /// Whether the warning should be showing at this instant — the remaining plateau has fallen inside
    /// the window. The one question every carrier asks.
    func isArmed(bpm: Int, beatsPerBar: Int) -> Bool {
        unitsRemaining <= window(bpm: bpm, beatsPerBar: beatsPerBar)
    }

    /// What the run caption reads while the warning shows — the accessible carrier, and the reason the
    /// caption is a decided carrier rather than the fallback one (ADR 0131 §3a): the drill-surface edge
    /// and the staircase pre-light are both silent to VoiceOver, and this is not.
    ///
    /// Deliberately says nothing about *when* ("next bar"): the window is at most a bar but is clamped
    /// to half a short plateau, and a seconds-keyed ramp has no bar to name. It states what is coming
    /// and in which direction, which is what the player has to prepare for.
    var caption: String {
        guard let to else { return "Last bar" }
        return isRise ? "Speeding up to \(to)" : "Backing off to \(to)"
    }
}
