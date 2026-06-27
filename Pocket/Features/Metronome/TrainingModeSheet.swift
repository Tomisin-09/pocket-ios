import SwiftData
import SwiftUI

/// **Training Mode** (ADR 0045): the explicit home for an exercise's command-anchored
/// routine. Edits the three tempos — warm-up **working** floor, owned **command**, derived
/// **reach** (target) — plus how many intermediate warm-up steps to climb through, and
/// **Start** configures, *saves* and arms the routine in one action (`engine.startTraining`),
/// so there's no separate "arm the automator" step that left the tempos and the ramp
/// disconnected. A one-tap **promote** ratchets command up to the reach.
///
/// Edits are held in **local state**, not written to the model until **Start** — so the
/// three tempos move independently while editing (lowering working never drags command with
/// it the way the `command`-falls-back-to-`working` model otherwise would), and **Close**
/// discards rather than saves. First open with no measured command seeds command from the
/// exercise's current tempo and working from a sensible floor below it.
///
/// The routine shape is fixed (warm-up → dwell at command → summit at reach → backoff below
/// command), shown as a staircase so what Start will do is visible.
struct TrainingModeSheet: View {
    let exercise: Exercise
    let engine: StandaloneMetronomeEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Local edit state — seeded from the exercise on appear, committed only on Start so the
    // tempos stay decoupled while editing and Close discards.
    @State private var working = 0
    @State private var command = 0
    @State private var steps = 0
    @State private var seeded = false

    /// The reach derived from the (local) command — proportional + clamped (ADR 0045).
    var reach: Int { TempoStretch.targetBPM(forCommand: command) }

    /// The warm-up step size the chosen number of intermediate stops implies.
    var stepBPM: Int {
        CommandRamp.warmupStepBPM(working: working, command: command, intermediateSteps: steps)
    }

    /// The routine the current edits describe — for the staircase preview and to mirror what
    /// `engine.startTraining` will arm (same step / interval / dwell / backoff).
    private var routine: CommandRamp {
        CommandRamp(working: working, command: command, target: reach,
                    stepBPM: stepBPM, intervalCount: StandaloneMetronomeEngine.automatorDefaultBars,
                    unit: .bars, dwellIntervals: StandaloneMetronomeEngine.automatorDefaultDwell,
                    includeBackoff: true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    tempos
                    stepsRow
                    RoutineStairs(plateaus: routine.plateaus, tint: PocketColor.metronome)
                    promoteButton
                }
                .padding(24)
            }
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Training Mode")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { startBar }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.tint(PocketColor.metronome)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: seedIfNeeded)
    }

    /// Seed the editor once. With a measured command, load the saved tempos as-is; without
    /// one (first open), default command to the exercise's current tempo and working to a
    /// sensible floor below it — so the two start apart, not equal (ADR 0045).
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
                                              stepBPM: exercise.automatorStepBPM)
        seeded = true
    }

    /// Persist the edits to the exercise and arm + start the routine in one tap. This is the
    /// only place Training Mode writes to the model — Close discards.
    private func commitAndStart() {
        exercise.workingTempo = working
        exercise.promoteCommand(to: command)          // command + reach (targetTempo)
        exercise.automatorStepBPM = stepBPM
        exercise.automatorIntervalUnit = .bars
        exercise.automatorIntervalCount = StandaloneMetronomeEngine.automatorDefaultBars
        exercise.automatorCeiling = reach
        exercise.automatorEnabled = true
        try? modelContext.save()

        if engine.transport != .stopped { engine.stop() }
        engine.startTraining(working: working, command: command, target: reach, stepBPM: stepBPM)
        engine.start()
        haptic(.medium)
        dismiss()
    }
}

// MARK: - Subviews & adjusters

private extension TrainingModeSheet {

