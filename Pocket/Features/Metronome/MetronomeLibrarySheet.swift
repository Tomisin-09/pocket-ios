import SwiftData
import SwiftUI

/// The exercise library (ADR 0043, slice 6) — a **pure browser** over the saved metronome
/// presets, where a preset *is* a practice exercise. Tap one to load its full configuration
/// (tempo, signature, subdivision, automator recipe), or swipe to rename / delete. Saving,
/// updating and leaving an exercise are direct actions on the metronome screen itself
/// (`ExerciseActionBar`), so they're not duplicated here. Reached from the screen's 📚 button.
struct MetronomeLibrarySheet: View {
    let engine: StandaloneMetronomeEngine
    /// The exercise currently loaded on the screen — set when one is tapped, cleared if it's
    /// deleted, so the screen title can show its name.
    @Binding var loadedExercise: MetronomeExercise?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MetronomeExercise.name) private var exercises: [MetronomeExercise]

    @State private var renaming: MetronomeExercise?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Exercises") {
                    if exercises.isEmpty {
                        Text("No presets yet. Dial in a tempo and meter, then tap + on the "
                             + "metronome to save it as an exercise.")
                            .font(.footnote)
                            .foregroundStyle(PocketColor.textSecondary)
                    } else {
                        ForEach(exercises) { exercise in
                            row(exercise)
                        }
                    }
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(PocketColor.metronome)
                }
            }
            .alert("Rename preset", isPresented: Binding(get: { renaming != nil },
                                                         set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $renameText)
                Button("Save", action: commitRename)
                Button("Cancel", role: .cancel) { renaming = nil }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ exercise: MetronomeExercise) -> some View {
        Button {
            MetronomeExerciseBridge.apply(exercise, to: engine)
            loadedExercise = exercise
            haptic(.medium)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name.isEmpty ? "Untitled" : exercise.name)
                        .font(.body)
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(exercise.configurationSummary)
                        .font(.caption)
                        .foregroundStyle(PocketColor.textSecondary)
                    // Light-progress climb at a glance (slice 7) — the fuller bar of the pair.
                    HStack(spacing: 8) {
                        TempoProgressBar(fraction: exercise.progress.fraction)
                        Text(exercise.progress.status)
                            .font(.caption2)
                            .foregroundStyle(PocketColor.textSecondary)
                            .fixedSize()
                    }
                }
                Spacer()
                if loadedExercise?.uid == exercise.uid {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PocketColor.metronome)
                }
            }
        }
        .listRowBackground(PocketColor.background)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { delete(exercise) } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                renameText = exercise.name
                renaming = exercise
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(PocketColor.metronome)
        }
    }

    private func commitRename() {
        guard let exercise = renaming else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { exercise.name = name }
        renaming = nil
    }

    private func delete(_ exercise: MetronomeExercise) {
        if loadedExercise?.uid == exercise.uid { loadedExercise = nil }
        context.delete(exercise)
    }
}
