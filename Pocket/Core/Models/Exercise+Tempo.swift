import Foundation

/// `Exercise`'s **tempo model** — the working / command / reach / backoff anchors, the derivations
/// between them, and the `CommandRamp` a run is launched from (ADR 0045/0046/0075). Split out of
/// `Exercise.swift` to keep each file under the 400-line cap; these are the model's own computed
/// accessors, not a separate concern, so they stay on the type rather than moving to a helper.
extension Exercise {

    /// The warm-up **floor** — the comfortable tempo a session's ramp begins from (ADR
    /// 0045). A clarity alias over the `currentTempo` storage (kept for migration); new
    /// code should prefer this name.
    var workingTempo: Int {
        get { currentTempo }
        set { currentTempo = newValue }
    }

    /// The **effective** command tempo: the measured `commandTempo` once promoted, else the
    /// working tempo (ADR 0045) — an un-promoted exercise's command is taken as where it's
    /// currently practised, so the reach still computes and the UI degrades to the old
    /// light model gracefully.
    var command: Int { commandTempo ?? currentTempo }

    /// Whether a command tempo has been measured/promoted yet (vs falling back to working).
    var hasMeasuredCommand: Bool { commandTempo != nil }

    /// The floor the ramp actually climbs **from** (ADR 0129 sub-decision 1).
    ///
    /// `workingTempo` is a straight alias over `currentTempo`, so an exercise with no promoted command
    /// has **working == command** — and `CommandRamp` then emits neither a warm-up (`command > working`
    /// is false) nor a backoff (the derived backoff lands *on* command, which isn't below it). That is
    /// why an un-promoted drill runs as a bare dwell plus summit, three of the four documented phases
    /// missing. With no measured command, derive the floor instead: `TempoStretch.warmupFloorBPM` is the
    /// helper ADR 0045 wrote for exactly this case and which nothing ever called.
    ///
    /// **Derived, never stored** — it vanishes the moment a real command is promoted, so nothing already
    /// authored is rewritten and there is no migration to owe.
    var rampFloor: Int {
        hasMeasuredCommand ? workingTempo : TempoStretch.warmupFloorBPM(forCommand: command)
    }

    /// The reach derived from the current `command` (ADR 0045): proportional + clamped. The
    /// **auto** value, kept pure so a reset-to-auto affordance can fall back to it. Read
    /// `reachTempo` for the effective reach.
    var derivedTarget: Int { TempoStretch.targetBPM(forCommand: command) }

    /// The **effective** reach (BPM): the pinned `targetTempoOverride` when set, else the auto
    /// `derivedTarget` (ADR 0075). Every surface that renders "the goal" reads this so a pin
    /// shows through. Mirrors `Loop.targetSpeed`.
    var reachTempo: Int { targetTempoOverride ?? derivedTarget }

    /// Whether the reach is a manual pin vs the auto derivation — gates the reset-to-auto affordance.
    var hasTargetOverride: Bool { targetTempoOverride != nil }

    /// The **auto** backoff floor derived from the current command / reach / working (user-testing
    /// note 6) — the fallback for reset-to-auto. Read `backoffTempo` for the effective value.
    /// Takes `rampFloor`, not `workingTempo`, so the backoff shown on a surface can never disagree with
    /// the one `ramp` actually plays (ADR 0129 sub-decision 1).
    var derivedBackoff: Int {
        TempoStretch.backoffBPM(command: command, target: reachTempo, floor: rampFloor)
    }

    /// The **effective** backoff floor (BPM): the pinned `backoffTempoOverride` when set, else the
    /// auto `derivedBackoff` (note 6). Mirrors `reachTempo`.
    var backoffTempo: Int { backoffTempoOverride ?? derivedBackoff }

    /// Whether the backoff is a manual pin vs the auto derivation — gates the reset-to-auto affordance.
    var hasBackoffOverride: Bool { backoffTempoOverride != nil }

    /// The command-anchored **training routine** this exercise prescribes (ADR 0045/0046):
    /// warm up from the working floor to the owned command, dwell there, summit briefly at the
    /// derived reach, then back off below command. The single pure seam Practice launches a run
    /// from — `engine.run(ramp:)` drives this `CommandRamp` directly instead of routing through
    /// the automator setters. Built entirely from the saved **native** recipe (`rampStepBPM` /
    /// interval / unit / `dwellIntervals` / `includeBackoff`). Pure and UI-free, so the plateau
    /// math stays unit-tested per AGENTS.md.
    var ramp: CommandRamp {
        CommandRamp(working: rampFloor, command: command, target: reachTempo,
                    stepBPM: max(1, rampStepBPM), intervalCount: max(1, rampIntervalCount),
                    unit: rampIntervalUnit, dwellIntervals: max(1, dwellIntervals),
                    includeBackoff: includeBackoff,
                    reachSteps: max(0, rampReachSteps), backoffSteps: max(0, rampBackoffSteps),
                    backoffOverride: backoffTempoOverride)
    }

    /// Promote a newly-owned tempo to `command` (ADR 0045 / 0075). The auto reach is derived, so
    /// promotion is a single write — but a **pinned** reach (`targetTempoOverride`) that the new
    /// command has caught up to is auto-cleared (a reach must stay above command), reverting to the
    /// auto value. No longer writes the vestigial `targetTempo` (ADR 0075).
    func promoteCommand(to tempo: Int) {
        commandTempo = tempo
        // Bind the achievement to the rhythm it was just measured in (ADR 0121). Every promote runs
        // through here, so the binding can't be forgotten at a call site; `nil` when the drill states
        // no rhythm, which is the honest record of "measured, rhythm unstated".
        commandNotesPerBeat = noteRate?.perBeat
        if let pinned = targetTempoOverride, pinned <= command { targetTempoOverride = nil }
    }

    /// The Italian tempo marking for the current working tempo (ADR 0043, slice 1) —
    /// "Andante", "Allegro", … Pure derived from `currentTempo`.
    var tempoMarking: TempoMarking { TempoMarking.marking(forBPM: Double(currentTempo)) }
}
