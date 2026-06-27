import SwiftData
import SwiftUI

/// **Practice** — a top-level destination (ADR 0046), peer to the song library and the
/// metronome, reached from Home. The home for everything you *train*, at two altitudes:
///
/// - **Build today's session** — the guided path (the planner, V2): a placeholder here until
///   Phase C, so the information architecture reads correctly from day one.
/// - **Your units** — the focused path: the list of trainable units, opened one at a time into
///   an `ExerciseRunView`. In Phase A a unit is an **exercise** (click-only, command-anchored);
///   song loops join the same list in Phase B, which is why this is an aggregation surface, not
///   a single model's list.
///
/// Relies on an ambient `NavigationStack` (pushed from Home, like `LibraryView`) rather than
/// owning one, so its toolbar and the run-screen push land in Home's navigation.
struct PracticeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    // Measured song loops (ADR 0046 Phase B): a loop with a command tempo is a trainable unit, so
    // it joins the exercises in "Your units." The `commandTempo != nil` gate keeps the list to
    // loops you've actually measured, not every loop fragment. This is the multi-source unit
    // aggregation the V2 planner will compose sessions from.
    @Query(filter: #Predicate<Loop> { $0.commandTempo != nil }) private var measuredLoops: [Loop]
    @State private var creating = false

    var body: some View {
        List {
            Section {
                plannerCard
            }
            Section("Your units") {
                if exercises.isEmpty && measuredLoops.isEmpty {
                    Text("No units yet. Tap + to create an exercise — a named drill you push "
                         + "faster over time — or measure a song loop's command tempo to train it "
                         + "here.")
                        .font(.footnote)
                        .foregroundStyle(PocketColor.textSecondary)
                        .listRowBackground(PocketColor.background)
                } else {
                    ForEach(exercises) { exercise in
                        NavigationLink {
                            ExerciseRunView(exercise: exercise)
                        } label: {
                            exerciseRow(exercise)
                        }
                        .listRowBackground(PocketColor.background)
                    }
                    .onDelete(perform: delete)
                    // Loops are aggregated in alongside exercises (ADR 0046 Phase B): same "things
                    // you train" list, distinguished by their song context. No swipe-to-delete —
                    // a loop belongs to its song, not Practice, so it's removed from the waveform
                    // screen, not here.
                    ForEach(measuredLoops) { loop in
                        NavigationLink {
                            LoopRunView(loop: loop)
                        } label: {
                            loopRow(loop)
                        }
                        .listRowBackground(PocketColor.background)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true; haptic(.light) } label: {
                    Image(systemName: "plus")
                }
                .tint(PocketColor.practice)
                .accessibilityLabel("New exercise")
            }
        }
        .sheet(isPresented: $creating) {
            NewExerciseSheet(onCreate: create)
        }
    }

    // MARK: - Planner placeholder (V2)

    /// The orchestration entry — disabled until Phase C. Present now so Practice reads as the
    /// two-altitude space the ADR describes (guided "build a session" above focused "your units").
    private var plannerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(PocketColor.practice)
                .frame(width: 44, height: 44)
                .background(Circle().fill(PocketColor.practice.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Build today's session")
                    .font(.headline)
                    .foregroundStyle(PocketColor.textPrimary)
                Text("Guided routine from your units")
                    .font(.subheadline)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 8)
            Text("SOON")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(PocketColor.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(PocketColor.barPlayed))
        }
        .listRowBackground(PocketColor.background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Build today's session, coming soon")
    }

    // MARK: - Unit rows

    /// An exercise unit: name + the command → reach in absolute BPM.
    private func exerciseRow(_ exercise: Exercise) -> some View {
        unitRow(title: exercise.name.isEmpty ? "Untitled" : exercise.name,
                context: nil,
                progress: "Command \(exercise.command) → \(exercise.derivedTarget) BPM")
    }

    /// A loop unit: the loop name with its **song** as context (loops live across songs, so the
    /// song is what distinguishes them in the merged list), + the command → reach in % of original.
    private func loopRow(_ loop: Loop) -> some View {
        unitRow(title: loop.name.isEmpty ? "Untitled loop" : loop.name,
                context: loop.song?.title,
                progress: "Command \(LoopCommandRamp.percent(loop.command))% → "
                    + "\(LoopCommandRamp.percent(loop.derivedTargetSpeed))%")
    }

    /// Shared two/three-line unit row: title, optional context line, and the command → reach line.
    private func unitRow(title: String, context: String?, progress: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body)
                .foregroundStyle(PocketColor.textPrimary)
            if let context, !context.isEmpty {
                Text(context)
                    .font(.caption2)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Text(progress)
                .font(.caption)
                .foregroundStyle(PocketColor.practice)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    /// Create an exercise anchored on the entered **command** tempo (ADR 0046): the warm-up
    /// working floor and the reach derive from it (pure `TempoStretch`), so the number typed in
    /// the sheet is the command shown on the run screen — no working/command mismatch.
    private func create(name: String, command: Int) {
        guard !name.isEmpty else { return }
        context.insert(Exercise.commandAnchored(name: name, command: command))
        haptic(.medium)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(exercises[index]) }
        haptic(.medium)
    }
}

#Preview("Practice — with units") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    container.mainContext.insert(Exercise(name: "Alternating picking",
                                          currentTempo: 70, commandTempo: 96))
    container.mainContext.insert(Exercise(name: "Spider", currentTempo: 60))
    return NavigationStack { PracticeView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

#Preview("Practice — empty") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    return NavigationStack { PracticeView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
