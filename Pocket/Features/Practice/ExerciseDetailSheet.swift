import SwiftData
import SwiftUI

/// A **read-only reference sheet** for one exercise (V1 feedback #2; ADR 0077): the place to read —
/// and lightly annotate — what an exercise *is*, kept entirely separate from tempo tuning and content
/// authoring. Neither tempo nor the drill's shape is editable here anymore (ADR 0077 pulled both
/// out): tempo is tuned on the run screen (and, in a routine, on the block surface), and the
/// content/shape editor moved to the board's "Edit shape" sheet (`ExerciseShapeSheet`). This sheet
/// surfaces, top to bottom, an editable **description** (the model's `notes`), the self-rated
/// **mastery**, the meter + subdivision (**Feel**), and — at the bottom — the read-only **template**
/// chip (ADR 0068, immutable). Reached from the exercise run screen's nav bar (ⓘ). The routine-staircase
/// preview was dropped as redundant (device feedback 2026-07-11) — the staircase already lives on the
/// run screen where you tune it.
///
/// Editable: **only** description and mastery — each committed on Done / dismiss (a no-op when
/// unchanged) so a quick open-and-close never writes. Tempo, routine shape, and the drill's content
/// are tuned elsewhere.
struct ExerciseDetailSheet: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var notes: String
    /// The exercise's self-rated mastery (0–5, `nil` = unrated), held locally and committed on
    /// Done — the planner's dueScore *need* signal (V2 planner Slice 1, ADR 0070: self-set, never
    /// measured). Mirrors the loop editor's mastery dots.
    @State private var mastery: Int?

    init(exercise: Exercise) {
        self.exercise = exercise
        _notes = State(initialValue: exercise.notes)
        _mastery = State(initialValue: exercise.mastery)
    }

    var body: some View {
        NavigationStack {
            Form {
                descriptionSection
                ExerciseProgressSection(mastery: $mastery, lastPracticed: exercise.lastPracticed)
                feelSection
                templateSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .tint(PocketColor.practice)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitNotes(); commitMastery()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Template (read-only, ADR 0068)

    /// The exercise's template — set at creation and **immutable** (ADR 0068). Shown so the drill's
    /// type reads at a glance; not editable, because changing it would mean a different renderer and
    /// a different authoring surface (delete + recreate to change type).
    private var templateSection: some View {
        Section {
            HStack(spacing: 8) {
                Text("Template").foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 8)
                Label(exercise.template.displayName, systemImage: exercise.template.iconName)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
            }
        } footer: {
            Text("The kind of drill, set when it was created. It groups the exercise in your "
                 + "library and can't be changed.")
        }
    }

    // MARK: - Description (editable) + tags

    private var descriptionSection: some View {
        Section {
            TextField("Technique cues, target feel, where it's from…", text: $notes, axis: .vertical)
                .lineLimit(3...8)
                .keyboardDoneButton()
            if !exercise.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(exercise.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.futura(.caption, weight: .semibold))
                            .foregroundStyle(PocketColor.practice)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(PocketColor.practice.opacity(0.16)))
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Description")
        } footer: {
            Text("A note to yourself about the drill — saved with the exercise.")
        }
    }

    // MARK: - Meter & subdivision (read-only)

    private var feelSection: some View {
        Section("Feel") {
            LabeledContent("Time signature") {
                Text(exercise.timeSignatureLabel).font(.pocketMono(.body))
            }
            LabeledContent("Subdivision") { Text(exercise.subdivision.label) }
        }
    }

    // MARK: - Helpers

    /// Persist an edited description, trimmed. A no-op when unchanged, so opening and closing the
    /// sheet without touching the field never writes to the store.
    private func commitNotes() {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != exercise.notes else { return }
        exercise.notes = trimmed
        try? modelContext.save()
    }

    /// Persist an edited mastery rating on Done, only when it differs from what's stored — a
    /// deliberate self-assessment (ADR 0070), never computed from playing.
    private func commitMastery() {
        guard mastery != exercise.mastery else { return }
        exercise.mastery = mastery
        try? modelContext.save()
    }
}

#Preview("Exercise detail — strumming") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let exercise = Exercise(name: "Folk strum", currentTempo: 70, commandTempo: 96,
                            template: .strumming, tags: ["rhythm", "strumming"],
                            notes: "Keep the hand swinging in steady eighths.")
    exercise.setStrumPattern(.folk)
    container.mainContext.insert(exercise)
    return ExerciseDetailSheet(exercise: exercise)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
