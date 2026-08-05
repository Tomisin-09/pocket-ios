import Foundation

/// **The click withdrawing itself** (ADR 0132) — the engine's half: which withdrawal is in force,
/// where the cycle's bar 0 sits, and what the cycle says about a tick about to be scheduled.
///
/// Split out of `StandaloneMetronomeEngine` like `+Warning` and `+Automator`: the core file sits at
/// the 400-line ceiling, and this is one concern. The arithmetic itself is the pure `ClickWithdrawal`
/// — everything here supplies the facts it cannot know on its own.
///
/// **This pays ADR 0131 §5's bill.** The captured origin is the same piece of engine state the
/// deferred audible tempo warning needs, so whichever feature was built first bought it for the
/// other; this one built it.
extension StandaloneMetronomeEngine {

    /// The withdrawal in force right now — the stored tier, with the three exclusions applied
    /// (ADR 0132 §4, as amended): the host must offer it, no ramp may be running, and no strum
    /// schedule may be armed. All three are facts the engine already holds, so nothing here has to
    /// know which screen it is on beyond the flag that screen set.
    ///
    /// `exercise: nil` until ADR 0132 Slice 2 adds the per-exercise override; `nil` is "inherit",
    /// which is exactly what every run means today.
    var activeWithdrawal: ClickWithdrawal {
        ClickWithdrawal.resolve(exercise: nil, global: AppSettings.clickWithdrawal,
                                onMetronomeTool: allowsClickWithdrawal,
                                rampRunning: isRampActive, strumArmed: strumSchedule != nil)
    }

    /// What the withdrawal says about a tick that is about to be scheduled, capturing — or dropping —
    /// the cycle's origin as eligibility changes.
    ///
    /// Capture is lazy rather than a separate step in `tick()` because this is called for exactly the
    /// ticks that need it, already holding the grid resolution the origin must be measured in. Dropping
    /// it the moment withdrawal stops applying is what makes a suspended cycle restart cleanly: arm the
    /// automator and the click goes full for the climb, stop it and the cycle begins again from the
    /// next downbeat, at bars 1–2 full.
    func withdrawalVerdict(forTick tick: Int, ticksPerBeat: Int) -> ClickWithdrawal.TickVerdict {
        let withdrawal = activeWithdrawal
        guard withdrawal != .off else {
            resetDrillOrigin()
            return .unchanged
        }
        let origin = drillOriginTick ?? captureDrillOrigin(eligibleAt: tick, ticksPerBeat: ticksPerBeat)
        return withdrawal.verdict(forTick: tick, originTick: origin,
                                  ticksPerBeat: ticksPerBeat,
                                  beatsPerBar: timeSignature.beats)
    }

    /// Capture and return the tick the cycle counts bar 0 from — the next bar downbeat at or after the
    /// tick withdrawal became eligible on (§8).
    ///
    /// The engine could not previously express that position at all: `tickIndex` counts sub-ticks from
    /// `phaseOrigin`, and nothing recorded where a drill's own bars began. Rounding to a downbeat is
    /// what keeps the cycle aligned to the meter when eligibility begins mid-bar, which it does
    /// whenever the tier is switched on mid-run or a ramp that suspended it stops.
    @discardableResult
    func captureDrillOrigin(eligibleAt tick: Int, ticksPerBeat: Int) -> Int {
        let origin = ClickWithdrawal.originTick(eligibleAt: tick, ticksPerBeat: ticksPerBeat,
                                                beatsPerBar: timeSignature.beats)
        drillOriginTick = origin
        return origin
    }

    /// Drop the captured origin so the next eligible tick re-captures it — the invalidation §8 calls
    /// the edge case to test.
    ///
    /// **Re-captured, never carried.** `reanchorPhase()` — a manual tempo change, a meter change, a
    /// subdivision change — restarts `tickIndex` at 0, so a carried origin would silently place every
    /// subsequent silent bar in the wrong place: the kind of defect that reads as "the feature feels
    /// wrong" rather than as a bug. Re-capturing restarts the cycle at bars 1–2 full, which is also
    /// the right behaviour — after a manual disruption you re-establish the pulse before withdrawing
    /// it again.
    func resetDrillOrigin() { drillOriginTick = nil }

    /// The level the click was voiced at on the bar **currently being heard** (§7) — what
    /// `BeatIndicator` reads instead of deciding separately when to go dark, so the visual and the
    /// audible cannot diverge: there is one decision, made once.
    ///
    /// The visual reads the heard bar; the audio decides on the scheduled tick, so these disagree by
    /// one look-ahead window — exactly as ADR 0131 §5 documents for the warning, and for the same
    /// reason. The indicator describes the present, the scheduler the near future, and neither should
    /// be made to follow the other.
    var heardWithdrawalLevel: ClickWithdrawal.Level {
        guard transport == .playing, currentBeat >= 0,
              let origin = drillOriginTick else { return .full }
        let ticksPerBeat = currentTicksPerBeat
        let bar = ClickWithdrawal.barIndex(forTick: currentBeat * ticksPerBeat, originTick: origin,
                                           ticksPerBeat: ticksPerBeat,
                                           beatsPerBar: timeSignature.beats)
        return activeWithdrawal.level(atBar: bar)
    }
}
