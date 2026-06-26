import SwiftUI

/// The "save as a new exercise" form (ADR 0043, slice 7). Beyond a name, it lets you set the
/// **working tempo** (where you practise today) and the **target tempo** (the goal you climb
/// toward) up front — without this, a save with the automator off would store working ==
/// target and the progress bar would read "At target" immediately. The other settings (meter,
/// subdivision, automator recipe) are captured from the live screen.
///
/// Prefilled by the caller: working/target default to the ramp floor/ceiling when the
/// automator is armed, else the current tempo and a sensible goal above it.
struct SaveExerciseSheet: View {
    let initialWorking: Int
    let initialTarget: Int
    /// Called with the trimmed name and chosen tempos when the user confirms.
    let onSave: (String, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var working: Int
    @State private var target: Int

    private let range = StandaloneMetronomeEngine.bpmRange

    init(initialWorking: Int, initialTarget: Int,
         onSave: @escaping (String, Int, Int) -> Void) {
        self.initialWorking = initialWorking
        self.initialTarget = initialTarget
        self.onSave = onSave
        _working = State(initialValue: initialWorking)
        _target = State(initialValue: initialTarget)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Spider", text: $name)
                }
                Section {
                    Stepper("Working tempo · \(working) BPM", value: $working,
                            in: range.lowerBound...range.upperBound)
                    Stepper("Target tempo · \(target) BPM", value: $target,
                            in: range.lowerBound...range.upperBound)
                } header: {
                    Text("Progress goal")
                } footer: {
                    Text("Where you practise today, climbing toward the target. Nudge the "
                         + "working tempo up over time as you improve.")
                }
            }
            .navigationTitle("Save exercise")
            .navigationBarTitleDisplayMode(.inline)
            .tint(PocketColor.metronome)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(trimmedName, working, target)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
