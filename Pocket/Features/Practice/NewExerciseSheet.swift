import SwiftUI

/// Create a new exercise from within **Practice** (ADR 0046, Phase A): a name and your
/// **command tempo** — the fastest you can play it cleanly and repeatably right now. The
/// warm-up **working** floor and the **reach** derive from the command, so the number you type
/// here is the command the run screen shows (no working/command mismatch). You tune working and
/// reach when you run the drill. This is Practice's own create path so exercises no longer depend
/// on the metronome's save UI; the automator's "Save as exercise" seam feeds the same flow.
struct NewExerciseSheet: View {
    /// Called with the trimmed name and chosen **command** tempo when the user confirms.
    let onCreate: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command = StandaloneMetronomeEngine.defaultBPM

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
                    Stepper("Command tempo · \(command) BPM", value: $command,
                            in: range.lowerBound...range.upperBound)
                } header: {
                    Text("Your command tempo")
                } footer: {
                    Text("The fastest you can play it cleanly and repeatably right now. The "
                         + "warm-up floor and the reach derive from it — tune them when you run it.")
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
                        onCreate(trimmedName, command)
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
