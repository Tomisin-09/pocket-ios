import Foundation

/// Pure, UI-free **stretch** math: the *reach* tempo derived from a command tempo
/// (ADR 0045). The target sits a proportional step above the tempo the player
/// already owns — a flat increment is wrong because perceived difficulty tracks
/// *relative* change (a +10 BPM reach is a 14% leap at 70 BPM but 5% at 200), so
/// the stretch is proportional, with absolute clamps to stop it being trivial at
/// the low end or brutal at the top.
///
/// **Unit-generic on purpose.** The core `target(forCommand:…)` works on any unit
/// because the clamps are caller-supplied in the command's *own* unit: exercises
/// pass absolute BPM (`targetBPM`), and the planned loop progression (ADR 0046)
/// passes a fraction of original tempo (`×`) with `×`-unit clamps — reusing this
/// math unchanged rather than forking it.
///
/// Kept free of SwiftUI/AVFoundation so the clamping/rounding boundaries (the kind
/// of tempo math that breaks silently) are exhaustively unit-tested per AGENTS.md.
enum TempoStretch {

    /// Default proportional reach above the command tempo (6%).
    static let defaultProportion = 0.06

    /// Absolute BPM clamps on the exercise stretch: never less than +3 BPM (so the
    /// reach is real at slow tempos) and never more than +15 BPM (so it stays
    /// attainable at fast ones).
    static let bpmMinIncrease = 3.0
    static let bpmMaxIncrease = 15.0

    /// `×`-unit clamps on the **loop** stretch (ADR 0046, Phase B): a loop's tempo is a
    /// fraction of original, so the same proportional reach is clamped in `×` units —
    /// never less than +0.02× (so the reach is real on a heavily slowed loop) and never
    /// more than +0.10× (so it stays attainable near full tempo). The loop analogue of
    /// `bpmMinIncrease`/`bpmMaxIncrease`, feeding the unit-generic `target(forCommand:…)`.
    static let speedMinIncrease = 0.02
    static let speedMaxIncrease = 0.10

    /// Downward warm-up proportion and clamps, mirroring the upward stretch — used to
    /// suggest a working floor below a command tempo (ADR 0045).
    static let warmupProportion = 0.15
    static let warmupMinDrop = 5.0
    static let warmupMaxDrop = 20.0

    /// The reach above `command`: `command × (1 + proportion)`, with the *increase*
    /// (not the result) clamped to `minIncrease...maxIncrease` in the command's own
    /// unit. Returns the precise value; callers round per unit. `command ≤ 0` is
    /// returned unchanged (no meaningful reach above a non-positive tempo).
    static func target(forCommand command: Double,
                       proportion: Double = defaultProportion,
                       minIncrease: Double,
                       maxIncrease: Double) -> Double {
        guard command > 0 else { return command }
        let increase = (command * proportion).clamped(to: minIncrease...maxIncrease)
        return command + increase
    }

    /// Exercise convenience: the absolute-BPM target a whole-number command climbs
    /// toward, proportional and clamped to `+3…+15` BPM, rounded to whole BPM.
    static func targetBPM(forCommand command: Int,
                          proportion: Double = defaultProportion) -> Int {
        let reach = target(forCommand: Double(command), proportion: proportion,
                           minIncrease: bpmMinIncrease, maxIncrease: bpmMaxIncrease)
        return Int(reach.rounded())
    }

    /// Loop convenience (ADR 0046, Phase B): the `×`-of-original target a measured loop
    /// climbs toward — proportional and clamped to `+0.02…+0.10×`, reusing the unit-generic
    /// `target(forCommand:…)` unchanged (the loop analogue of `targetBPM`). Returns the
    /// precise `×`; callers round to whatever precision they display. `command ≤ 0` is
    /// returned unchanged.
    static func targetSpeed(forCommand command: Double,
                            proportion: Double = defaultProportion) -> Double {
        target(forCommand: command, proportion: proportion,
               minIncrease: speedMinIncrease, maxIncrease: speedMaxIncrease)
    }

    /// A sensible **warm-up floor** below `command` (ADR 0045): a proportional drop,
    /// clamped `5…20` BPM, mirroring the upward stretch. Used as the default working
    /// tempo the first time Training Mode is opened for an exercise with no measured
    /// command yet (so working starts below command rather than equal to it). Pure /
    /// unit-generic — not clamped to a device BPM range here; the caller clamps to its
    /// own range. `command ≤ 0` is returned unchanged.
    static func warmupFloorBPM(forCommand command: Int) -> Int {
        guard command > 0 else { return command }
        let drop = (Double(command) * warmupProportion).clamped(to: warmupMinDrop...warmupMaxDrop)
        return command - Int(drop.rounded())
    }

    /// The **backoff** tempo for the end-of-session tail (ADR 0045): drop *below*
    /// command by the same distance the target sits above it, so the session ends
    /// reinforcing clean control rather than the sloppy edge. Floored at `floor`
    /// (the working tempo) so it never undershoots the warm-up.
    static func backoffBPM(command: Int, target: Int, floor: Int) -> Int {
        max(floor, command - (target - command))
    }
}
