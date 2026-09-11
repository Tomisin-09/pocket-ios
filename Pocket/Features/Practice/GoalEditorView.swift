import SwiftData
import SwiftUI

/// The **goal editor** (V2 planner Slice 3, ADR 0015 S1 / Decision 7): create a practice goal from a
/// curated `GoalTemplate`, or edit an existing one. A new goal starts on the template picker; picking
/// one seeds the title and a sensible skill set the user then **trims** (no free-text / AI in V2).
/// Priority is the three-level `GoalPriority` surface over the stored `weight`; a repertoire goal
/// (any selected skill in `repertoire` mode) additionally asks for a target song (Path B). Editing
/// adds a **met** toggle and delete. Mutations are applied to the passed context and saved on Save.
///
/// This edits the **short-term** tier — what you want out of *this* session (ADR 0171). The
/// template picker, skill trimming and target song are shared with `LongTermGoalEditorView` via
/// `GoalAuthoringSections`; what is local here is the priority segment, because weighting is the
/// thing that distinguishes this tier from the ranked one.
struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// The goal under edit, or `nil` to create a new one (which begins on the template picker).
    let existing: Goal?
    /// The song library, for the repertoire target picker.
    let songs: [Song]
    /// The drill and loop libraries, for the line under each skill saying what it would actually
    /// pull into a session (ADR 0216 D4).
    @Query private var exercises: [Exercise]
    @Query private var loops: [Loop]
    /// For a drill made from a skill's fix: the profile's instrument and default command tempo.
    @Query private var profiles: [Profile]
    /// The type a skill's fix is creating a drill of, while that sheet is up.
    @State private var newExerciseTemplate: ExerciseTemplate?

    /// The chosen template for a new goal — `nil` until picked (the picker is shown until then).
    @State private var template: GoalTemplate?
    @State private var title = ""
    @State private var priority: GoalPriority = .normal
    /// Every skill offered as a trimmable row (the template's or the existing goal's seeded set).
    @State private var offeredSkillIDs: [String] = []
    /// The subset currently kept — tapping a row toggles membership.
    @State private var keptSkillIDs: Set<String> = []
    @State private var targetSong: Song?
    @State private var isMet = false
    /// Whether the full-catalog skill picker is showing (R2 — add skills beyond the template's seed).
    @State private var showingSkillPicker = false
    /// Whether the player chose **Something else** — no template, straight to the form. Its own flag
    /// rather than a sentinel template, because `template` is also what supplies the fallback title,
    /// and a blank start deliberately has none.
    @State private var startedBlank = false

    /// Whether any kept skill routes via the target song (Path B) — drives the song picker's presence.
    private var needsTargetSong: Bool { goalNeedsTargetSong(keptSkillIDs) }

    /// A new goal with no template chosen yet shows the picker instead of the field form.
    private var isPickingTemplate: Bool { existing == nil && template == nil && !startedBlank }

    var body: some View {
        NavigationStack {
            Group {
                if isPickingTemplate {
                    GoalTemplatePicker(onPick: choose, onStartBlank: startBlank)
                } else {
                    editorForm
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle(existing == nil ? "New goal" : "Edit goal")
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
                            .disabled(keptSkillIDs.isEmpty)
                    }
                }
            }
        }
        .onAppear(perform: loadExisting)
    }

    // MARK: - Editor form

    private var editorForm: some View {
        List {
            Section("Name") {
                TextField("Goal name", text: $title)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    // Same as the routine and loop name fields: the placeholder is not a label, and
                    // the `Name` header is a separate element (ADR 0213 D1).
                    .accessibilityLabel("Goal name")
                    .listRowBackground(PocketColor.background)
            }

            Section {
                Picker("Priority", selection: $priority) {
                    ForEach(GoalPriority.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(PocketColor.background)
            } header: {
                Text("Priority")
            } footer: {
                Text("How hard this goal pulls its skills up today's session.")
                    .font(.futura(.caption))
            }

            GoalSkillsSection(offeredSkillIDs: $offeredSkillIDs, keptSkillIDs: $keptSkillIDs,
                              showingSkillPicker: $showingSkillPicker,
                              reach: goalSkillReach(offeredSkillIDs,
                                                    targetSong: needsTargetSong ? targetSong : nil,
                                                    exercises: exercises, loops: loops, songs: songs),
                              onFix: applyFix)

            if needsTargetSong { GoalTargetSongSection(songs: songs, targetSong: $targetSong) }

            metAndDeleteSection
        }
        .sheet(isPresented: $showingSkillPicker) {
            SkillPickerSheet(offeredSkillIDs: $offeredSkillIDs, keptSkillIDs: $keptSkillIDs)
        }
        .sheet(isPresented: Binding(get: { newExerciseTemplate != nil },
                                    set: { if !$0 { newExerciseTemplate = nil } })) {
            if let newExerciseTemplate {
                NewExerciseSheet(initialCommand: profiles.first?.experience?.defaultCommandTempo
                                     ?? StandaloneMetronomeEngine.defaultCommandBPM,
                                 fixedTemplate: newExerciseTemplate,
                                 defaultInstrument: profiles.first?.preferredInstrument ?? .guitar,
                                 onCreate: { $0.finalise(in: context) })
            }
        }
    }

    /// A skill's fix, tapped. Only *make an exercise* acts; the rest are lines of text. The drill is
    /// made through the one insert path (ADR 0128), and the skill's line updates when it lands.
    private func applyFix(_ fix: SkillAssociation.Fix) {
        guard case .makeExercise(let template) = fix else { return }
        newExerciseTemplate = template
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
                    Text("A met goal stays in your history but stops shaping new sessions.")
                        .font(.futura(.caption))
                }
            }
        }
    }

    // MARK: - State

    /// Seed the editor from an existing goal (once, on appear). New goals seed from their template
    /// via `choose(_:)` instead.
    private func loadExisting() {
        guard let existing, offeredSkillIDs.isEmpty else { return }
        title = existing.title
        priority = GoalPriority.nearest(toWeight: existing.weight)
        offeredSkillIDs = existing.skillIDs
        keptSkillIDs = Set(existing.skillIDs)
        targetSong = existing.targetSong
        isMet = existing.isMet
    }

    /// Seed a new goal's fields from the picked template and move on to the field form.
    private func choose(_ candidate: GoalTemplate) {
        template = candidate
        title = candidate.title
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

    /// Commit the edit: mutate the existing goal or insert a new one, preserving the offered skill
    /// order (only the kept subset is stored). A repertoire goal without a chosen song still saves —
    /// it simply produces no Path-B candidates until one is picked (the app never refuses, ADR 0073).
    private func save() {
        let keptOrdered = offeredSkillIDs.filter { keptSkillIDs.contains($0) }
        let finalTitle = title.trimmingCharacters(in: .whitespaces)
        let goal = existing ?? Goal()
        goal.title = finalTitle.isEmpty ? (template?.title ?? "Goal") : finalTitle
        goal.weight = priority.weight
        goal.skillIDs = keptOrdered
        goal.targetSong = needsTargetSong ? targetSong : nil
        goal.isMet = isMet
        if existing == nil { context.insert(goal) }
        try? context.save()
        haptic(.medium)
        dismiss()
    }

    private func deleteGoal() {
        if let existing { context.delete(existing); try? context.save() }
        haptic(.medium)
        dismiss()
    }
}

#Preview("Goal editor — new") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Goal.self, Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    return GoalEditorView(existing: nil, songs: [])
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
