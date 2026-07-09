import SwiftData
import SwiftUI

/// The **goal editor** (V2 planner Slice 3, ADR 0015 S1 / Decision 7): create a practice goal from a
/// curated `GoalTemplate`, or edit an existing one. A new goal starts on the template picker; picking
/// one seeds the title and a sensible skill set the user then **trims** (no free-text / AI in V2).
/// Priority is the three-level `GoalPriority` surface over the stored `weight`; a repertoire goal
/// (any selected skill in `repertoire` mode) additionally asks for a target song (Path B). Editing
/// adds a **met** toggle and delete. Mutations are applied to the passed context and saved on Save.
struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// The goal under edit, or `nil` to create a new one (which begins on the template picker).
    let existing: Goal?
    /// The song library, for the repertoire target picker.
    let songs: [Song]

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

    /// Whether any kept skill routes via the target song (Path B) — drives the song picker's presence.
    private var needsTargetSong: Bool {
        keptSkillIDs.contains { TechniqueTaxonomy.mode($0)?.isRepertoire == true }
    }

    /// A new goal with no template chosen yet shows the picker instead of the field form.
    private var isPickingTemplate: Bool { existing == nil && template == nil }

    var body: some View {
        NavigationStack {
            Group {
                if isPickingTemplate {
                    templatePicker
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

    // MARK: - Template picker (new goal)

    private var templatePicker: some View {
        List {
            Section {
                ForEach(GoalTemplateLibrary.all) { candidate in
                    Button { choose(candidate) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: candidate.iconName)
                                .font(.futura(.title3))
                                .foregroundStyle(PocketColor.practice)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.title)
                                    .font(.futura(.body))
                                    .foregroundStyle(PocketColor.textPrimary)
                                Text(candidate.blurb)
                                    .font(.futura(.caption))
                                    .foregroundStyle(PocketColor.textSecondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.futura(.caption))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PocketColor.background)
                }
            } header: {
                Text("Start from a goal")
            } footer: {
                Text("Pick a starting point, then trim the skills to what you want to focus on.")
                    .font(.futura(.caption))
            }
        }
    }

    // MARK: - Editor form

    private var editorForm: some View {
        List {
            Section("Name") {
                TextField("Goal name", text: $title)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
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

            skillsSection

            if needsTargetSong { targetSongSection }

            metAndDeleteSection
        }
        .sheet(isPresented: $showingSkillPicker) {
            SkillPickerSheet(offeredSkillIDs: $offeredSkillIDs, keptSkillIDs: $keptSkillIDs)
        }
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

    private var skillsSection: some View {
        Section {
            ForEach(offeredSkillIDs, id: \.self) { skillID in
                Button { toggle(skillID) } label: {
                    HStack {
                        Text(TechniqueTaxonomy.info(skillID)?.name ?? skillID)
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                        Spacer()
                        Image(systemName: keptSkillIDs.contains(skillID) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(keptSkillIDs.contains(skillID)
                                             ? PocketColor.practice : PocketColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(PocketColor.background)
            }
            Button { showingSkillPicker = true } label: {
                Label("Add skills", systemImage: "plus.circle")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.practice)
            }
            .listRowBackground(PocketColor.background)
        } header: {
            Text("Skills")
        } footer: {
            Text(keptSkillIDs.isEmpty
                 ? "Keep at least one skill for this goal to schedule anything."
                 : "Tap to include or drop a skill, or add more from the full catalog.")
                .font(.futura(.caption))
        }
    }

    private var targetSongSection: some View {
        Section {
            if songs.isEmpty {
                Text("Add a song to your library to target it here.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                Picker("Song", selection: $targetSong) {
                    Text("None").tag(Song?.none)
                    ForEach(songs) { song in
                        Text(song.title.isEmpty ? "Untitled" : song.title).tag(Song?.some(song))
                    }
                }
                .font(.futura(.body))
                .tint(PocketColor.practice)
                .listRowBackground(PocketColor.background)
            }
        } header: {
            Text("Target song")
        } footer: {
            Text("Learning a song schedules its loops and a play-through. Pick one to include it.")
                .font(.futura(.caption))
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

    private func toggle(_ skillID: String) {
        if keptSkillIDs.contains(skillID) { keptSkillIDs.remove(skillID) } else { keptSkillIDs.insert(skillID) }
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
