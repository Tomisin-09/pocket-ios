import SwiftData
import SwiftUI

/// The **long-term goal editor** (ADR 0171): create a standing outcome from a shared `GoalTemplate`,
/// or edit an existing one. Shape mirrors `GoalEditorView` — template picker, then trim the skills,
/// then a target song for a repertoire goal — and the three shared sections come from
/// `GoalAuthoringSections` so the two tiers can't drift.
///
/// **What is absent here is the decision.** There is no priority segment, because this tier is
/// ranked by its position in the list rather than weighted (ADR 0171 D3) — the only way to change
/// how hard a long-term goal pulls is to drag it. And there is **no date field of any kind**
/// (D1): no deadline, no horizon, no "by when". With nothing stored there is nothing for the app to
/// be late against, which is what makes the no-verdict property of ADR 0070 structural rather than
/// a promise kept by copy. Do not add one.
struct LongTermGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// The goal under edit, or `nil` to create a new one (which begins on the template picker).
    let existing: LongTermGoal?
    /// The song library, for the repertoire target picker.
    let songs: [Song]
    /// Where a new goal lands in the ranking — the caller passes the current count, so a new goal
    /// joins the **bottom** of the list rather than displacing something the player ranked.
    var newGoalOrder: Int = 0
    /// The drill and loop libraries, for the line under each skill saying what it would actually
    /// pull into a session (ADR 0216 D4).
    @Query private var exercises: [Exercise]
    @Query private var loops: [Loop]
    /// For a drill made from a skill's fix: the profile's instrument and default command tempo.
    @Query private var profiles: [Profile]
    /// The drill a skill's fix is creating, while that sheet is up.
    @State private var fixExercise: SkillFixExercise?

    @State private var template: GoalTemplate?
    @State private var title = ""
    @State private var offeredSkillIDs: [String] = []
    @State private var keptSkillIDs: Set<String> = []
    @State private var targetSong: Song?
    /// A set's songs by `Song.sourceID` (ADR 0299), and whether this goal is one. A set is known by its
    /// songs once saved (D3); while editing, by the starting point it came from.
    @State private var setSongIDs: Set<String> = []
    @State private var holdsSet = false
    @State private var isMet = false
    @State private var showingSkillPicker = false
    /// Whether the player chose **Something else** — no template, straight to the form. Its own flag
    /// rather than a sentinel template, because `template` is also what supplies the fallback title,
    /// and a blank start deliberately has none.
    @State private var startedBlank = false
    /// The goal a first Save made, so Save after a failed save edits it rather than adding a second
    /// (ADR 0318).
    @State private var created: LongTermGoal?
    @State private var saveFailed = false

    private var needsTargetSong: Bool { !holdsSet && goalNeedsTargetSong(keptSkillIDs) }

    /// Save waits for a skill, and for a set, a song: a set saved with none would not be one (D3).
    private var canSave: Bool { !keptSkillIDs.isEmpty && (!holdsSet || !liveSetSongIDs.isEmpty) }

    /// The chosen songs still in the library, in a stable order for the store.
    private var liveSetSongIDs: [String] {
        songs.map(\.sourceID).filter { setSongIDs.contains($0) }.sorted()
    }

    private var isPickingTemplate: Bool { existing == nil && template == nil && !startedBlank }

    var body: some View {
        NavigationStack {
            Group {
                if isPickingTemplate {
                    GoalTemplatePicker(onPick: choose, onStartBlank: startBlank,
                                       templates: GoalTemplateLibrary.offered(longTerm: true))
                } else {
                    editorForm
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle(existing == nil ? "New long-term goal" : "Edit long-term goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.tint(PocketColor.textSecondary)
                }
                if !isPickingTemplate {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") { save() }
                            .font(.futura(.body, weight: .bold))
                            .tint(PocketColor.practice)
                            .disabled(!canSave)
                    }
                }
            }
        }
        .onAppear(perform: loadExisting)
        .saveFailedAlert(isPresented: $saveFailed, retry: commit)
    }

    // MARK: - Editor form

    private var editorForm: some View {
        List {
            Section {
                TextField("Goal name", text: $title)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    .listRowBackground(PocketColor.background)
            } header: {
                Text("Name")
            } footer: {
                Text("Open-ended by design — there's no deadline here, and nothing counts down.")
                    .font(.futura(.caption))
            }

            GoalSkillsSection(offeredSkillIDs: $offeredSkillIDs, keptSkillIDs: $keptSkillIDs,
                              showingSkillPicker: $showingSkillPicker,
                              reach: goalSkillReach(offeredSkillIDs,
                                                    targetSong: needsTargetSong ? targetSong : nil,
                                                    setSongIDs: holdsSet ? liveSetSongIDs : [],
                                                    exercises: exercises, loops: loops, songs: songs),
                              onFix: applyFix)

            if holdsSet {
                GoalSetSongsSection(songs: songs, songIDs: $setSongIDs)
            } else if needsTargetSong {
                GoalTargetSongSection(songs: songs, targetSong: $targetSong)
            }

            metAndDeleteSection
        }
        .sheet(isPresented: $showingSkillPicker) {
            SkillPickerSheet(offeredSkillIDs: $offeredSkillIDs, keptSkillIDs: $keptSkillIDs)
        }
        // The name follows the song until the player types one of their own (ADR 0298 D1).
        .onChange(of: targetSong?.title) { old, new in
            title = GoalTitle.following(title, from: old, to: new)
        }
        .skillFixSheet($fixExercise, profile: profiles.first, context: context)
    }

    /// A skill's fix, tapped — the same handling as `GoalEditorView`'s.
    private func applyFix(_ skillID: String, _ fix: SkillAssociation.Fix) {
        guard let exercise = SkillFixExercise(fix: fix, skillID: skillID) else { return }
        fixExercise = exercise
        haptic(.light)
    }

    private var metAndDeleteSection: some View {
        Group {
            if existing != nil {
                Section {
                    Toggle("Mark as met", isOn: $isMet)
                        .font(.futura(.body))
                        .tint(PocketColor.practice)
                        .listRowBackground(PocketColor.background)
                    Button(role: .destructive) { deleteGoal() } label: {
                        Label("Delete goal", systemImage: "trash")
                            .font(.futura(.body))
                    }
                    .listRowBackground(PocketColor.background)
                } footer: {
                    Text("A met goal stays in your list but stops shaping new sessions.")
                        .font(.futura(.caption))
                }
            }
        }
    }

    // MARK: - State

    private func loadExisting() {
        guard let existing, offeredSkillIDs.isEmpty else { return }
        // A goal saved under the song template's placeholder opens named for its song (ADR 0298 D1).
        title = GoalTitle.following(existing.title, from: nil, to: existing.targetSong?.title)
        offeredSkillIDs = existing.skillIDs
        keptSkillIDs = Set(existing.skillIDs)
        targetSong = existing.targetSong
        setSongIDs = Set(existing.setSongIDs)
        holdsSet = existing.isSet
        isMet = existing.isMet
    }

    private func choose(_ candidate: GoalTemplate) {
        template = candidate
        title = candidate.title
        holdsSet = candidate.holdsSet
        offeredSkillIDs = candidate.skillIDs
        keptSkillIDs = Set(candidate.skillIDs)
        haptic(.light)
    }

    /// **Something else** — go to the form with nothing seeded and open the catalogue straight away,
    /// because an empty Skills section with only an "Add skills" button is a dead end to land on.
    private func startBlank() {
        startedBlank = true
        showingSkillPicker = true
        haptic(.light)
    }

    // MARK: - Persistence

    /// Commit the edit. A new goal takes `newGoalOrder` — the bottom of the ranking — so authoring
    /// never silently reorders what the player already arranged; promoting it is a deliberate drag.
    private func save() {
        let keptOrdered = offeredSkillIDs.filter { keptSkillIDs.contains($0) }
        let finalTitle = title.trimmingCharacters(in: .whitespaces)
        let goal = existing ?? created ?? LongTermGoal(order: newGoalOrder)
        goal.title = finalTitle.isEmpty ? (template?.title ?? "Long-term goal") : finalTitle
        goal.skillIDs = keptOrdered
        goal.targetSong = needsTargetSong ? targetSong : nil
        goal.setSongIDs = holdsSet ? liveSetSongIDs : []
        goal.isMet = isMet
        if existing == nil, created == nil {
            context.insert(goal)
            created = goal
        }
        commit()
    }

    /// The save and the close, which *Try again* repeats. A failed save keeps the editor open (ADR 0318).
    private func commit() {
        guard context.saveOrLog() else { saveFailed = true; return }
        haptic(.medium)
        dismiss()
    }

    private func deleteGoal() {
        if let existing { context.delete(existing); context.saveOrLog() }
        haptic(.medium)
        dismiss()
    }
}

#Preview("Long-term goal editor — new") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: LongTermGoal.self, Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    return LongTermGoalEditorView(existing: nil, songs: [])
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
