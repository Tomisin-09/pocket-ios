import SwiftUI

/// Create a new exercise from within **Practice** (ADR 0046, Phase A): a name and the
/// **working tempo** you practise it at today. Command and reach are left unmeasured — you set
/// them when you first run the drill and **promote** the fastest tempo you own. This is
/// Practice's own create path so exercises no longer depend on the metronome's save UI (which
/// Slice 4 retires); the automator's "Save as exercise" discovery seam feeds the same flow.
struct NewExerciseSheet: View {
    /// Called with the trimmed name and chosen working tempo when the user confirms.
    let onCreate: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var working = StandaloneMetronomeEngine.defaultBPM

    private let range = StandaloneMetronomeEngine.bpmRange

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
                } header: {
                    Text("Where you start")
                } footer: {
                    Text("The comfortable warm-up tempo. You'll set the fastest you own — and "
                         + "reach for more — when you run it.")
                }
            }
            .navigationTitle("New exercise")
            .navigationBarTitleDisplayMode(.inline)
            .tint(PocketColor.practice)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(trimmedName, working)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("New exercise") {
    NewExerciseSheet { _, _ in }
}
