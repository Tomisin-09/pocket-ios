import Foundation

/// Duration estimation and block-fitting for a **loop** ramp — the loop counterpart of
/// `SessionEstimate` (ADR 0129, extended after the device pass).
///
/// The two cannot share one estimator because a loop ramp's units are not an exercise's. A loop
/// reuses `CommandRamp` with the `.bars` interval mechanism **reinterpreted as loop passes**, and
/// its plateau values are *percent of original speed*, not BPM (`LoopCommandRamp`). So one interval
/// costs `regionSeconds ÷ (percent/100)` — the same passage takes longer the slower you play it —
/// where the exercise estimator prices bars against a meter. Feeding a loop ramp to
/// `SessionEstimate.seconds(forRamp:beatsPerBar:)` would silently produce a number in the wrong
/// units, which is precisely how loops fell out of the block model.
///
/// Foundation-only and unit-tested per AGENTS.md — this is tempo math, the kind that breaks quietly.
enum LoopEstimate {

    /// Seconds one pass through a `regionSeconds` region takes at `percent` of original speed.
    /// A non-positive percent (or region) yields zero rather than a division blow-up.
    static func passSeconds(regionSeconds: Double, percent: Int) -> Double {
        guard regionSeconds > 0, percent > 0 else { return 0 }
        return regionSeconds * 100.0 / Double(percent)
    }

    /// Seconds a whole loop ramp takes, integrating **per plateau** — each plateau's passes priced at
    /// that plateau's own speed, so a long warm-up at 70% is correctly dearer than the same number of
    /// passes at command.
    static func seconds(forRamp ramp: CommandRamp, regionSeconds: Double) -> Double {
        let perStep = Double(max(1, ramp.intervalCount))
        return ramp.plateaus.reduce(0) { total, plateau in
            total + Double(plateau.intervals) * perStep
                * passSeconds(regionSeconds: regionSeconds, percent: plateau.bpm)
        }
    }

    /// Whole minutes for one run of a loop ramp, floored at 1 (a block never reads "0 min").
    static func minutes(forRamp ramp: CommandRamp, regionSeconds: Double) -> Int {
        SessionEstimate.minutes(fromSeconds: seconds(forRamp: ramp, regionSeconds: regionSeconds))
    }

    /// Seconds one **dwell interval** costs — `intervalCount` passes at the command speed. The
    /// quantum the fit adds and removes, exactly as for an exercise.
    static func dwellIntervalSeconds(_ ramp: CommandRamp, regionSeconds: Double) -> Double {
        Double(max(1, ramp.intervalCount))
            * passSeconds(regionSeconds: regionSeconds, percent: ramp.command)
    }

    /// `ramp` resized to fill roughly `minutes` by moving the **dwell** only, bounded against the
    /// authored dwell by the shared `SessionEstimate.clampedDwell` (ADR 0129 as amended).
    ///
    /// Fitting a loop means changing how many times you play the passage, which is why the dwell — the
    /// consolidation hold at command — is the right place to spend a block's time here too. The
    /// warm-up, summit and back-off passes keep the staircase's shape.
    static func fitted(_ ramp: CommandRamp, toMinutes minutes: Int,
                       regionSeconds: Double) -> CommandRamp {
        guard minutes > 0 else { return ramp }
        let perInterval = dwellIntervalSeconds(ramp, regionSeconds: regionSeconds)
        guard perInterval > 0 else { return ramp }

        // Everything that isn't dwell, measured by pricing a one-interval dwell and removing it.
        var probe = ramp
        probe.dwellIntervals = 1
        let fixed = seconds(forRamp: probe, regionSeconds: regionSeconds) - perInterval

        let wanted = Int(((Double(minutes) * 60 - fixed) / perInterval).rounded())
        var fit = ramp
        fit.dwellIntervals = SessionEstimate.clampedDwell(wanted, authored: ramp.dwellIntervals)
        return fit
    }

    /// What a loop block **actually takes** once fitted to its allotment — the honest figure for the
    /// session readout, which departs from `plannedMinutes` exactly where the dwell clamp bites.
    /// `nil` minutes (a hand-authored block) is the ramp's own natural length.
    static func effectiveMinutes(forRamp ramp: CommandRamp, plannedMinutes: Int?,
                                 regionSeconds: Double) -> Int {
        guard let plannedMinutes else { return minutes(forRamp: ramp, regionSeconds: regionSeconds) }
        return minutes(forRamp: fitted(ramp, toMinutes: plannedMinutes, regionSeconds: regionSeconds),
                       regionSeconds: regionSeconds)
    }
}
