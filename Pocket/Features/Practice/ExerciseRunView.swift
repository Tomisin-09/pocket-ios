import SwiftData
import SwiftUI

/// A **training run** on one exercise (ADR 0046, Phase A): the screen you reach by tapping a
/// unit in Practice. Unlike the old in-metronome Training Mode sheet, this **owns its own
/// `StandaloneMetronomeEngine`** — Practice runs are independent of the metronome's free-play
/// engine, so starting a drill here never disturbs (or is disturbed by) the metronome screen.
///
/// Two modes on one screen:
/// - **Set up** (stopped): edit the three tempos — warm-up **working** floor, owned
///   **command**, derived **reach** — and how many warm-up steps to climb through, with the
///   routine drawn as a staircase. A one-tap **promote** ratchets command up to the reach.
/// - **Running**: the live BPM (climbing as the ramp steps), the beat indicator, and the
///   session timer, with pause / resume / stop.
///
/// **Start** commits the edits to the model and hands the engine a `CommandRamp` directly
/// (`engine.run(ramp:)`, ADR 0046) — no separate "arm the automator" step. Edits are held in
/// local state until Start, so the three tempos move independently while editing and leaving
/// the screen without starting discards them.
struct ExerciseRunView: View {
    let exercise: Exercise
    @State private var engine = StandaloneMetronomeEngine()
    @Environment(\.modelContext) private var modelContext

    // Local edit state — seeded from the exercise on appear, committed only on Start.
    @State private var working = 0
    @State private var command = 0
    @State private var steps = 0
    @State private var reachSteps = 0
    @State private var backoffSteps = 0
    @State private var showSteps = false
    @State private var seeded = false

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
                    tempos
                    stepsSection
                }
                RoutineStairs(plateaus: routine.plateaus, tint: PocketColor.practice,
                              currentIndex: isRunning ? engine.currentRampPlateau : nil)
                if !isRunning { promoteButton }
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { transport }
        .keepAwakeDuringPractice()   // Settings V1 (ADR 0050)
        .onAppear(perform: seedIfNeeded)
        .onDisappear { engine.stop() }
    }

    // MARK: - Live readout (running)

    private var liveReadout: some View {
        VStack(spacing: 18) {
            VStack(spacing: 2) {
                Text("\(engine.bpm)")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
                Text("BPM · \(engine.tempoMarking.name)")
                    .font(.caption)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            BeatIndicator(engine: engine)
            SessionTracker(engine: engine)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Setup (stopped)

    private var tempos: some View {
        VStack(spacing: 14) {
            EditableTempoRow(label: "Working", caption: "warm-up floor", value: working,
                             tint: PocketColor.practice,
                             onStep: { adjustWorking(by: $0) }, onType: { setWorking($0) })
            EditableTempoRow(label: "Command", caption: "fastest you own", value: command,
                             tint: PocketColor.practice,
                             onStep: { adjustCommand(by: $0) }, onType: { setCommand($0) })
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reach").font(.subheadline).foregroundStyle(PocketColor.textPrimary)
                    Text("auto · +\(reach - command) BPM")
                        .font(.caption2).foregroundStyle(PocketColor.textSecondary)
                }
                Spacer()
                Text("\(reach) BPM")
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.practice)
                    .contentTransition(.numericText())
            }
        }
    }

    /// The step controls, tucked behind a disclosure header so the run setup reads as just the
    /// tempos + staircase by default; expand to shape the warm-up / reach / back-up granularity.
    private var stepsSection: some View {
        RoutineStepsControls(expanded: $showSteps, warmupSteps: $steps, reachSteps: $reachSteps,
                             backoffSteps: $backoffSteps, warmupStepBPM: stepBPM, reach: reach,
                             hasReach: hasReach, tint: PocketColor.practice) { haptic(.light) }
    }

    private var promoteButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                command = min(StandaloneMetronomeEngine.bpmRange.upperBound, reach)
            }
            haptic(.medium)
        } label: {
            Label("I own \(reach) now — promote", systemImage: "arrow.up.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PocketColor.practice)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().stroke(PocketColor.practice, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Promote: I own \(reach) beats per minute now")
    }

    // MARK: - Transport

    /// Stopped → **Start training** (commit + `run(ramp:)`). Running → pause / resume with a
    /// secondary stop that ends the run and clears the ramp.
    private var transport: some View {
        HStack(spacing: 14) {
            if isRunning {
                Button { engine.stop(); haptic(.medium) } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
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
                Button(action: commitAndStart) {
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

    // MARK: - Actions

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
        seeded = true
    }

    /// Persist the edits and hand the routine to this screen's own engine in one tap — the only
    /// place the run screen writes to the model (leaving without starting discards).
    private func commitAndStart() {
        exercise.workingTempo = working
        exercise.promoteCommand(to: command)          // command + reach (targetTempo)
        exercise.rampStepBPM = stepBPM
        exercise.rampIntervalUnit = .bars
        exercise.rampIntervalCount = StandaloneMetronomeEngine.automatorDefaultBars
        exercise.dwellIntervals = StandaloneMetronomeEngine.automatorDefaultDwell
        exercise.includeBackoff = true
        exercise.rampReachSteps = reachSteps
        exercise.rampBackoffSteps = backoffSteps
        try? modelContext.save()

        engine.run(ramp: routine)
        haptic(.medium)
    }

    /// Working stays in range and never above command (the floor sits below the owned tempo).
    private func adjustWorking(by delta: Int) { setWorking(working + delta) }

    /// Command stays in range and never below working; the reach re-derives automatically.
    private func adjustCommand(by delta: Int) { setCommand(command + delta) }

    /// Set working to an absolute (typed) value, clamped to range and never above command.
    private func setWorking(_ value: Int) {
        let range = StandaloneMetronomeEngine.bpmRange
        working = min(command, max(range.lowerBound, value))
        haptic(.light)
    }

    /// Set command to an absolute (typed) value, clamped to range and never below working.
    private func setCommand(_ value: Int) {
        let range = StandaloneMetronomeEngine.bpmRange
        command = min(range.upperBound, max(working, value))
        haptic(.light)
    }
}

private extension View {
    /// The shared big-pill look for the run screen's primary transport buttons.
    var pocketRunButton: some View {
        self
            .font(.headline)
            .foregroundStyle(PocketColor.background)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.practice))
    }
}

#Preview("Exercise run") {
    NavigationStack {
        ExerciseRunView(exercise: Exercise(name: "Alternating picking",
                                           currentTempo: 70, commandTempo: 96))
    }
    .preferredColorScheme(.dark)
}