    var tempos: some View {
        VStack(spacing: 14) {
            tempoRow(label: "Working", caption: "warm-up floor", value: working) {
                adjustWorking(by: $0)
            }
            tempoRow(label: "Command", caption: "fastest you own", value: command) {
                adjustCommand(by: $0)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reach").font(.subheadline).foregroundStyle(PocketColor.textPrimary)
                    Text("auto · +\(reach - command) BPM")
                        .font(.caption2).foregroundStyle(PocketColor.textSecondary)
                }
                Spacer()
                Text("\(reach) BPM")
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.metronome)
                    .contentTransition(.numericText())
            }
        }
    }

    /// How many intermediate stops the warm-up climbs through between working and command.
    var stepsRow: some View {
        tempoRow(label: "Warm-up steps", caption: stepsCaption, value: steps) {
            adjustSteps(by: $0)
        }
    }

    var stepsCaption: String {
        steps == 0 ? "straight to command" : "+\(stepBPM) BPM per step"
    }

    /// The big primary action: save, configure + arm the routine, and begin playing.
    var startBar: some View {
        Button(action: commitAndStart) {
            Label("Start training", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(PocketColor.background)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.metronome))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .accessibilityLabel("Start training routine")
    }

    var promoteButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                command = min(StandaloneMetronomeEngine.bpmRange.upperBound, reach)
            }
            haptic(.medium)
        } label: {
            Label("I own \(reach) now — promote", systemImage: "arrow.up.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PocketColor.metronome)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().stroke(PocketColor.metronome, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Promote: I own \(reach) beats per minute now")
    }

    func tempoRow(label: String, caption: String, value: Int,
                  adjust: @escaping (Int) -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline).foregroundStyle(PocketColor.textPrimary)
                Text(caption).font(.caption2).foregroundStyle(PocketColor.textSecondary)
            }
            Spacer()
            stepButton(symbol: "minus", label: "Lower \(label)") { adjust(-1) }
            Text("\(value)")
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(minWidth: 52)
                .contentTransition(.numericText())
            stepButton(symbol: "plus", label: "Raise \(label)") { adjust(1) }
        }
    }

    /// Working stays in range and never above command (the floor sits below the owned tempo).
    func adjustWorking(by delta: Int) {
        let range = StandaloneMetronomeEngine.bpmRange
        working = min(command, max(range.lowerBound, working + delta))
        haptic(.light)
    }

    /// Command stays in range and never below working; the reach re-derives automatically.
    func adjustCommand(by delta: Int) {
        let range = StandaloneMetronomeEngine.bpmRange
        command = min(range.upperBound, max(working, command + delta))
        haptic(.light)
    }

    /// Intermediate warm-up stops, 0…6 (0 ⇒ jump straight to command).
    func adjustSteps(by delta: Int) {
        steps = max(0, min(6, steps + delta))
        haptic(.light)
    }

    func stepButton(symbol: String, label: String,
                    action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(PocketColor.metronome.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The routine as a staircase: one bar per plateau, height ∝ BPM (normalised across the
/// routine's span) and **width ∝ how long it holds**, so the command dwell reads as the wide
/// bar and the backoff tail as the dip after the summit. A faithful picture of what Start
/// will play (ADR 0045).
private struct RoutineStairs: View {
    let plateaus: [CommandRamp.Plateau]
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let low = plateaus.map(\.bpm).min() ?? 0
                let high = plateaus.map(\.bpm).max() ?? 1
                let span = max(1, high - low)
                let totalIntervals = max(1, plateaus.reduce(0) { $0 + $1.intervals })
                let spacing: CGFloat = 4
                let usableWidth = geo.size.width - spacing * CGFloat(plateaus.count - 1)
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(plateaus.enumerated()), id: \.offset) { _, plateau in
                        let heightFraction = 0.3 + 0.7 * Double(plateau.bpm - low) / Double(span)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(tint.opacity(plateau.intervals > 1 ? 0.9 : 0.55))
                            .frame(width: usableWidth * CGFloat(plateau.intervals)
                                   / CGFloat(totalIntervals),
                                   height: geo.size.height * heightFraction)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 96)
            HStack {
                Text("warm-up").font(.caption2).foregroundStyle(PocketColor.textSecondary)
                Spacer()
                Text("dwell at command").font(.caption2.weight(.semibold)).foregroundStyle(tint)
                Spacer()
                Text("reach · back off").font(.caption2).foregroundStyle(PocketColor.textSecondary)
            }
        }
    }
}

#Preview("Training Mode") {
    TrainingModeSheet(exercise: Exercise(name: "Alternating picking",
                                                  currentTempo: 70, commandTempo: 96),
                      engine: StandaloneMetronomeEngine())
}
