import SwiftData
import SwiftUI

/// A **training run** on one song loop (ADR 0046, Phase B): the loop counterpart of
/// `ExerciseRunView`. A measured loop trains the same command-anchored staircase as an exercise —
/// warm up → dwell → reach → back off — but against its **time-stretched audio**, so the tempos
/// are percent-of-original (`×`) rather than absolute BPM. It owns a `LoopRunModel` (and through it
/// a private `PracticeAudioEngine`), so a Practice loop run is independent of the waveform screen.
///
/// Two modes on one screen, mirroring the exercise run:
/// - **Set up** (stopped): edit the warm-up **working** floor and owned **command** (as % of
///   original), with the derived **reach**, the warm-up/reach/back-up step granularity, and the
///   routine drawn as a staircase. A one-tap **promote** ratchets command up to the reach.
/// - **Running**: the live playback speed (climbing as the ramp steps the audio rate) over the
///   looping region, with pause / resume / stop.
///
/// **Start** commits the edits to the loop (`speed` = working, `promoteCommand` = command) and
/// hands the engine a `CommandRamp` (percent units, `.seconds` intervals) via `LoopRunModel`. Edits
/// live in local state until Start, so leaving without starting discards them.
struct LoopRunView: View {
    let loop: Loop
    /// Routine-session chrome (progress, Skip, auto-advance) when a block in a routine; `nil` standalone.
    var routineContext: RoutineRunContext?
    @State private var model: LoopRunModel
    @Environment(\.modelContext) private var modelContext

    // Local edit state (percent of original), seeded on appear, committed only on Start.
    @State private var working = 0
    @State private var command = 0
    @State private var steps = 0
    @State private var reachSteps = 0
    @State private var backoffSteps = 0
    @State private var repsPerStep = LoopCommandRamp.defaultRepsPerStep
    /// The top-level "Practice Settings" disclosure — collapsed by default so the run screen opens on
    /// the summary + staircase (parity with the exercise run); expands to reveal tempos/reps/Steps.
    @State private var showSettings = false
    @State private var showSteps = false
    /// Whether the routine count-in overlay is showing (routine mode only) — gates the run start.
    @State private var showCountIn = false
    @State private var seeded = false
    /// The practice journal sheet — authoring lives here now (ADR 0058), reachable from the nav bar.
    @State private var showingJournal = false
    /// The setup as last persisted — captured on seed and after each Save, so the Save Changes
    /// button shows only while the edits differ (ADR 0057). All six persisted fields — the two
    /// tempos and the four ramp-shape controls (ADR 0057 follow-up) — are tracked, so editing any
    /// of them arms Save Changes.
    @State private var baseline: LoopSetupState?

    private var current: LoopSetupState {
        LoopSetupState(working: working, command: command, warmupSteps: steps,
                       reachSteps: reachSteps, backoffSteps: backoffSteps, repsPerStep: repsPerStep)
    }
    private var isDirty: Bool { baseline.map { $0 != current } ?? false }

    private static let repsRange = 1...8

    /// Playback-speed bounds as integer percent (the engine clamps 0.25×–2.0×).
    private static let percentRange =
        Int(TempoMath.minSpeed * 100)...Int(TempoMath.maxSpeed * 100)

    init(loop: Loop, routineContext: RoutineRunContext? = nil) {
        self.loop = loop
        self.routineContext = routineContext
        _model = State(initialValue: LoopRunModel(loop: loop))
    }

    /// The reach (% of original) derived from the (local) command — proportional + clamped via the
    /// `×`-unit `TempoStretch`, mapped back to percent.
    private var reach: Int {
        LoopCommandRamp.percent(TempoStretch.targetSpeed(forCommand: Double(command) / 100))
    }

    /// The warm-up step size (percent points) the chosen number of intermediate stops implies.
    private var stepPercent: Int {
        CommandRamp.warmupStepBPM(working: working, command: command, intermediateSteps: steps)
    }

    /// The routine the current edits describe — the staircase preview and the exact `CommandRamp`
    /// (percent units) handed to the run on Start.
    private var routine: CommandRamp {
        CommandRamp(working: working, command: command, target: reach, stepBPM: stepPercent,
                    intervalCount: max(1, repsPerStep), unit: .bars,
                    dwellIntervals: LoopCommandRamp.defaultDwellIntervals, includeBackoff: true,
                    reachSteps: reachSteps, backoffSteps: backoffSteps)
    }

