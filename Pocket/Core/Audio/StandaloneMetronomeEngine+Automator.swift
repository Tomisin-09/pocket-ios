import Foundation

/// The standalone metronome's tempo-automator config (ADR 0043, slice 4), split out of
/// `StandaloneMetronomeEngine.swift` for file length — like `PracticeAudioEngine+Metronome`.
/// The live ramp stepping runs in the engine's `tick()`; this holds the config setters and
/// the derived readouts the panel shows. The engine's automator stored state is internal so
/// this split can drive it.
extension StandaloneMetronomeEngine {

    /// The automator's mode for the segmented control — off, or stepping by bars / by time.
    enum AutomatorMode: Hashable { case off, bars, seconds }

    /// The current mode derived from the stored config — `.off` unless armed, then the unit.
    var automatorMode: AutomatorMode {
        guard automatorEnabled else { return .off }
        return automatorUnit == .bars ? .bars : .seconds
    }

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

    /// The ramp the engine's `tick()` drives — an explicit training routine (`run(ramp:)`,
    /// ADR 0046) first, else the command-anchored free-play ramp when a command is loaded,
    /// else the free-play linear ramp. Spelled out rather than a `??` chain: mixing the
    /// concrete `CommandRamp?` and `MetronomeAutomator` operands through nested `??` defeats
    /// the existential type inference for `any TempoRamp`.
    var activeRamp: any TempoRamp {
        if let trainingRamp { return trainingRamp }
        if let automatorCommandRamp { return automatorCommandRamp }
        return automatorLinearRamp
    }

    /// Whether a ramp is driving the tempo — an explicit training routine (`run(ramp:)`) or
    /// the armed free-play automator. The single gate `tick()` and `start()` use to decide
    /// whether to accrue ramp progress and drive `bpm` from a ramp.
    var isRampActive: Bool { trainingRamp != nil || automatorEnabled }

    /// Run a command-anchored training routine directly (ADR 0046): the Practice layer hands
    /// the engine a fully-formed `CommandRamp`, which drives the tempo from its working floor
    /// through dwell → summit → backoff, instead of arming the free-play automator. This
    /// replaces ADR 0045's `startTraining`, which routed through the automator setters and so
    /// made arming and training mutually exclusive. Stops any current session, sets the floor,
    /// and begins playing — `start()` engages the ramp (it's `isRampActive`).
    func run(ramp: CommandRamp) {
        if transport != .stopped { stop() }
        trainingRamp = ramp
        setBPM(ramp.working)
        start()
    }

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
