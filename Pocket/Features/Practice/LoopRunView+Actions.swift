import SwiftUI

// MARK: - Actions

/// The `LoopRunView` run-setup behaviour — seed / persist / start plus the tempo + reach clamps
/// (ADR 0057 write-path discipline, ADR 0075 reach override), in percent-of-original units. Split
/// out of `LoopRunView.swift` to keep each file under the 400-line cap; the view's edit state is
/// module-internal so this extension can drive it.
extension LoopRunView {

    /// Seed the editor once. With a measured command, load the saved speeds as-is; without one,
    /// default command to the loop's start speed and working to a floor below it (so the two start
    /// apart, not equal), mirroring `ExerciseRunView`.
    func seedIfNeeded() {
        guard !seeded else { return }
        if loop.hasMeasuredCommand {
            command = clampPercent(LoopCommandRamp.percent(loop.command))
            working = min(command, clampPercent(LoopCommandRamp.percent(loop.speed)))
        } else {
            command = clampPercent(LoopCommandRamp.percent(loop.speed))
            working = max(Self.percentRange.lowerBound, command - 15)
        }
        // Restore the saved ramp shape (ADR 0057 follow-up); migrated/new loops read the
        // declaration defaults (no intermediate stops, single drop, one rep per step).
        steps = loop.rampWarmupSteps
        reachSteps = loop.rampReachSteps
        backoffSteps = loop.rampBackoffSteps
        repsPerStep = max(Self.repsRange.lowerBound, loop.rampRepsPerStep)
        dwell = max(1, loop.rampDwellIntervals)
        targetOverride = loop.targetSpeedOverride.map { LoopCommandRamp.percent($0) }
        // In a routine, a naturally-finished ramp auto-advances the session (never a manual stop).
        model.onFinished = routineContext?.onFinished
        seeded = true
        baseline = current
    }

    /// Write the current tempos to the loop — shared by Save Changes and Start so the two write
    /// paths never diverge (ADR 0057). Re-baselines so the Save Changes button hides.
    func persist() {
        loop.speed = Double(working) / 100
        loop.promoteCommand(to: Double(command) / 100)
        // After promoteCommand (which auto-clears a caught-up pin), write the current pin — always
        // above command here, so it survives — or clear it when reset to auto (ADR 0075).
        loop.targetSpeedOverride = targetOverride.map { Double($0) / 100 }
        loop.rampWarmupSteps = steps
        loop.rampReachSteps = reachSteps
        loop.rampBackoffSteps = backoffSteps
        loop.rampRepsPerStep = repsPerStep
        loop.rampDwellIntervals = max(1, dwell)
        try? modelContext.save()
        baseline = current
    }

    /// Save the tuning without starting a run (ADR 0057). Leaving still discards *unsaved* edits.
    func saveChanges() {
        persist()
        haptic(.medium)
    }

    /// Start tapped: in a routine, run the count-in first (ADR 0071); standalone, start immediately.
    func startTapped() {
        if routineContext != nil { showCountIn = true; haptic(.light) } else { commitAndStart() }
    }

    /// Auto-start on arrival when the context asks for it (Settings-gated; never the first block) and
    /// the audio is ready — routes through the same count-in as a tapped Start.
    func maybeAutoStart() {
        if routineContext?.autoStart == true, !isRunning, !model.isLoading, !model.loadFailed {
            showCountIn = true
        }
    }

    /// The count-in reached zero — drop the overlay and begin the run.
    func countInFinished() {
        showCountIn = false
        commitAndStart()
    }

    /// Persist the edits to the loop and start the run in one tap.
    func commitAndStart() {
        persist()
        model.start(ramp: routine)
        haptic(.medium)
    }

    // Pure clamps — `StepperButton` owns the ±/hold-repeat haptics, so these must not fire their own.
    func adjustWorking(by delta: Int) {
        working = min(command, max(Self.percentRange.lowerBound, working + delta))
    }
    func adjustCommand(by delta: Int) {
        command = min(Self.percentRange.upperBound, max(working, command + delta))
        clearOverrideIfCaughtUp()
    }

    /// Working stays in range and never above command (the floor sits below the owned speed).
    func setWorking(_ value: Int) {
        working = min(command, max(Self.percentRange.lowerBound, value))
        haptic(.light)
    }

    /// Command stays in range and never below working; a pinned reach that command has caught up to
    /// is dropped (the reach re-derives above the new command), mirroring the model auto-clear.
    func setCommand(_ value: Int) {
        command = min(Self.percentRange.upperBound, max(working, value))
        clearOverrideIfCaughtUp()
        haptic(.light)
    }

    /// Pin the reach to a nudged value (no haptic — `StepperButton` owns it). Clamped **above**
    /// command; landing exactly on the auto value clears the pin so the caption reverts to "auto".
    func adjustReach(by delta: Int) { pinReach((targetOverride ?? autoReach) + delta) }

    /// Pin the reach to a typed value (ADR 0075) — same clamp, with the type-commit haptic.
    func setReach(_ value: Int) { pinReach(value); haptic(.light) }

    /// Clear the pin — the reach falls back to the auto derivation above the current command.
    func resetReach() { targetOverride = nil; haptic(.light) }

    func pinReach(_ value: Int) {
        let clamped = min(Self.percentRange.upperBound, max(command + 1, value))
        targetOverride = (clamped == autoReach) ? nil : clamped
    }

    /// Drop a pinned reach once command has risen to meet or pass it — a reach must stay above
    /// command (ADR 0075); the auto reach then takes over above the new command.
    func clearOverrideIfCaughtUp() {
        if let pin = targetOverride, pin <= command { targetOverride = nil }
    }

    func clampPercent(_ value: Int) -> Int {
        min(Self.percentRange.upperBound, max(Self.percentRange.lowerBound, value))
    }
}

/// Snapshot of the loop run-setup fields that persist — the two tempos (working + command %) plus
/// the four ramp-shape controls (ADR 0057 follow-up) — compared against the live values to decide
/// whether the Save Changes button shows (ADR 0057). Every persisted field is tracked, so editing
/// the ramp shape alone still arms Save Changes.
struct LoopSetupState: Equatable {
    var working: Int
    var command: Int
    var warmupSteps: Int
    var reachSteps: Int
    var backoffSteps: Int
    var repsPerStep: Int
    /// The command-plateau dwell (ADR 0078) — editing it arms the Save button.
    var dwell: Int
    /// The pinned reach (% of original) or `nil` for the auto derivation — editing it arms Save (ADR 0075).
    var targetOverride: Int?
}
