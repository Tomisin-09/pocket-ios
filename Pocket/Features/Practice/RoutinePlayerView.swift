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
    @Environment(\.modelContext) private var modelContext
    @State private var player: RoutineSessionPlayer
    /// The just-finished unit block awaiting an end-of-block reflection (ADR 0071), or `nil`. Set
    /// when a block completes with the reflection setting on; dismissing the sheet advances.
    @State private var reflectingStage: RoutineStage?

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
        .sheet(item: $reflectingStage, onDismiss: player.advance) { stage in
            reflectionSheet(for: stage)
        }
    }

    /// A block finished on its own. With the reflection setting on, pause on a journal sheet for that
    /// unit (a rest has nothing to reflect on); otherwise advance straight away. Skip bypasses this.
    private func finishedBlock() {
        if AppSettings.routineReflection, let stage = player.current, stage.kind != .rest {
            reflectingStage = stage
        } else {
            player.advance()
        }
    }

    @ViewBuilder
    private func reflectionSheet(for stage: RoutineStage) -> some View {
        if let owner = owner(for: stage) {
            JournalSheet(owner: owner,
                         onAdd: { text, kind in
                             _ = JournalWriter.add(to: owner, text: text, kind: kind,
                                                   into: modelContext)
                             try? modelContext.save(); haptic(.light)
                         },
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

    private func owner(for stage: RoutineStage) -> JournalOwner? {
        if let exercise = stage.exercise { return .exercise(exercise) }
        if let loop = stage.loop { return .loop(loop) }
        return nil
    }

    /// The `RoutineRunContext` handed to each run screen — the progress strip's position, whether
    /// this block auto-starts, skip, the natural-completion hook, and exit. Rebuilt each render; all
    /// closures target the stable player, so it's safe for a run screen to wire `onFinished` once.
    private var context: RoutineRunContext {
        RoutineRunContext(stageIndex: player.currentIndex,
                          stageCount: player.stageCount,
                          autoStart: player.shouldAutoStart(at: player.currentIndex),
                          canGoBack: player.canGoBack,
                          onBack: { player.back(); haptic(.light) },
                          onSkip: { player.advance(); haptic(.light) },
                          onFinished: { finishedBlock() },
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
            if let next = player.upNext {
                VStack(spacing: 4) {
                    Text("Up next")
                        .font(.futura(.caption, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .textCase(.uppercase)
                    Text(next.title)
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.practiceCircleWash))
            }
            Spacer()
        }
        .padding(24)
        .navigationTitle("Rest")
        .routineSessionChrome(context)
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack(spacing: 16) {
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
            if !practicedTitles.isEmpty { recap }
            Button { dismiss() } label: {
                Label("Done", systemImage: "checkmark").pocketRunButton
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }

    /// A judgement-free recap — just *what* you worked through this session, no scores (ADR 0070).
    private var recap: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("You practised")
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
                .textCase(.uppercase)
            ForEach(Array(practicedTitles.enumerated()), id: \.offset) { _, title in
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(PocketColor.practice)
                    Text(title)
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.practiceCircleWash))
    }

    /// The unit blocks (exercises/loops) in this routine, in order — the recap list; rests omitted.
    private var practicedTitles: [String] {
        player.stages.filter { $0.kind != .rest }.map(\.title)
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
