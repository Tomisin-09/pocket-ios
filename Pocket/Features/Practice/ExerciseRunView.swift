import SwiftData
import SwiftUI

/// A **training run** on one exercise (ADR 0046, Phase A): the screen reached by tapping a unit in
/// Practice. It **owns its own `StandaloneMetronomeEngine`**, so a drill here never disturbs the
/// metronome screen. Two modes: **set up** (stopped) edits the three tempos — working floor, command,
/// derived reach — plus warm-up steps, drawn as a staircase with a one-tap promote; **running** shows
/// the live BPM and the beat/template surface. **Start** commits the edits and hands the engine a
/// `CommandRamp` (`engine.run(ramp:)`); edits are held in local state until then, so leaving discards.
struct ExerciseRunView: View {
    let exercise: Exercise
    /// Routine-session chrome (progress, Skip, auto-advance) when a block in a routine; `nil` standalone.
    var routineContext: RoutineRunContext?
    @State private var engine = StandaloneMetronomeEngine()
    @Environment(\.modelContext) private var modelContext
    /// The global note-caption preference (set from the exercise editors) — read so the live board
    /// captions notes the same way the creation preview did.
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }

    // Local edit state — seeded from the exercise on appear, committed only on Start.
    @State private var working = 0
    @State private var command = 0
    @State private var steps = 0
    @State private var reachSteps = 0
    @State private var backoffSteps = 0
    @State private var showSteps = false
    /// The top-level "Practice Settings" disclosure — collapsed by default (V1 feedback).
    @State private var showSettings = false
    @State private var signature: TimeSignature = .standard
    @State private var seeded = false
    /// Whether the routine count-in overlay is showing (routine mode only) — gates the run start.
    @State private var showCountIn = false
    /// The practice journal sheet — authoring lives here now (ADR 0058), reachable from the nav bar.
    @State private var showingJournal = false
    /// The exercise detail/reference sheet (V1 feedback #2) — an ⓘ in the nav bar opens it.
    @State private var showingDetail = false
    /// The setup as it was last persisted — captured on seed and after each Save, so the Save
    /// Changes button shows only while the current edits differ from what's stored (ADR 0057).
    @State private var baseline: ExerciseSetupState?

    /// The persistable setup as it stands now — what Start / Save would write.
    private var current: ExerciseSetupState {
        ExerciseSetupState(working: working, command: command, steps: steps,
                           reachSteps: reachSteps, backoffSteps: backoffSteps, signature: signature)
    }

    /// True when the setup has unsaved edits — drives the Save Changes button.
    private var isDirty: Bool { baseline.map { $0 != current } ?? false }

    /// The reach derived from the (local) command — proportional + clamped (ADR 0045).
    private var reach: Int { TempoStretch.targetBPM(forCommand: command) }

    /// The warm-up step size the chosen number of intermediate stops implies.
    private var stepBPM: Int {
        CommandRamp.warmupStepBPM(working: working, command: command, intermediateSteps: steps)
    }

    /// The routine the current edits describe — the staircase preview and the exact
    /// `CommandRamp` handed to `engine.run(ramp:)` on Start.
    private var routine: CommandRamp {
        CommandRamp(working: working, command: command, target: reach,
                    stepBPM: stepBPM, intervalCount: StandaloneMetronomeEngine.automatorDefaultBars,
                    unit: .bars, dwellIntervals: StandaloneMetronomeEngine.automatorDefaultDwell,
                    includeBackoff: true, reachSteps: reachSteps, backoffSteps: backoffSteps)
    }

    /// Whether there's a climb above command to put intermediate reach stops on.
    private var hasReach: Bool { reach > command }

    private var isRunning: Bool { engine.transport != .stopped }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if isRunning {
                    liveReadout
                } else {
                    if let pattern = exercise.strumPattern { StrumPatternPreview(pattern: pattern) }
                    if let drill = exercise.fretboardDrill { FretboardExercisePreview(drill: drill) }
                    if let progression = exercise.chordProgression {
                        ChordProgressionPreview(progression: progression)
                    }
                    if let sheet = exercise.strumChordSheet { StrumChordsPreview(sheet: sheet) }
                    practiceSettings
                }
                RoutineStairs(plateaus: routine.plateaus, tint: PocketColor.practice,
                              currentIndex: isRunning ? engine.currentRampPlateau : nil)
                if !isRunning { promoteButton }
                if !isRunning, isDirty { saveChangesButton }
                if !isRunning, routineContext == nil {
                    JournalPreviewSection(owner: .exercise(exercise)) { showingJournal = true }
                        .padding(.top, 4)
                }
            }
            .padding(24)
            .animation(.easeInOut(duration: 0.2), value: isDirty)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isRunning {
                ToolbarItem(placement: .topBarTrailing) { signaturePicker }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingDetail = true; haptic(.light) } label: {
                    Image(systemName: "info.circle")
                }
                .tint(PocketColor.practice)
                .accessibilityLabel("Exercise details")
            }
        }
        .routineSessionChrome(routineContext)
        .safeAreaInset(edge: .bottom) { transport }
        .overlay { if showCountIn { RoutineCountInOverlay(onComplete: countInFinished) } }
        .keepAwakeDuringPractice()   // Settings V1 (ADR 0050)
        .onAppear { seedIfNeeded(); maybeAutoStart() }
        .onDisappear { engine.stop() }
        .sheet(isPresented: $showingJournal) {
            JournalSheet(owner: .exercise(exercise),
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
        .sheet(isPresented: $showingDetail) {
            ExerciseDetailSheet(exercise: exercise)
        }
    }

    /// Write a new entry, snapshotting the exercise's current command tempo in BPM (ADR 0058).
    private func addJournalEntry(_ text: String, _ kind: EntryKind) {
        if JournalWriter.add(to: .exercise(exercise), text: text, kind: kind, into: modelContext) {
            try? modelContext.save()
            haptic(.light)
        }
    }

    // MARK: - Live readout (running)

    private var liveReadout: some View {
        VStack(spacing: 18) {
            if let countdown = engine.automatorCountdown {
                // Count-in before the climb engages (ADR 0052) — the beat dots keep flashing below.
                VStack(spacing: 2) {
                    Text("\(countdown)")
                        .font(.pocketMono(.largeTitle))
                        .foregroundStyle(PocketColor.practice)
                        .contentTransition(.numericText())
                    Text("Counting in")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            } else {
                VStack(spacing: 2) {
                    Text("\(engine.bpm)")
                        .font(.pocketMono(.largeTitle))
                        .foregroundStyle(PocketColor.textPrimary)
                        .contentTransition(.numericText())
                    Text("BPM · \(engine.tempoMarking.name)")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            ExerciseTemplateSurface(engine: engine, exercise: exercise, labelMode: labelMode)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Setup (stopped)

    /// Edit the exercise's **meter** from the run setup (ADR 0052) — a compact nav-bar menu shown only
    /// while stopped. Drives the click's accents + count-in; committed on Start, so leaving discards it.
    private var signaturePicker: some View {
        Menu {
            Picker("Time signature", selection: $signature) {
                ForEach(TimeSignature.presets) { preset in
                    Text("\(preset.name) · \(preset.context)").tag(preset)
                }
            }
        } label: {
            Text(signature.name)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
        }
        .accessibilityLabel("Time signature: \(signature.name)")
    }

    /// The collapsible **Practice Settings** panel (V1 feedback): the three tempos + the nested
    /// Steps granularity behind one disclosure header, so the setup reads as just the title,
    /// a summary, and the staircase by default. The tempo edits still live in this view's state.
    private var practiceSettings: some View {
        PracticeSettingsPanel(
            expanded: $showSettings,
            working: working, command: command, reach: reach,
            onStepWorking: { adjustWorking(by: $0) }, onTypeWorking: { setWorking($0) },
            onStepCommand: { adjustCommand(by: $0) }, onTypeCommand: { setCommand($0) },
            stepsExpanded: $showSteps, warmupSteps: $steps, reachSteps: $reachSteps,
            backoffSteps: $backoffSteps, warmupStepBPM: stepBPM,
            hasReach: hasReach, tint: PocketColor.practice, onToggle: { haptic(.light) })
    }

    private var promoteButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                command = min(StandaloneMetronomeEngine.bpmRange.upperBound, reach)
            }
            haptic(.medium)
        } label: {
            Label("I own \(reach) now — promote", systemImage: "arrow.up.circle.fill")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().stroke(PocketColor.practice, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Promote: I own \(reach) beats per minute now")
    }

    /// Persist the tuning without starting a run (ADR 0057) — shown only while the setup differs
    /// from what's stored. A subtle filled capsule, distinct from the outlined Promote above it
    /// and the filled Start pill below. Leaving still discards *unsaved* edits.
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
        .accessibilityLabel("Save changes to this exercise")
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Transport

    /// Stopped → **Start training** (commit + `run(ramp:)`). Running → pause / resume with a
    /// secondary stop that ends the run and clears the ramp.
    private var transport: some View {
        HStack(spacing: 14) {
            if isRunning {
                Button { engine.stop(); haptic(.medium) } label: {
                    Image(systemName: "stop.fill")
                        .font(.futura(.title3))
                        .foregroundStyle(PocketColor.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(PocketColor.textSecondary.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and reset")
                Button { engine.toggle(); haptic(.medium) } label: {
                    Label(engine.transport == .playing ? "Pause" : "Resume",
                          systemImage: engine.transport == .playing ? "pause.fill" : "play.fill")
                        .pocketRunButton
                }
                .buttonStyle(.plain)
            } else {
                Button(action: startTapped) {
                    Label("Start training", systemImage: "play.fill").pocketRunButton
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start training routine")
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(PocketColor.background.opacity(0.95))
    }
}

// MARK: - Actions

private extension ExerciseRunView {

    /// Seed the editor once. With a measured command, load the saved tempos as-is; without one
    /// (first open), default command to the exercise's current tempo and working to a sensible
    /// floor below it — so the two start apart, not equal (ADR 0045).
    private func seedIfNeeded() {
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
    private func persist() {
        exercise.workingTempo = working
        exercise.promoteCommand(to: command)          // command + reach (targetTempo)
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
    private func saveChanges() {
        persist()
        haptic(.medium)
    }

    /// Start tapped: in a routine, run the count-in first (ADR 0071); standalone, start immediately.
    private func startTapped() {
        if routineContext != nil { showCountIn = true; haptic(.light) } else { commitAndStart() }
    }

    /// Auto-start on arrival when the context asks (Settings-gated; never the first block).
    private func maybeAutoStart() {
        if routineContext?.autoStart == true, !isRunning { showCountIn = true }
    }

    /// The count-in reached zero — drop the overlay and begin the run.
    private func countInFinished() {
        showCountIn = false
        commitAndStart()
    }

    /// Persist the edits and hand the routine to this screen's own engine in one tap.
    private func commitAndStart() {
        persist()
        // Feed the exercise's meter to the run engine so the click's accents and the count-in
        // length honor it (ADR 0052), then hand over the routine.
        engine.setTimeSignature(signature)
        engine.run(ramp: routine)
        haptic(.medium)
    }

    // Steps are pure (`StepperButton` owns the ±/hold-repeat haptics); the typed setters keep their
    // own single haptic. Both clamp through the shared helpers below.
    private func adjustWorking(by delta: Int) { working = clampWorking(working + delta) }
    private func adjustCommand(by delta: Int) { command = clampCommand(command + delta) }
    private func setWorking(_ value: Int) { working = clampWorking(value); haptic(.light) }
    private func setCommand(_ value: Int) { command = clampCommand(value); haptic(.light) }

    /// Working stays in range and never above command (the floor sits below the owned tempo).
    private func clampWorking(_ value: Int) -> Int {
        min(command, max(StandaloneMetronomeEngine.bpmRange.lowerBound, value))
    }

    /// Command stays in range and never below working; the reach re-derives automatically.
    private func clampCommand(_ value: Int) -> Int {
        min(StandaloneMetronomeEngine.bpmRange.upperBound, max(working, value))
    }
}

/// Snapshot of the run-setup fields Start / Save persist — compared against the live values to
/// decide whether the Save Changes button shows (ADR 0057). Pure UI state, not a domain type.
private struct ExerciseSetupState: Equatable {
    var working: Int
    var command: Int
    var steps: Int
    var reachSteps: Int
    var backoffSteps: Int
    var signature: TimeSignature
}

#Preview("Exercise run") {
    NavigationStack {
        ExerciseRunView(exercise: Exercise(name: "Alternating picking",
                                           currentTempo: 70, commandTempo: 96))
    }
    .preferredColorScheme(.dark)
}
