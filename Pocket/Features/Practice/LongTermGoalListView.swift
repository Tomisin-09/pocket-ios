import SwiftData
import SwiftUI

/// **Long-term goals** (ADR 0171) — the ranked list of standing outcomes the player is working
/// toward, pushed from the Practice hub. This is the tier's **only** editable surface: adding,
/// reordering, editing and deleting all happen here. Progress carries a read-only echo of the same
/// list (ADR 0171 D6), and it carries no controls, because ADR 0117 keeps Progress read-back-only.
///
/// **Rank is the whole interaction.** Position sets the projected `weight` *and* the planner's
/// round-robin visit order (ADR 0171 D3), so dragging a goal up is a thing the player can observe in
/// the next generated session rather than a label. That is why the reorder affordance is a visible
/// toolbar control and not a hidden hold — ADR 0163 lodged a standing objection to spending another
/// undiscoverable gesture, and this list had a free toolbar slot.
///
/// **There is no date anywhere on this screen, and there must never be one** (ADR 0171 D1): no
/// deadline column, no "added 3 weeks ago", no countdown. Nothing here may give the player something
/// to be late against.
struct LongTermGoalListView: View {
    @Environment(\.modelContext) private var context
    @Query private var goals: [LongTermGoal]
    @Query private var songs: [Song]

    /// Present by stable identity, never by `PersistentIdentifier` (ADR 0090) — a `.sheet(item:)`
    /// bound to a `@Model` self-dismisses the moment the model is touched.
    @State private var editingGoal: StableRef<LongTermGoal>?
    @State private var addingGoal = false
    @State private var isReordering = false

    /// The ranked, unmet goals — what shapes a session.
    private var activeGoals: [LongTermGoal] {
        LongTermGoalStore.inRankOrder(goals).filter { !$0.isMet }
    }

    private var metGoals: [LongTermGoal] {
        LongTermGoalStore.inRankOrder(goals).filter(\.isMet)
    }

    /// The cap is enforced at the add button rather than by refusing a save (ADR 0171 D4) — the app
    /// never refuses (ADR 0073); it declines to offer.
    private var canAddGoal: Bool { goals.count < LongTermRank.maxGoals }

    var body: some View {
        List {
            rankedSection
            if !metGoals.isEmpty { metSection }
        }
        .scrollContentBackground(.hidden)
        .readableWidth()
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Long-term goals")
        .navigationBarTitleDisplayMode(.inline)
        // The repo's edit-mode idiom (`RoutineDetailView`): a host-owned flag rather than
        // `EditButton`, whose label changes width and would shift an inline title (ADR 0126).
        .environment(\.editMode, .constant(isReordering ? .active : .inactive))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isReordering.toggle()
                    haptic(.light)
                } label: {
                    Image(systemName: isReordering
                          ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                }
                .tint(PocketColor.practice)
                .disabled(activeGoals.count < 2)
                .accessibilityLabel(isReordering ? "Done reordering" : "Reorder goals")
            }
        }
        .sheet(isPresented: $addingGoal) {
            LongTermGoalEditorView(existing: nil, songs: songs, newGoalOrder: goals.count)
        }
        .sheet(item: $editingGoal) { ref in
            LongTermGoalEditorView(existing: ref.value, songs: songs)
        }
    }

    // MARK: - Ranked

    private var rankedSection: some View {
        Section {
            if activeGoals.isEmpty {
                Text("Nothing here yet. A long-term goal is something you're working toward with no "
                     + "deadline attached — the higher it sits, the harder it pulls when you build "
                     + "a session.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(Array(activeGoals.enumerated()), id: \.element.uid) { pair in
                    goalRow(pair.element, rank: pair.offset + 1)
                        .listRowBackground(PocketColor.background)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            }
            if canAddGoal {
                Button { addingGoal = true; haptic(.light) } label: {
                    Label("Add a long-term goal", systemImage: "plus.circle.fill")
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.practice)
                }
                .listRowBackground(PocketColor.background)
            }
        } header: {
            Text("Ranked")
        } footer: {
            Text(canAddGoal
                 ? "Order them however you like. The top of the list pulls hardest when a session "
                   + "is built."
                 : "That's \(LongTermRank.maxGoals) — the most a ranking stays meaningful at. "
                   + "Mark one met or delete one to add another.")
                .font(.futura(.caption))
        }
    }

    private func goalRow(_ goal: LongTermGoal, rank: Int) -> some View {
        Button { editingGoal = StableRef(value: goal); haptic(.light) } label: {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.futura(.callout, weight: .bold))
                    .foregroundStyle(PocketColor.practice)
                    .frame(width: 20, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(subtitle(for: goal))
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.title), rank \(rank)")
    }

    /// Skills, and the target song when there is one. A **count**, never a numerator — a skill count
    /// over a total would state a target, and a target is habit-pressure under another name
    /// (`PracticeLog`).
    private func subtitle(for goal: LongTermGoal) -> String {
        let skills = goal.skillIDs.count == 1 ? "1 skill" : "\(goal.skillIDs.count) skills"
        guard let song = goal.targetSong else { return skills }
        return "\(skills) · \(song.title.isEmpty ? "a song" : song.title)"
    }

    // MARK: - Met

    private var metSection: some View {
        Section {
            ForEach(metGoals, id: \.uid) { goal in
                Button { editingGoal = StableRef(value: goal); haptic(.light) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PocketColor.practice)
                        Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textSecondary)
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(PocketColor.background)
            }
        } header: {
            Text("Met")
        } footer: {
            Text("Kept here, and no longer shaping new sessions.")
                .font(.futura(.caption))
        }
    }

    // MARK: - Mutation

    /// Reorder and renumber contiguously — `order` must stay gap-free or `LongTermRank` starts
    /// skipping steps and two adjacent goals stop pulling differently.
    private func move(from offsets: IndexSet, to destination: Int) {
        LongTermGoalStore.move(from: offsets, to: destination, in: activeGoals)
        try? context.save()
        haptic(.light)
    }

    /// Delete, then close the gaps left behind — for the same reason `move` renumbers.
    private func delete(at offsets: IndexSet) {
        let ordered = activeGoals
        for index in offsets where ordered.indices.contains(index) { context.delete(ordered[index]) }
        let survivors = ordered.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        LongTermGoalStore.renumber(survivors)
        try? context.save()
        haptic(.medium)
    }
}

#Preview("Long-term goals") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: LongTermGoal.self, Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    container.mainContext.insert(LongTermGoal(title: "Play Wish You Were Here",
                                              skillIDs: ["rep.learn-song", "rep.master-song"],
                                              order: 0))
    container.mainContext.insert(LongTermGoal(title: "Build speed",
                                              skillIDs: ["pick.alternate", "fret.legato"], order: 1))
    return NavigationStack { LongTermGoalListView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
