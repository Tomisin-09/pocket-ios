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

    @State private var template: GoalTemplate?
    @State private var title = ""
    @State private var offeredSkillIDs: [String] = []
    @State private var keptSkillIDs: Set<String> = []
    @State private var targetSong: Song?
    @State private var isMet = false
    @State private var showingSkillPicker = false
    /// Whether the player chose **Something else** — no template, straight to the form. Its own flag
    /// rather than a sentinel template, because `template` is also what supplies the fallback title,
    /// and a blank start deliberately has none.
    @State private var startedBlank = false

    private var needsTargetSong: Bool { goalNeedsTargetSong(keptSkillIDs) }

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
                              showingSkillPicker: $showingSkillPicker)

            if needsTargetSong { GoalTargetSongSection(songs: songs, targetSong: $targetSong) }

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
                    Text("A met goal stays in your list but stops shaping new sessions.")
                        .font(.futura(.caption))
                }
            }
        }
    }

    // MARK: - State

    private func loadExisting() {
        guard let existing, offeredSkillIDs.isEmpty else { return }
        title = existing.title
        offeredSkillIDs = existing.skillIDs
        keptSkillIDs = Set(existing.skillIDs)
        targetSong = existing.targetSong
        isMet = existing.isMet
    }

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

    /// Commit the edit. A new goal takes `newGoalOrder` — the bottom of the ranking — so authoring
    /// never silently reorders what the player already arranged; promoting it is a deliberate drag.
    private func save() {
        let keptOrdered = offeredSkillIDs.filter { keptSkillIDs.contains($0) }
        let finalTitle = title.trimmingCharacters(in: .whitespaces)
        let goal = existing ?? LongTermGoal(order: newGoalOrder)
        goal.title = finalTitle.isEmpty ? (template?.title ?? "Long-term goal") : finalTitle
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

#Preview("Long-term goal editor — new") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: LongTermGoal.self, Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    return LongTermGoalEditorView(existing: nil, songs: [])
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
