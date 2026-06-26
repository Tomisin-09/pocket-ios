import Foundation

/// The standalone metronome's tempo-automator config (ADR 0043, slice 4), split out of
/// `StandaloneMetronomeEngine.swift` for file length — like `PracticeAudioEngine+Metronome`.
/// The live ramp stepping runs in the engine's `tick()`; this holds the config setters and
/// the derived readouts the panel shows. The engine's automator stored state is internal so
/// this split can drive it.
extension StandaloneMetronomeEngine {

    /// Default headroom for a freshly-armed ramp: the ceiling starts this far above the
    /// current tempo (the floor).
    static var automatorDefaultHeadroom: Int { 20 }

    /// How many intervals the command plateau holds — the dwell (ADR 0045). Auto, not exposed
    /// (the auto/minimal panel): consolidation gets the bulk of the reps by default.
    static var automatorDefaultDwell: Int { 4 }

    /// The free-play **linear** ramp built from the current config: climb from the captured
    /// floor to the ceiling in even steps. Drives free play and the linear staircase graphic.
    var automatorLinearRamp: MetronomeAutomator {
        MetronomeAutomator(enabled: automatorEnabled, startBPM: automatorStartBPM,
                           stepBPM: automatorStepBPM, intervalCount: automatorIntervalCount,
                           unit: automatorUnit, ceilingBPM: automatorCeiling)
    }

    /// The **command-anchored** ramp, when an exercise command is loaded (ADR 0045): warm up
    /// from the floor to command, dwell, summit at the ceiling (the target reach), back off.
    /// `nil` in free play, where the linear ramp drives instead.
    var automatorCommandRamp: CommandRamp? {
        guard let command = automatorCommandBPM else { return nil }
        return CommandRamp(working: automatorStartBPM, command: command, target: automatorCeiling,
                           stepBPM: automatorStepBPM, intervalCount: automatorIntervalCount,
                           unit: automatorUnit, dwellIntervals: Self.automatorDefaultDwell,
                           includeBackoff: true)
    }

    /// The ramp the engine's `tick()` drives — command-anchored when an exercise command is
    /// set, else the free-play linear ramp.
    var activeRamp: any TempoRamp { automatorCommandRamp ?? automatorLinearRamp }

    /// Total steps from floor to ceiling — for the linear staircase graphic and the controls.
    var automatorTotalSteps: Int { automatorLinearRamp.stepsToCeiling }

    /// How many steps the ramp has climbed so far (0…total) — drives the highlighted step on
    /// the linear staircase.
    var automatorCurrentStep: Int {
        guard automatorStepBPM > 0 else { return 0 }
        return min(abs(bpm - automatorStartBPM) / automatorStepBPM, automatorTotalSteps)
    }

    /// Drive the segmented Off / By Bars / By Time control. Turning *on* from off defaults the
    /// ceiling to the current tempo + headroom; switching bars↔time keeps the ceiling.
    func setAutomatorMode(_ mode: AutomatorMode) {
        switch mode {
        case .off: setAutomatorEnabled(false)
        case .bars: arm(unit: .bars)
        case .seconds: arm(unit: .seconds)
        }
    }

    /// Sensible interval defaults — bars are counted in small numbers, seconds in larger
    /// ones, so the two units start from very different values (and use different ranges in
    /// the UI).
    static var automatorDefaultBars: Int { 4 }
    static var automatorDefaultSeconds: Int { 30 }

    private func arm(unit: MetronomeIntervalUnit) {
        let wasOff = !automatorEnabled
        // Reset the interval to the unit's natural default when arming or switching unit —
        // "4 bars" and "30 seconds" aren't interchangeable values.
        if wasOff || unit != automatorUnit {
            automatorIntervalCount = unit == .bars ? Self.automatorDefaultBars
                                                   : Self.automatorDefaultSeconds
        }
        if wasOff {
            automatorCeiling = clampedBPM(bpm + Self.automatorDefaultHeadroom)
            // Arming from the panel is a free-play (linear) ramp; a command-anchored ramp is
            // set up only by loading an exercise (ADR 0045), so drop any stale command.
            automatorCommandBPM = nil
        }
        automatorUnit = unit
        automatorEnabled = true
        engageAutomator()   // capture the floor (current tempo) even while stopped
    }

    /// Make the armed ramp **command-anchored** at `command` (ADR 0045) — called by the bridge
    /// when loading a promoted exercise, after the mode/step/interval/ceiling are set. The
    /// ceiling already holds the exercise's target reach, so the ramp warms up to command,
    /// dwells, summits at the ceiling, then backs off. Re-engages a live ramp.
    func setAutomatorCommand(_ command: Int) {
        automatorCommandBPM = clampedBPM(command)
        if automatorEnabled, transport != .stopped { engageAutomator() }
    }

    /// Configure and arm the command-anchored **training routine** in one step (ADR 0045,
    /// Training Mode): floor = `working`, ceiling = the `target` reach, anchored at `command`,
    /// warming up in `stepBPM` increments — warm up → dwell → summit → backoff. The single
    /// action behind Training Mode's **Start**, so there's no separate "arm the automator"
    /// step. Order matters: `arm` (via `setAutomatorMode`) clears any stale command and resets
    /// the interval, so the step, ceiling and command are all set after it.
    func startTraining(working: Int, command: Int, target: Int, stepBPM: Int) {
        setBPM(working)
        setAutomatorMode(.bars)
        setAutomatorStepBPM(stepBPM)
        setAutomatorCeiling(target)
        setAutomatorCommand(command)
    }

    func setAutomatorEnabled(_ enabled: Bool) {
        guard enabled != automatorEnabled else { return }
        automatorEnabled = enabled
        if enabled, transport != .stopped { engageAutomator() }
    }

    /// Return to the **free-play launch defaults** — what you get on first open: 90 BPM, 4/4,
    /// no subdivision, automator off, session stopped and zeroed. Lets you leave a loaded
    /// exercise without quitting the screen (ADR 0043, slice 7). Run while stopped so the
    /// config setters just write values (no re-anchor / re-engage).
    func reset() {
        stop()
        setBPM(Self.defaultBPM)
        setTimeSignature(.standard)
        setSubdivision(.none)
        setAutomatorEnabled(false)
        automatorStepBPM = 5
        automatorUnit = .bars
        automatorIntervalCount = Self.automatorDefaultBars
        automatorCommandBPM = nil   // back to free-play (linear) defaults
    }

    func setAutomatorStepBPM(_ value: Int) {
        automatorStepBPM = max(1, value)
        if automatorEnabled, transport != .stopped { engageAutomator() }
    }

    func setAutomatorIntervalCount(_ value: Int) {
        automatorIntervalCount = max(1, value)
        if automatorEnabled, transport != .stopped { engageAutomator() }
    }

    func setAutomatorCeiling(_ value: Int) {
        automatorCeiling = clampedBPM(value)
        if automatorEnabled, transport != .stopped { engageAutomator() }
    }

    private func clampedBPM(_ value: Int) -> Int {
        min(Self.bpmRange.upperBound, max(Self.bpmRange.lowerBound, value))
    }
}
