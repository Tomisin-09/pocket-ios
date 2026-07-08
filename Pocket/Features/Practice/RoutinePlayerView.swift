import SwiftData
import SwiftUI

/// The **routine player** (ADR 0066, slice 3 / ADR 0071): a full-screen host that runs a routine's
/// blocks end-to-end. It is deliberately *thin* — each exercise/loop block is the **real**
/// `ExerciseRunView` / `LoopRunView`, injected with a `RoutineRunContext`, so every training aid
/// (fretboard/strum/chord preview, Practice Settings, the ramp staircase, promote, journal) is kept,
/// not re-implemented. The session logic lives in `RoutineSessionPlayer`; this view swaps the run
/// screen per block (`.id(stage.id)` so each starts fresh), runs the between-blocks rest countdown,
/// and shows the finished summary. Blocks **auto-advance** on natural completion; a rest counts down.
///
/// Deliberately **judgement-free (ADR 0070)**: it shows what's playing and how far along the session
/// is, and nothing about *how well*. The player is the judge.
struct RoutinePlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var player: RoutineSessionPlayer

    init(routine: Routine) {
        _player = State(initialValue: RoutineSessionPlayer(routine: routine))
    }

    var body: some View {
        NavigationStack {
            Group {
                if player.isFinished {
                    finishedView
                } else if player.state == .resting {
                    restView
                } else if let stage = player.current {
                    stageView(stage)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(PocketColor.background.ignoresSafeArea())
        }
        .onAppear(perform: player.start)
        .onDisappear(perform: player.end)
    }

    /// The `RoutineRunContext` handed to each run screen — progress, skip, the natural-completion
    /// hook, and exit. Rebuilt each render; all closures target the stable player, so it's safe for a
    /// run screen to wire `onFinished` to its engine once.
    private var context: RoutineRunContext {
        RoutineRunContext(progressLabel: player.progressLabel,
                          onSkip: { player.advance(); haptic(.light) },
                          onFinished: { player.advance() },
                          onExit: { dismiss() })
    }

    // MARK: - Unit block → the real run screen

    @ViewBuilder
    private func stageView(_ stage: RoutineStage) -> some View {
        switch stage.payload {
        case .exercise(let exercise):
            ExerciseRunView(exercise: exercise, routineContext: context).id(stage.id)
        case .loop(let loop):
            LoopRunView(loop: loop, routineContext: context).id(stage.id)
        case .rest:
            EmptyView()   // rests never reach here — the conductor is in `.resting`
        }
    }

    // MARK: - Rest

    private var restView: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 6) {
                Text("\(player.restRemaining)")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.practice)
                    .contentTransition(.numericText())
                Text("Breathe — next block starts automatically")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            RoutineSkipButton(context: context)
                .padding(.bottom, 24)
        }
        .padding(24)
        .navigationTitle("Rest")
        .routineSessionChrome(context)
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
