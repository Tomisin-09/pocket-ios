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
        dwell = max(1, exercise.dwellIntervals)
        targetOverride = exercise.targetTempoOverride
        includeBackoff = exercise.includeBackoff
        backoffOverride = exercise.backoffTempoOverride
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
        exercise.dwellIntervals = max(1, dwell)
        exercise.includeBackoff = includeBackoff
        exercise.backoffTempoOverride = backoffOverride
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
        // Standalone: arm the post-run completion offer (ADR 0079), capturing the reach being run so
        // the screen's copy/target stay stable even if the returned setup is edited afterward. In a
        // routine the hook is the player's advance (set in `seedIfNeeded`), so leave it untouched.
        if routineContext == nil { armCompletionOffer() }
        // Meter → accents + count-in length (ADR 0052); a rhythm drill's click follows the strum
        // pattern (ADR 0071 R5) unless Settings opts out. Both set before `run(ramp:)` so the grid holds.
        engine.setTimeSignature(signature)
        engine.setStrumPattern(runStrumPattern)
        // If a take is armed, arm the record session + start capture *before* the engine runs, so its
        // `configureSession()` (guarded) leaves `.playAndRecord` in place rather than flipping mid-run
        // (ADR 0069). The exercise's count-in is the engine's audible metronome, so a speaker take
        // catches a couple of count-in clicks; a headphone take stays clean.
        recorder.beginArmedTake()
        engine.run(ramp: routine)
        haptic(.medium)
    }

    /// Wire `onRampFinished` to raise the post-run completion screen for a standalone run (ADR 0079).
    /// Fires only when the ramp runs its full course (dwell → summit → backoff), never on a manual
    /// stop. The reach/command are snapshotted now so the offer is stable regardless of later edits.
    private func armCompletionOffer() {
        let summitedReach = reach
        let summitedCommand = command
        engine.onRampFinished = {
            completion = RunCompletion(reach: summitedReach, command: summitedCommand)
        }
    }

    /// The promote offer for the standalone completion screen (ADR 0079) — `nil` when the
    /// (ceiling-clamped) reach isn't above command. The target defaults to the reach and is editable
    /// from just above the summited command up to the BPM ceiling.
    func completionPromoteConfig(_ finished: RunCompletion) -> RoutineBlockDoneView.PromoteConfig? {
        let ceiling = StandaloneMetronomeEngine.bpmRange.upperBound
        guard PromoteOffer.canPromote(reach: finished.reach, command: finished.command, ceiling: ceiling)
        else { return nil }
        return .init(defaultTarget: PromoteOffer.promotedCommand(reach: finished.reach, ceiling: ceiling),
                     minValue: finished.command + 1, maxValue: ceiling)
    }

    /// Commit the post-run completion screen (ADR 0079) — the same `RoutineBlockDoneView` a routine
    /// block finishes on, reused for a standalone run: an optional mastery self-rating, an optional
    /// journal note, and the opt-in promote, committed together in the one Finish. Each may be a no-op
    /// (unchanged rating, empty note, toggle off). When on, `promoteTo` is the chosen (possibly custom)
    /// command — already clamped by the screen's stepper — so command moves there and a caught-up reach
    /// pin drops; everything lands through the single write path (`persist`, ADR 0057) — there's no
    /// following Start, so this *is* the commit.
    func commitCompletion(mastery: Int?, note: String, promoteTo: Int?) {
        exercise.mastery = mastery
        _ = JournalWriter.add(to: .exercise(exercise), text: note, kind: .note, into: modelContext)
        if let promoteTo {
            command = promoteTo
            clearOverrideIfCaughtUp()
        }
        persist()
        haptic(.light)
        completion = nil
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

    /// Pin the backoff floor to a nudged value (no haptic — `StepperButton` owns it). Clamped
    /// **below** command; landing exactly on the auto value clears the pin (user-testing note 6).
    func adjustBackoff(by delta: Int) { pinBackoff((backoffOverride ?? autoBackoff) + delta) }

    /// Pin the backoff floor to a typed value (note 6) — same clamp, with the type-commit haptic.
    func setBackoff(_ value: Int) { pinBackoff(value); haptic(.light) }

    /// Clear the pin — the backoff falls back to the auto derivation below the current command.
    func resetBackoff() { backoffOverride = nil; haptic(.light) }

    func pinBackoff(_ value: Int) {
        let lower = StandaloneMetronomeEngine.bpmRange.lowerBound
        let clamped = max(lower, min(command - 1, value))
        backoffOverride = (clamped == autoBackoff) ? nil : clamped
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

/// A just-finished standalone run awaiting the post-run promote offer (ADR 0079). Snapshotted at the
/// moment the ramp completes so the copy/target stay stable even if the returned setup is edited.
/// `Identifiable` so it drives a `fullScreenCover(item:)`.
struct RunCompletion: Identifiable, Equatable {
    let id = UUID()
    /// The reach the run summited — the promote's default target.
    let reach: Int
    /// The command the run held — the floor the editable promote value sits above, and what the
    /// "anything to promote?" gate compares against (ADR 0079 §5).
    let command: Int
}

/// Snapshot of the run-setup fields Start / Save persist — compared against the live values to
/// decide whether the Save Changes button shows (ADR 0057). Pure UI state, not a domain type.
struct ExerciseSetupState: Equatable {
    var working: Int
    var command: Int
    var steps: Int
    var reachSteps: Int
    var backoffSteps: Int
    /// The command-plateau dwell (ADR 0078) — editing it arms the Save button.
    var dwell: Int
    var signature: TimeSignature
    /// The pinned reach (BPM) or `nil` for the auto derivation — editing it arms Save (ADR 0075).
    var targetOverride: Int?
    /// Whether the routine backs off below command after the summit (user-testing note 6) —
    /// toggling it arms Save.
    var includeBackoff: Bool
    /// The pinned backoff floor (BPM) or `nil` for the auto derivation — editing it arms Save (note 6).
    var backoffOverride: Int?
}
