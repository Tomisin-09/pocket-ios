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

    /// The pure ramp built from the current config — the engine reads its `bpm(…)` each tick.
    /// The ramp starts at the captured floor and climbs to the ceiling. Internal so the
    /// engine's `tick()` (main file) can read it.
    var automatorRamp: MetronomeAutomator {
        MetronomeAutomator(enabled: automatorEnabled, startBPM: automatorStartBPM,
                           stepBPM: automatorStepBPM, intervalCount: automatorIntervalCount,
                           unit: automatorUnit, ceilingBPM: automatorCeiling)
    }

    /// Total steps from floor to ceiling — for the staircase graphic and the controls.
    var automatorTotalSteps: Int { automatorRamp.stepsToCeiling }

    /// How many steps the ramp has climbed so far (0…total) — drives the highlighted step on
    /// the staircase.
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
        }
        automatorUnit = unit
        automatorEnabled = true
        engageAutomator()   // capture the floor (current tempo) even while stopped
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
