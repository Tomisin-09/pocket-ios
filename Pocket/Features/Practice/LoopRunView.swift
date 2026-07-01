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
    @State private var model: LoopRunModel
    @Environment(\.modelContext) private var modelContext

    // Local edit state (percent of original), seeded on appear, committed only on Start.
    @State private var working = 0
    @State private var command = 0
    @State private var steps = 0
    @State private var reachSteps = 0
    @State private var backoffSteps = 0
    @State private var repsPerStep = LoopCommandRamp.defaultRepsPerStep
    @State private var showSteps = false
    @State private var seeded = false

    private static let repsRange = 1...8

    /// Playback-speed bounds as integer percent (the engine clamps 0.25×–2.0×).
    private static let percentRange =
        Int(TempoMath.minSpeed * 100)...Int(TempoMath.maxSpeed * 100)

    init(loop: Loop) {
        self.loop = loop
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
                    tempos
                    repsRow
                    stepsSection
                }
                RoutineStairs(plateaus: routine.plateaus, tint: PocketColor.practice,
                              currentIndex: model.currentPlateau(in: routine))
                if !isRunning { promoteButton }
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { transport }
        .keepAwakeDuringPractice()   // Settings V1 (ADR 0050)
        .onAppear(perform: seedIfNeeded)
        .task { await model.loadIfNeeded() }
        .onDisappear { model.stop() }
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
                    .font(.caption)
                    .foregroundStyle(PocketColor.textSecondary)
                Text("loop \(model.elapsedReps + 1)")
                    .font(.caption2)
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

    private var tempos: some View {
        VStack(spacing: 14) {
            EditableTempoRow(label: "Working", caption: "warm-up floor (% of original)",
                             value: working, tint: PocketColor.practice,
                             onStep: { adjustWorking(by: $0) }, onType: { setWorking($0) })
            EditableTempoRow(label: "Command", caption: "fastest you own (% of original)",
                             value: command, tint: PocketColor.practice,
                             onStep: { adjustCommand(by: $0) }, onType: { setCommand($0) })
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reach").font(.subheadline).foregroundStyle(PocketColor.textPrimary)
                    Text("auto · +\(reach - command)%")
                        .font(.caption2).foregroundStyle(PocketColor.textSecondary)
                }
                Spacer()
                Text("\(reach)%")
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.practice)
                    .contentTransition(.numericText())
            }
        }
    }

    /// How many loop passes each step holds before the tempo bumps (ADR 0046 Phase B). `1` ⇒ each
    /// step is one pass through the loop; the command dwell holds this many passes per its intervals.
    private var repsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reps per step").font(.subheadline).foregroundStyle(PocketColor.textPrimary)
                Text(repsPerStep == 1 ? "one loop, then step up" : "\(repsPerStep) loops, then step up")
                    .font(.caption2).foregroundStyle(PocketColor.textSecondary)
            }
            Spacer()
            stepButton(symbol: "minus", label: "Fewer reps per step") {
                repsPerStep = max(Self.repsRange.lowerBound, repsPerStep - 1); haptic(.light)
            }
            Text("\(repsPerStep)")
                .font(.pocketMono(.title3)).foregroundStyle(PocketColor.textPrimary)
                .frame(width: 44).contentTransition(.numericText())
            stepButton(symbol: "plus", label: "More reps per step") {
                repsPerStep = min(Self.repsRange.upperBound, repsPerStep + 1); haptic(.light)
            }
        }
    }

    private func stepButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(PocketColor.practice.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var stepsSection: some View {
        RoutineStepsControls(expanded: $showSteps, warmupSteps: $steps, reachSteps: $reachSteps,
                             backoffSteps: $backoffSteps, warmupStepBPM: stepPercent, reach: reach,
                             hasReach: hasReach, tint: PocketColor.practice, stepUnit: "%") {
            haptic(.light)
        }
    }

    private var promoteButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                command = min(Self.percentRange.upperBound, reach)
            }
            haptic(.medium)
        } label: {
            Label("I own \(reach)% now — promote", systemImage: "arrow.up.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PocketColor.practice)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().stroke(PocketColor.practice, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Promote: I own \(reach) percent now")
    }

    // MARK: - Transport

    private var transport: some View {
        HStack(spacing: 14) {
            if isRunning {
                Button { model.stop(); haptic(.medium) } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
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
                Button(action: commitAndStart) {
                    Label("Start training", systemImage: "play.fill").pocketRunButton
                }
                .buttonStyle(.plain)
                .disabled(model.isLoading)
                .accessibilityLabel("Start training routine")
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(PocketColor.background.opacity(0.95))
    }

    // MARK: - Actions

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
        seeded = true
    }

    /// Persist the edits to the loop and start the run in one tap — the only place the run screen
    /// writes to the model (leaving without starting discards).
    private func commitAndStart() {
        loop.speed = Double(working) / 100
        loop.promoteCommand(to: Double(command) / 100)
        try? modelContext.save()
        model.start(ramp: routine)
        haptic(.medium)
    }

    private func adjustWorking(by delta: Int) { setWorking(working + delta) }
    private func adjustCommand(by delta: Int) { setCommand(command + delta) }

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

#Preview("Loop run") {
    let loop = Loop(name: "Chorus solo", start: 0.2, end: 0.4, speed: 0.7, repeats: 0)
    loop.commandTempo = 0.85
    return NavigationStack { LoopRunView(loop: loop) }
        .preferredColorScheme(.dark)
}
