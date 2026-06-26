import SwiftData
import SwiftUI

/// The exercise library (ADR 0043, slice 6): the saved metronome presets, where a preset
/// *is* a practice exercise. Save the current configuration as a named exercise, tap one to
/// load its full configuration (tempo, signature, subdivision, automator recipe), and
/// rename / delete. Reached from the metronome screen's presets button.
struct MetronomeLibrarySheet: View {
    let engine: StandaloneMetronomeEngine
    /// The exercise currently loaded on the screen — set when one is tapped, cleared if it's
    /// deleted, so the screen title can show its name.
    @Binding var loadedExercise: MetronomeExercise?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MetronomeExercise.name) private var exercises: [MetronomeExercise]

    @State private var savingNew = false
    @State private var newName = ""
    @State private var renaming: MetronomeExercise?
    @State private var renameText = ""
    @State private var confirmingUpdate = false
    /// The to-be-saved configuration, captured when the user taps "Update" so the
    /// confirmation shows exactly what will overwrite the preset.
    @State private var pendingSummary = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        newName = ""
                        savingNew = true
                    } label: {
                        Label("Save current settings as a preset", systemImage: "plus.circle.fill")
                            .foregroundStyle(PocketColor.metronome)
                    }
                    if let loaded = loadedExercise {
                        Button {
                            pendingSummary = MetronomeExerciseBridge
                                .preview(from: engine).configurationSummary
                            confirmingUpdate = true
                        } label: {
                            Label("Update “\(loaded.name)” with current settings",
                                  systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }

                Section("Exercises") {
                    if exercises.isEmpty {
                        Text("No presets yet. Dial in a tempo and meter, then save it as an exercise.")
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
            .alert("Save preset", isPresented: $savingNew) {
                TextField("Name (e.g. Spider)", text: $newName)
                Button("Save", action: saveNew)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save as an exercise:\n\(MetronomeExerciseBridge.preview(from: engine).configurationSummary)")
            }
            .alert("Rename preset", isPresented: Binding(get: { renaming != nil },
                                                         set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $renameText)
                Button("Save", action: commitRename)
                Button("Cancel", role: .cancel) { renaming = nil }
            }
            .confirmationDialog("Update “\(loadedExercise?.name ?? "")”?",
                                isPresented: $confirmingUpdate, titleVisibility: .visible) {
                Button("Save these settings", action: commitUpdate)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(pendingSummary)
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name.isEmpty ? "Untitled" : exercise.name)
                        .font(.body)
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(exercise.configurationSummary)
                        .font(.caption)
                        .foregroundStyle(PocketColor.textSecondary)
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

    private func commitUpdate() {
        guard let loaded = loadedExercise else { return }
        MetronomeExerciseBridge.update(loaded, from: engine)
        haptic(.medium)
    }

    private func saveNew() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let exercise = MetronomeExerciseBridge.capture(named: name, from: engine)
        context.insert(exercise)
        loadedExercise = exercise
        haptic(.medium)
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
