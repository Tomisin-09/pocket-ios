import SwiftData
import SwiftUI

/// The **add-unit picker** for the routine editor (ADR 0066, slice 2): a sheet listing the
/// units you can drop into a routine, **Exercises first** (the exercises-first direction —
/// technique mode, audio-free, works with an empty library), then **Loops** (repertoire
/// mode). Songs are intentionally absent until the player can hand off to the full waveform
/// screen (slice 3); a routine is exercise/loop-only for now.
///
/// Pure picker: it reports the chosen unit through a callback and dismisses; the editor owns
/// creating the `RoutineItem` and ordering it.
struct AddRoutineUnitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Loop.name) private var loops: [Loop]

    let onPickExercise: (Exercise) -> Void
    let onPickLoop: (Loop) -> Void

    /// Only loops with a measured command tempo are trainable in a routine (same gate as the
    /// loop library — an unmeasured loop has no ramp for the player to run).
    private var trainableLoops: [Loop] { loops.filter { $0.commandTempo != nil } }

    var body: some View {
        NavigationStack {
            List {
                Section("Exercises") {
                    if exercises.isEmpty {
                        emptyHint("No exercises yet — create one in the Exercises library.")
                    } else {
                        ForEach(exercises) { exercise in
                            Button {
                                onPickExercise(exercise)
                                haptic(.medium)
                                dismiss()
                            } label: {
                                PracticeUnitRow(
                                    title: exercise.name.isEmpty ? "Untitled" : exercise.name,
                                    progress: "Command \(exercise.command) → "
                                        + "\(exercise.derivedTarget) BPM")
                            }
                            .listRowBackground(PocketColor.background)
                        }
                    }
                }
                Section("Loops") {
                    if trainableLoops.isEmpty {
                        emptyHint("No measured loops yet — set a command tempo on a loop first.")
                    } else {
                        ForEach(trainableLoops) { loop in
                            Button {
                                onPickLoop(loop)
                                haptic(.medium)
                                dismiss()
                            } label: {
                                PracticeUnitRow(
                                    title: loop.name.isEmpty ? "Untitled loop" : loop.name,
                                    context: loop.song?.title,
                                    progress: "Command \(Int((loop.command * 100).rounded()))%")
                            }
                            .listRowBackground(PocketColor.background)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Add to routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(PocketColor.practice)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.futura(.footnote))
            .foregroundStyle(PocketColor.textSecondary)
            .listRowBackground(PocketColor.background)
    }
}
