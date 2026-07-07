import SwiftData
import SwiftUI

/// The **add-unit picker** for the routine editor (ADR 0066, slice 2): a sheet listing the
/// units you can drop into a routine, grouped into categories so a long library stays
/// scannable — **Exercises by template** (Warm-up, Scales, Arpeggios, …, the same taxonomy
/// as the Exercises library) then **Loops by song**. Exercises come first (the
/// exercises-first direction — technique mode, audio-free, works with an empty library).
///
/// Songs are intentionally absent until the player can run them (slice 3); a routine is
/// exercise/loop-only for now. Pure picker: it reports the chosen unit through a callback and
/// dismisses; the editor owns creating the `RoutineItem` and ordering it.
struct AddRoutineUnitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Loop.name) private var loops: [Loop]

    let onPickExercise: (Exercise) -> Void
    let onPickLoop: (Loop) -> Void

    /// Exercises grouped by their template, in the canonical template order (`allCases`), so the
    /// sections read the same as the Exercises library. Only non-empty groups are shown.
    private var exerciseGroups: [(title: String, items: [Exercise])] {
        ExerciseTemplate.allCases.compactMap { template in
            let matches = exercises.filter { $0.template == template }
            return matches.isEmpty ? nil : (template.displayName, matches)
        }
    }

    /// Trainable loops (a measured command tempo — the same gate as the loop library) grouped by
    /// their song title, alphabetically; loose loops fall under "Other".
    private var loopGroups: [(title: String, items: [Loop])] {
        let trainable = loops.filter { $0.commandTempo != nil }
        let grouped = Dictionary(grouping: trainable) { loop -> String in
            let title = loop.song?.title ?? ""
            return title.isEmpty ? "Other" : title
        }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                if exercises.isEmpty && loopGroups.isEmpty {
                    emptyHint("Nothing to add yet — create an exercise, or measure a loop's "
                              + "command tempo, then build a routine from it.")
                }
                ForEach(exerciseGroups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.items) { exercise in
                            pickButton(title: exercise.name.isEmpty ? "Untitled" : exercise.name,
                                       context: nil,
                                       progress: "Command \(exercise.command) → "
                                        + "\(exercise.derivedTarget) BPM") {
                                onPickExercise(exercise)
                            }
                        }
                    }
                }
                ForEach(loopGroups, id: \.title) { group in
                    Section("Loops · \(group.title)") {
                        ForEach(group.items) { loop in
                            pickButton(title: loop.name.isEmpty ? "Untitled loop" : loop.name,
                                       context: loop.song?.title,
                                       progress: "Command "
                                        + "\(Int((loop.command * 100).rounded()))%") {
                                onPickLoop(loop)
                            }
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

    private func pickButton(title: String, context: String?, progress: String,
                            action: @escaping () -> Void) -> some View {
        Button {
            action()
            haptic(.medium)
            dismiss()
        } label: {
            PracticeUnitRow(title: title, context: context, progress: progress)
        }
        .listRowBackground(PocketColor.background)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.futura(.footnote))
            .foregroundStyle(PocketColor.textSecondary)
            .listRowBackground(PocketColor.background)
    }
}
