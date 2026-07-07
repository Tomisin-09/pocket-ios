import SwiftData
import SwiftUI

/// The **routine player** (ADR 0066, slice 3): a full-screen transport that runs a routine's blocks
/// end-to-end, **auto-advancing** between them on each block's natural completion (a ramp's last
/// plateau, or a rest's countdown). The session logic lives in `RoutineSessionPlayer`; this is its
/// face — a progress header, the current block's live surface, and a minimal transport
/// (Pause/Resume · Skip · End).
///
/// Deliberately **judgement-free (ADR 0070)**: it shows what's playing and how far along the
/// session is, and nothing about *how well* — no score, no accuracy, no pass/fail. The player is the
/// judge.
struct RoutinePlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var player: RoutineSessionPlayer

    /// The global note-caption preference (set from the exercise editors) — read so a drill's live
    /// board captions notes the same way its own run screen does.
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }

    init(routine: Routine) {
        _player = State(initialValue: RoutineSessionPlayer(routine: routine))
    }

    var body: some View {
        ZStack {
            PocketColor.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
                if !player.isFinished { transport }
            }
            .padding(24)
        }
        .keepAwakeDuringPractice()
        .onAppear(perform: player.start)
        .onDisappear(perform: player.end)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.routineName)
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.textPrimary)
                if !player.progressLabel.isEmpty, !player.isFinished {
                    Text(player.progressLabel)
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.futura(.title3))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .accessibilityLabel("Close player")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if player.isFinished {
            finishedView
        } else if let stage = player.current {
            stageView(stage)
        }
    }

    @ViewBuilder
    private func stageView(_ stage: RoutineStage) -> some View {
        VStack(spacing: 20) {
            blockLabel(stage.title, kind: stage.kind)
            switch stage.payload {
            case .exercise(let exercise): exerciseSurface(exercise)
            case .loop: loopSurface
            case .rest: restSurface
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The block's name + a small type caption above whatever surface is running.
    private func blockLabel(_ title: String, kind: RoutineStageKind) -> some View {
        VStack(spacing: 4) {
            Text(caption(for: kind))
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
                .textCase(.uppercase)
            Text(title)
                .font(.futura(.title2))
                .foregroundStyle(PocketColor.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    private func caption(for kind: RoutineStageKind) -> String {
        switch kind {
        case .exercise: return "Exercise"
        case .loop: return "Loop"
        case .song: return "Song"
        case .rest: return "Rest"
        }
    }

    // MARK: - Exercise surface

    private func exerciseSurface(_ exercise: Exercise) -> some View {
        VStack(spacing: 16) {
            if let countdown = player.metronome.automatorCountdown {
                bpmReadout(text: "\(countdown)", caption: "Counting in", tint: PocketColor.practice)
            } else {
                bpmReadout(text: "\(player.metronome.bpm)",
                           caption: "BPM · \(player.metronome.tempoMarking.name)",
                           tint: PocketColor.textPrimary)
            }
            ExerciseTemplateSurface(engine: player.metronome, exercise: exercise, labelMode: labelMode)
        }
    }

    private func bpmReadout(text: String, caption: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.pocketMono(.largeTitle))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(caption)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    // MARK: - Loop surface

    @ViewBuilder
    private var loopSurface: some View {
        if let model = player.loopModel {
            VStack(spacing: 8) {
                if model.isLoading {
                    ProgressView().tint(PocketColor.practice)
                } else {
                    Text("\(model.currentPercent)%")
                        .font(.pocketMono(.largeTitle))
                        .foregroundStyle(PocketColor.textPrimary)
                        .contentTransition(.numericText())
                    Text("loop \(model.elapsedReps + 1)")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        }
    }

    // MARK: - Rest surface

    private var restSurface: some View {
        VStack(spacing: 6) {
            Text("\(player.restRemaining)")
                .font(.pocketMono(.largeTitle))
                .foregroundStyle(PocketColor.practice)
                .contentTransition(.numericText())
            Text("Breathe — next block starts automatically")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack(spacing: 12) {
            Image(systemName: player.stages.isEmpty ? "questionmark.circle" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(PocketColor.practice)
            Text(player.stages.isEmpty ? "Nothing to play" : "Session complete")
                .font(.futura(.title3))
                .foregroundStyle(PocketColor.textPrimary)
            Text(player.stages.isEmpty
                 ? "This routine has no playable exercises or loops yet."
                 : "Nice work. Find the music in the mistakes.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
            Button { dismiss() } label: {
                Label("Done", systemImage: "checkmark").pocketRunButton
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Transport

    private var transport: some View {
        HStack(spacing: 14) {
            Button(action: player.end) {
                Image(systemName: "stop.fill")
                    .font(.futura(.title3))
                    .foregroundStyle(PocketColor.textPrimary)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(PocketColor.textSecondary.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End session")

            if player.canPause {
                Button { player.togglePause(); haptic(.medium) } label: {
                    Label(player.state == .paused ? "Resume" : "Pause",
                          systemImage: player.state == .paused ? "play.fill" : "pause.fill")
                        .pocketRunButton
                }
                .buttonStyle(.plain)
            }

            Button { player.advance(); haptic(.light) } label: {
                Label("Skip", systemImage: "forward.fill")
                    .font(.futura(.body, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
                    .frame(maxWidth: player.canPause ? nil : .infinity)
                    .frame(height: 56)
                    .padding(.horizontal, 20)
                    .background(Capsule().stroke(PocketColor.practice, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip to next block")
        }
        .padding(.top, 8)
    }
}

#Preview("Routine player") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Routine.self, RoutineItem.self, Exercise.self, Song.self, Loop.self,
        configurations: .init(isStoredInMemoryOnly: true))
    let drill = Exercise(name: "Alternating picking", currentTempo: 70, commandTempo: 96)
    container.mainContext.insert(drill)
    let routine = Routine(name: "Morning warm-up")
    routine.items = [RoutineItem.item(drill, kind: .warmup, order: 0),
                     RoutineItem.rest(order: 1),
                     RoutineItem.item(drill, order: 2)]
    container.mainContext.insert(routine)
    try? container.mainContext.save()
    return RoutinePlayerView(routine: routine)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