    private var hasReach: Bool { reach > command }
    private var isRunning: Bool { model.isRunning }
    private var title: String { loop.name.isEmpty ? "Loop" : loop.name }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if isRunning {
                    liveReadout
                } else {
                    practiceSettings
                }
                RoutineStairs(plateaus: routine.plateaus, tint: PocketColor.practice,
                              currentIndex: model.currentPlateau(in: routine))
                if !isRunning { promoteButton }
                if !isRunning, isDirty { saveChangesButton }
                if !isRunning, routineContext == nil {
                    JournalPreviewSection(owner: .loop(loop)) { showingJournal = true }
                        .padding(.top, 4)
                }
            }
            .padding(24)
            .animation(.easeInOut(duration: 0.2), value: isDirty)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .routineSessionChrome(routineContext)
        .safeAreaInset(edge: .bottom) { transport }
        .overlay { if showCountIn { RoutineCountInOverlay(onComplete: countInFinished) } }
        .keepAwakeDuringPractice()   // Settings V1 (ADR 0050)
        .onAppear(perform: seedIfNeeded)
        .task { await model.loadIfNeeded(); maybeAutoStart() }
        .onDisappear { model.stop() }
        .sheet(isPresented: $showingJournal) {
            JournalSheet(owner: .loop(loop),
                         onAdd: addJournalEntry,
                         onUpdate: { entry, text, kind in
                             JournalWriter.update(entry, text: text, kind: kind)
                             try? modelContext.save()
                         },
                         onDelete: { entry in
                             JournalWriter.delete(entry, from: modelContext)
                             try? modelContext.save(); haptic(.light)
                         })
        }
    }

    /// Write a new entry, snapshotting the loop's current mastery + command tempo (ADR 0058).
    private func addJournalEntry(_ text: String, _ kind: EntryKind) {
        if JournalWriter.add(to: .loop(loop), text: text, kind: kind, into: modelContext) {
            try? modelContext.save()
            haptic(.light)
        }
    }

    // MARK: - Live readout (running)

    private var liveReadout: some View {
        VStack(spacing: 18) {
            VStack(spacing: 2) {
                Text("\(model.currentPercent)%")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
                Text("of original tempo")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                Text("loop \(model.elapsedReps + 1)")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.practice)
                    .contentTransition(.numericText())
            }
            if model.isLoading {
                ProgressView().tint(PocketColor.practice)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Playing at \(model.currentPercent) percent of original tempo")
    }

    // MARK: - Setup (stopped)

    /// The collapsible Practice Settings panel — tempos + reps + Steps behind one disclosure, so the
    /// loop run opens on the summary + staircase (parity with the exercise run, ADR 0071).
    private var practiceSettings: some View {
        LoopSettingsPanel(
            expanded: $showSettings,
            working: working, command: command, reach: reach,
            onStepWorking: { adjustWorking(by: $0) }, onTypeWorking: { setWorking($0) },
            onStepCommand: { adjustCommand(by: $0) }, onTypeCommand: { setCommand($0) },
            repsPerStep: $repsPerStep, repsRange: Self.repsRange,
            stepsExpanded: $showSteps, warmupSteps: $steps, reachSteps: $reachSteps,
            backoffSteps: $backoffSteps, warmupStepBPM: stepPercent,
            hasReach: hasReach, tint: PocketColor.practice, onToggle: { haptic(.light) })
    }

    private var promoteButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                command = min(Self.percentRange.upperBound, reach)
            }
            haptic(.medium)
        } label: {
            Label("I own \(reach)% now — promote", systemImage: "arrow.up.circle.fill")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().stroke(PocketColor.practice, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Promote: I own \(reach) percent now")
    }

    /// Persist the tuning without starting a run (ADR 0057) — shown only while the setup differs
    /// from what's stored. A subtle filled capsule, distinct from the outlined Promote and the
    /// filled Start pill. Leaving still discards *unsaved* edits.
    private var saveChangesButton: some View {
        Button(action: saveChanges) {
            Label("Save changes", systemImage: "checkmark.circle.fill")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(PocketColor.practiceCircleWash))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save changes to this loop")
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Transport

    private var transport: some View {
        HStack(spacing: 14) {
            if isRunning {
                Button { model.stop(); haptic(.medium) } label: {
                    Image(systemName: "stop.fill")
                        .font(.futura(.title3))
                        .foregroundStyle(PocketColor.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(PocketColor.textSecondary.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and reset")
                Button { model.toggle(); haptic(.medium) } label: {
                    Label(model.transport == .playing ? "Pause" : "Resume",
                          systemImage: model.transport == .playing ? "pause.fill" : "play.fill")
                        .pocketRunButton
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    if model.loadFailed {
                        Text("Couldn't load this song's audio — the file may have moved or been deleted.")
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    Button(action: startTapped) {
                        Label("Start training", systemImage: "play.fill").pocketRunButton
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isLoading || model.loadFailed)
                    .accessibilityLabel("Start training routine")
                }
            }
            if let routineContext { RoutineSkipButton(context: routineContext) }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(PocketColor.background.opacity(0.95))
    }
}

// MARK: - Actions

private extension LoopRunView {

    /// Seed the editor once. With a measured command, load the saved speeds as-is; without one,
    /// default command to the loop's start speed and working to a floor below it (so the two start
    /// apart, not equal), mirroring `ExerciseRunView`.
    private func seedIfNeeded() {
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
        // In a routine, a naturally-finished ramp auto-advances the session (never a manual stop).
        model.onFinished = routineContext?.onFinished
        seeded = true
        baseline = current
    }

    /// Write the current tempos to the loop — shared by Save Changes and Start so the two write
    /// paths never diverge (ADR 0057). Re-baselines so the Save Changes button hides.
    private func persist() {
        loop.speed = Double(working) / 100
        loop.promoteCommand(to: Double(command) / 100)
        loop.rampWarmupSteps = steps
        loop.rampReachSteps = reachSteps
        loop.rampBackoffSteps = backoffSteps
        loop.rampRepsPerStep = repsPerStep
        try? modelContext.save()
        baseline = current
    }

    /// Save the tuning without starting a run (ADR 0057). Leaving still discards *unsaved* edits.
    private func saveChanges() {
        persist()
        haptic(.medium)
    }

    /// Start tapped: in a routine, run the count-in first (ADR 0071); standalone, start immediately.
    private func startTapped() {
        if routineContext != nil { showCountIn = true; haptic(.light) } else { commitAndStart() }
    }

    /// Auto-start on arrival when the context asks for it (Settings-gated; never the first block) and
    /// the audio is ready — routes through the same count-in as a tapped Start.
    private func maybeAutoStart() {
        if routineContext?.autoStart == true, !isRunning, !model.isLoading, !model.loadFailed {
            showCountIn = true
        }
    }

    /// The count-in reached zero — drop the overlay and begin the run.
    private func countInFinished() {
        showCountIn = false
        commitAndStart()
    }

    /// Persist the edits to the loop and start the run in one tap.
    private func commitAndStart() {
        persist()
        model.start(ramp: routine)
        haptic(.medium)
    }

    // Pure clamps — `StepperButton` owns the ±/hold-repeat haptics, so these must not fire their own.
    private func adjustWorking(by delta: Int) {
        working = min(command, max(Self.percentRange.lowerBound, working + delta))
    }
    private func adjustCommand(by delta: Int) {
        command = min(Self.percentRange.upperBound, max(working, command + delta))
    }

    /// Working stays in range and never above command (the floor sits below the owned speed).
    private func setWorking(_ value: Int) {
        working = min(command, max(Self.percentRange.lowerBound, value))
        haptic(.light)
    }

    /// Command stays in range and never below working; the reach re-derives automatically.
    private func setCommand(_ value: Int) {
        command = min(Self.percentRange.upperBound, max(working, value))
        haptic(.light)
    }

    private func clampPercent(_ value: Int) -> Int {
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
}

#Preview("Loop run") {
    let loop = Loop(name: "Chorus solo", start: 0.2, end: 0.4, speed: 0.7, repeats: 0)
    loop.commandTempo = 0.85
    return NavigationStack { LoopRunView(loop: loop) }
        .preferredColorScheme(.dark)
}
