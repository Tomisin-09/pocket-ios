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
    /// Pre-fills the meter picker — the metronome's current signature when launched from the
    /// automator seam, 4/4 when created fresh in Practice.
    var initialSignature: TimeSignature = .standard
    /// Called with the trimmed name, chosen **command** tempo, and **time signature** when the
    /// user confirms. The meter drives the run metronome's accents + count-in length (ADR 0052).
    let onCreate: (String, Int, TimeSignature) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command: Int
    @State private var signature: TimeSignature

    private let range = StandaloneMetronomeEngine.bpmRange

    init(initialCommand: Int = StandaloneMetronomeEngine.defaultBPM,
         initialSignature: TimeSignature = .standard,
         onCreate: @escaping (String, Int, TimeSignature) -> Void) {
        self.initialCommand = initialCommand
        self.initialSignature = initialSignature
        self.onCreate = onCreate
        _command = State(initialValue: initialCommand)
        _signature = State(initialValue: initialSignature)
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
                    FieldInfoLabel(title: "Your command tempo",
                                   info: PracticeFieldInfo.exerciseCommandTempo)
                }
                Section {
                    Picker("Time signature", selection: $signature) {
                        ForEach(TimeSignature.presets) { preset in
                            Text("\(preset.name) · \(preset.context)").tag(preset)
                        }
                    }
                } header: {
                    Text("Time signature")
                } footer: {
                    Text("Sets the run's accents and count-in length. Defaults to 4/4.")
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
                        onCreate(trimmedName, command, signature)
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
    NewExerciseSheet { _, _, _ in }
}
