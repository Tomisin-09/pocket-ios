import SwiftData
import SwiftUI

// MARK: - Actions

/// The `ExerciseRunView` run-setup behaviour — seed / persist / start plus the tempo + reach clamps
/// (ADR 0057 write-path discipline, ADR 0075 reach override). Split out of `ExerciseRunView.swift`
/// to keep each file under the 400-line cap; the view's edit state is module-internal so this
/// extension can drive it.
extension ExerciseRunView {

    /// Seed the editor once. With a measured command, load the saved tempos as-is; without one
    /// (first open), default command to the exercise's current tempo and working to a sensible
    /// floor below it — so the two start apart, not equal (ADR 0045).
    func seedIfNeeded() {
        guard !seeded else { return }
        let range = StandaloneMetronomeEngine.bpmRange
        if exercise.hasMeasuredCommand {
            command = exercise.command
            working = exercise.workingTempo
        } else {
            command = exercise.currentTempo
            working = max(range.lowerBound, TempoStretch.warmupFloorBPM(forCommand: command))
        }
        steps = CommandRamp.intermediateSteps(working: working, command: command,
                                              stepBPM: exercise.rampStepBPM)
        reachSteps = max(0, exercise.rampReachSteps)
        backoffSteps = max(0, exercise.rampBackoffSteps)
        targetOverride = exercise.targetTempoOverride
        signature = TimeSignature.forStored(beats: exercise.beatsPerBar,
                                            noteValue: exercise.noteValue,
                                            accentBeats: exercise.accentBeats)
        // In a routine, a naturally-finished ramp auto-advances the session (ADR 0071). Fires only
        // on the ramp's own completion, never on a manual stop.
        engine.onRampFinished = routineContext?.onFinished
        seeded = true
        baseline = current
    }

    /// Write the current setup to the model — shared by Save Changes and Start so the two write
    /// paths never diverge (ADR 0057). Re-baselines so the Save Changes button hides.
    func persist() {
        exercise.workingTempo = working
        exercise.promoteCommand(to: command)          // command; auto-clears a caught-up pin
        // Write the reach pin after promoteCommand (which drops a caught-up one) — always above
        // command here, so it survives — or clear it when reset to auto (ADR 0075).
        exercise.targetTempoOverride = targetOverride
        exercise.rampStepBPM = stepBPM
        exercise.rampIntervalUnit = .bars
        exercise.rampIntervalCount = StandaloneMetronomeEngine.automatorDefaultBars
        exercise.dwellIntervals = StandaloneMetronomeEngine.automatorDefaultDwell
        exercise.includeBackoff = true
        exercise.rampReachSteps = reachSteps
        exercise.rampBackoffSteps = backoffSteps
        exercise.beatsPerBar = signature.beats
        exercise.noteValue = signature.noteValue
        try? modelContext.save()
        baseline = current
    }

    /// Save the tuning without starting a run (ADR 0057). Leaving still discards *unsaved* edits.
    func saveChanges() {
        persist()
        haptic(.medium)
    }

    /// Auto-start on arrival in a routine when the context asks (Settings-gated; never the first
    /// block). An exercise needs no separate visual count-in — `commitAndStart` runs the engine's own
    /// audible metronome count-in (per the Count-in setting), so a routine block gets the same lead-in
    /// as a standalone run instead of a doubled one.
    func maybeAutoStart() {
        if routineContext?.autoStart == true, !isRunning { commitAndStart() }
    }

    /// Persist the edits and hand the routine to this screen's own engine in one tap.
    func commitAndStart() {
        persist()
        // Stamp the exercise as practised now, so the planner's dueness / warm-up LRU advance
        // (V2 planner Slice 1). Persist() already saved; this rides the next context save.
        exercise.markPracticed()
        try? modelContext.save()
        // Meter → accents + count-in length (ADR 0052); a rhythm drill's click follows the strum
        // pattern (ADR 0071 R5) unless Settings opts out. Both set before `run(ramp:)` so the grid holds.
        engine.setTimeSignature(signature)
        engine.setStrumPattern(runStrumPattern)
        engine.run(ramp: routine)
        haptic(.medium)
    }

    /// The strum pattern the run should sound — a rhythm drill's pattern, unless the user turned off
    /// "Strumming click follows the pattern" (Settings); `nil` ⇒ a standard metronome click.
    var runStrumPattern: StrumPattern? {
        guard AppSettings.strumClickFollowsPattern else { return nil }
        return exercise.strumPattern ?? exercise.strumChordSheet?.strumPattern
    }

    // Steps are pure (`StepperButton` owns the ±/hold-repeat haptics); the typed setters keep their
    // own single haptic. Both clamp through the shared helpers below.
    func adjustWorking(by delta: Int) { working = clampWorking(working + delta) }
    func adjustCommand(by delta: Int) {
        command = clampCommand(command + delta); clearOverrideIfCaughtUp()
    }
    func setWorking(_ value: Int) { working = clampWorking(value); haptic(.light) }
    func setCommand(_ value: Int) {
        command = clampCommand(value); clearOverrideIfCaughtUp(); haptic(.light)
    }

    /// Pin the reach to a nudged value (no haptic — `StepperButton` owns it). Clamped **above**
    /// command; landing exactly on the auto value clears the pin so the caption reverts to "auto".
    func adjustReach(by delta: Int) { pinReach((targetOverride ?? autoReach) + delta) }

    /// Pin the reach to a typed value (ADR 0075) — same clamp, with the type-commit haptic.
    func setReach(_ value: Int) { pinReach(value); haptic(.light) }

    /// Clear the pin — the reach falls back to the auto derivation above the current command.
    func resetReach() { targetOverride = nil; haptic(.light) }

    func pinReach(_ value: Int) {
        let upper = StandaloneMetronomeEngine.bpmRange.upperBound
        let clamped = min(upper, max(command + 1, value))
        targetOverride = (clamped == autoReach) ? nil : clamped
    }

    /// Drop a pinned reach once command has risen to meet or pass it — a reach must stay above
    /// command (ADR 0075); the auto reach then takes over above the new command.
    func clearOverrideIfCaughtUp() {
        if let pin = targetOverride, pin <= command { targetOverride = nil }
    }

    /// Working stays in range and never above command (the floor sits below the owned tempo).
    func clampWorking(_ value: Int) -> Int {
        min(command, max(StandaloneMetronomeEngine.bpmRange.lowerBound, value))
    }

    /// Command stays in range and never below working; the reach re-derives automatically.
    func clampCommand(_ value: Int) -> Int {
        min(StandaloneMetronomeEngine.bpmRange.upperBound, max(working, value))
    }
}

/// Snapshot of the run-setup fields Start / Save persist — compared against the live values to
/// decide whether the Save Changes button shows (ADR 0057). Pure UI state, not a domain type.
struct ExerciseSetupState: Equatable {
    var working: Int
    var command: Int
    var steps: Int
    var reachSteps: Int
    var backoffSteps: Int
    var signature: TimeSignature
    /// The pinned reach (BPM) or `nil` for the auto derivation — editing it arms Save (ADR 0075).
    var targetOverride: Int?
}
