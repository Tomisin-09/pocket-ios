import SwiftUI

/// Create a new exercise from within **Practice** (ADR 0046, Phase A): a name and your
/// **command tempo** — the fastest you can play it cleanly and repeatably right now. The
/// warm-up **working** floor and the **reach** derive from the command, so the number you type
/// here is the command the run screen shows (no working/command mismatch). You tune working and
/// reach when you run the drill. This is Practice's own create path so exercises no longer depend
/// on the metronome's save UI; the automator's "Save as exercise" seam feeds the same flow by
/// presenting this sheet with `initialCommand` set to the discovered breakdown tempo.
struct NewExerciseSheet: View {
    /// Pre-fills the command stepper — the discovered tempo when launched from the automator
    /// seam, the engine default when created fresh in Practice.
    var initialCommand: Int = StandaloneMetronomeEngine.defaultBPM
    /// Called with the trimmed name and chosen **command** tempo when the user confirms.
    let onCreate: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command: Int

    private let range = StandaloneMetronomeEngine.bpmRange

    init(initialCommand: Int = StandaloneMetronomeEngine.defaultBPM,
         onCreate: @escaping (String, Int) -> Void) {
        self.initialCommand = initialCommand
        self.onCreate = onCreate
        _command = State(initialValue: initialCommand)
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
