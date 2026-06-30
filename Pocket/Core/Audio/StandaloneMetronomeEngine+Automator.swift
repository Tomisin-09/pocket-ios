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

    /// Whether a ramp is driving the tempo — an explicit training routine (`run(ramp:)`) or a
    /// free-play automator that's been **started** (ADR 0048; arming alone no longer climbs).
    /// The single gate `tick()` and `start()` use to decide whether to accrue ramp progress and
    /// drive `bpm` from a ramp.
    var isRampActive: Bool { trainingRamp != nil || automatorRunning }

    /// Begin the free-play climb — the explicit **Start** (ADR 0048). Arming (the segmented
    /// control) only configured the ramp; this runs it. Plays the metronome if it's stopped,
    /// captures the floor at the current tempo, and counts in one bar before the climb engages
    /// (so you can settle in). No-op unless armed.
    func startAutomatorRun() {
        guard automatorEnabled else { return }
        if transport == .stopped { start() }
        engageAutomator()                       // floor = current tempo, progress zeroed
        countInStartBeat = currentBeat
        countInTarget = max(1, timeSignature.beats)
        automatorCountingIn = true
        automatorRunning = true
        pushNowPlaying()
    }

    /// Halt the climb — the explicit **Stop**. Leaves the metronome playing at the tempo it
    /// reached and the ramp still armed, so Start replays from the floor. The session is intact.
    func stopAutomatorRun() {
        automatorRunning = false
        automatorCountingIn = false
        pushNowPlaying()
    }

    /// Advance the pre-climb **count-in** (ADR 0048). Returns `true` while still counting in —
    /// the tick holds the floor — and `false` once the climb should drive (or when there's no
    /// count-in). On the count-in's final beat it engages the climb cleanly from here.
    func advanceCountIn() -> Bool {
        guard automatorCountingIn else { return false }
        if currentBeat - countInStartBeat >= countInTarget {
            automatorCountingIn = false
            engageAutomator()                   // start the climb from the downbeat we reached
            return false
        }
        return true
    }

    /// The count-in number to show before the climb (ADR 0048), or `nil` when not counting in —
    /// the meter's beats counted down to the downbeat where the climb engages.
    var automatorCountdown: Int? {
        guard automatorRunning, automatorCountingIn else { return nil }
        return max(1, countInTarget - max(0, currentBeat - countInStartBeat))
    }

    /// End a finished climb. A Practice **training run** ends the whole session (ADR 0046); a
    /// **free-play** automator instead just stops *running* and holds at the ceiling, so the
    /// click keeps going at the tempo you reached.
    func finishRamp() {
        if trainingRamp != nil {
            stop()
        } else {
            automatorRunning = false
            automatorCountingIn = false
            pushNowPlaying()
        }
    }

    /// **Infinite** mode (ADR 0048): no chosen target — the ramp simply climbs to the system
    /// ceiling. Derived from the ceiling so there's no separate flag to keep in sync.
    var automatorNoLimit: Bool { automatorCeiling >= Self.bpmRange.upperBound }

    /// Toggle infinite mode: on ⇒ ceiling at the system max; off ⇒ back to a sensible target
    /// (the floor plus the default headroom), so turning it off lands on a usable number.
    func setAutomatorNoLimit(_ noLimit: Bool) {
        setAutomatorCeiling(noLimit ? Self.bpmRange.upperBound
                                    : clampedBPM(automatorStartBPM + Self.automatorDefaultHeadroom))
    }

    /// The plateau index a **training run** is currently holding (ADR 0046) — drives the live
    /// highlight on the Practice staircase. `nil` when no explicit training ramp is driving
    /// (free-play or stopped), so the staircase falls back to its un-highlighted preview.
    var currentRampPlateau: Int? {
        guard let trainingRamp else { return nil }
        return trainingRamp.currentPlateauIndex(elapsedBars: Int(automatorBarsElapsed),
                                                elapsedSeconds: automatorSecondsElapsed)
    }

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
        if !enabled { stopAutomatorRun() }      // disarming ends any run (ADR 0048)
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
