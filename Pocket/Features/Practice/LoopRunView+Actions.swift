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
        command = clampPercent(LoopCommandRamp.percent(loop.command))
        // The warm-up floor sits a step below command (not *at* it) so the ramp has room to climb;
        // a saved speed that's already lower wins (device feedback 2026-07-17). The rule itself lives
        // on `Loop.rampFloor` so the model-level staircase and this one cannot disagree (ADR 0129).
        working = clampPercent(LoopCommandRamp.percent(loop.rampFloor))
        // Restore the saved ramp shape (ADR 0057 follow-up); migrated/new loops read the
        // declaration defaults (no intermediate stops, single drop, one rep per step).
        steps = loop.rampWarmupSteps
        reachSteps = loop.rampReachSteps
        backoffSteps = loop.rampBackoffSteps
        repsPerStep = max(Self.repsRange.lowerBound, loop.rampRepsPerStep)
        dwell = max(1, loop.rampDwellIntervals)
        targetOverride = loop.targetSpeedOverride.map { LoopCommandRamp.percent($0) }
        includeBackoff = loop.includeBackoff
        backoffOverride = loop.backoffSpeedOverride.map { LoopCommandRamp.percent($0) }
        // In a routine, a naturally-finished ramp auto-advances the session (never a manual stop) —
        // and logs the block as a completed unit-run first (ADR 0117), before advancing tears this
        // screen down. The standalone path replaces this hook in `armCompletionOffer`, which logs
        // the same way.
        if let routineContext {
            model.onFinished = {
                logCompletedRun()
                routineContext.onFinished()
            }
        }
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
        loop.includeBackoff = includeBackoff
        loop.backoffSpeedOverride = backoffOverride.map { Double($0) / 100 }
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

    /// Start tapped: run the visual count-in first — always in a routine (ADR 0071), and for a
    /// standalone run when the Count-in setting is on (device feedback 2026-07-17: loops deserve the
    /// same lead-in exercises get). With the setting off standalone, start immediately.
    func startTapped() {
        if routineContext != nil || AppSettings.countInEnabled {
            showCountIn = true
            haptic(.light)
        } else {
            commitAndStart()
        }
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
        // Standalone: arm the post-run completion offer (ADR 0082, mirroring ADR 0079), capturing the
        // reach being run so the screen's copy/target stay stable even if the setup is edited after. In
        // a routine the hook is the player's advance (set in `seedIfNeeded`), so leave it untouched.
        if routineContext == nil { armCompletionOffer() }
        // Start the practice log's clock (ADR 0117) — consumed by whichever completion hook fires.
        runStartedAt = .now
        // If a take is armed, begin capture **before** playback starts, so the session flips to
        // `.playAndRecord` with no audio in flight (no mid-play glitch — device feedback 2026-07-17).
        // The count-in has already run, so the take is the playing only, not the lead-in.
        recorder.beginArmedTake()
        model.start(ramp: routine)
        AppSettings.recordPracticed()
        Analytics.send(.practiceStarted(kind: .loop,
                                        source: routineContext == nil ? .standalone : .routine,
                                        sinceInstall: AppSettings.installAgeBucket))
        haptic(.medium)
    }

    /// Wire `model.onFinished` to raise the post-run completion screen for a standalone run (ADR 0082).
    /// Fires only when the ramp runs its full course (dwell → summit → back off), never on a manual
    /// stop. The reach/command (percent of original) are snapshotted now so the offer stays stable
    /// regardless of later edits.
    private func armCompletionOffer() {
        let summitedReach = reach
        let summitedCommand = command
        model.onFinished = {
            Analytics.send(.practiceCompleted(kind: .loop))
            logCompletedRun()
            completion = RunCompletion(reach: summitedReach, command: summitedCommand)
        }
    }

    /// Append this run to the **practice log** (ADR 0117) — one row per completed unit-run, at the
    /// natural-completion seam shared by a standalone run and a routine block.
    ///
    /// A loop's tempo is a **percent of original** (ADR 0082), never a BPM, so it lands in
    /// `tempoPercent` and the BPM field stays empty; the two are never both set. As on the exercise
    /// side the logged value is **command** — the speed the loop is owned at — read before the Done
    /// screen's optional promote, so the row records what was played, not what was agreed to next.
    func logCompletedRun() {
        guard let startedAt = runStartedAt else { return }
        runStartedAt = nil
        PracticeLogWriter.log(kind: .loop,
                              startedAt: startedAt,
                              unitUID: loop.uid,
                              routineUID: routineContext?.routineUID,
                              tempoPercent: command,
                              into: modelContext)
    }

    /// The tempo anchors the standalone completion screen sizes its revision offer from (ADR 0082,
    /// mirroring ADR 0079 / 0134). Percent-of-original throughout — a loop's command is a percent, so
    /// every value here reads "90%", never a BPM. The settle target is `loop.backoffPercent`, derived
    /// in the same percent domain `CommandRamp` works in so the offer and the tail cannot disagree.
    func completionAnchors(_ finished: RunCompletion) -> CommandOffer.Anchors {
        .init(command: finished.command,
              floor: Self.percentRange.lowerBound, ceiling: Self.percentRange.upperBound,
              raiseTarget: CommandOffer.raisedCommand(reach: finished.reach,
                                                      ceiling: Self.percentRange.upperBound),
              settleTarget: loop.backoffPercent)
    }

    /// Commit the post-run completion screen (ADR 0082) — the same `RoutineBlockDoneView` a routine
    /// block finishes on, reused for a standalone loop run: an optional mastery self-rating, an
    /// optional journal note, and the opt-in promote, committed together in the one Finish. Each may
    /// be a no-op (unchanged rating, empty note, toggle off). When on, `promoteTo` is the chosen
    /// (possibly custom) command percent — already clamped by the screen's stepper — so command moves
    /// there and a caught-up reach pin drops. Everything lands through the single write path
    /// (`persist`, ADR 0057); there's no following Start, so this *is* the commit.
    func commitCompletion(mastery: Int?, note: String, kind: EntryKind,
                          revision: CommandOffer.Revision?) {
        loop.mastery = mastery
        _ = JournalWriter.add(to: .loop(loop), text: note, kind: kind, into: modelContext)
        switch revision {
        case .raise(let percent):
            command = percent
            clearOverrideIfCaughtUp()
        case .settle(let percent):
            // Through the local setup state, as on the exercise screen: `persist()` re-derives the
            // model from these `@State` percents (ADR 0057). A loop needs no floor pull-down —
            // `Loop.rampFloor` forces its own gap below command — but `working` is held here as a raw
            // percent that `adjustWorking` keeps at or below command, so it comes down with it.
            working = min(working, percent)
            command = percent
            backoffOverride = CommandOffer.survivingBackoffPin(backoffOverride, command: percent)
        case .none:
            break
        }
        persist()
        haptic(.light)
        completion = nil
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

    /// Pin the backoff floor to a nudged value (no haptic — `StepperButton` owns it). Clamped
    /// **below** command; landing exactly on the auto value clears the pin (user-testing note 6).
    func adjustBackoff(by delta: Int) { pinBackoff((backoffOverride ?? autoBackoff) + delta) }

    /// Pin the backoff floor to a typed value (note 6) — same clamp, with the type-commit haptic.
    func setBackoff(_ value: Int) { pinBackoff(value); haptic(.light) }

    /// Clear the pin — the backoff falls back to the auto derivation below the current command.
    func resetBackoff() { backoffOverride = nil; haptic(.light) }

    func pinBackoff(_ value: Int) {
        let clamped = max(Self.percentRange.lowerBound, min(command - 1, value))
        backoffOverride = (clamped == autoBackoff) ? nil : clamped
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
    /// Whether the ramp backs off below command after the summit (user-testing note 6) — toggling it
    /// arms Save. Defaulted so existing snapshot constructions stay terse; `current` always sets it.
    var includeBackoff: Bool = true
    /// The pinned backoff floor (% of original) or `nil` for the auto derivation — editing it arms Save.
    var backoffOverride: Int?
}
