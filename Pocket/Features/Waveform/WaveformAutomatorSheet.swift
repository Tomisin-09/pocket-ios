import SwiftUI

/// Set up a loop's **automator** — the speed ramp that steps playback faster as you nail
/// it (ADR 0013). Reached by the "A" control on a loop row. Mirrors the other edit sheets:
/// edits local `@State`, writes back to the `Loop` on **Done** (so **Cancel** discards),
/// then `onSave` lets the practice model engage the ramp if the loop is playing.
struct AutomatorSheet: View {
    let loop: Loop
    let song: Song
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var enabled: Bool
    @State private var startSpeed: Double
    @State private var stepSpeed: Double
    @State private var ceilingSpeed: Double
    @State private var repeatsPerStep: Int

    init(loop: Loop, song: Song, onSave: @escaping () -> Void) {
        self.loop = loop
        self.song = song
        self.onSave = onSave
        let config = loop.automator
        _enabled = State(initialValue: config.enabled)
        _startSpeed = State(initialValue: config.startSpeed)
        _stepSpeed = State(initialValue: config.stepSpeed)
        _ceilingSpeed = State(initialValue: config.ceilingSpeed)
        _repeatsPerStep = State(initialValue: config.repeatsPerStep)
    }

    /// The live config from the current controls — drives the summary footer.
    private var draft: AutomatorConfig {
        AutomatorConfig(startSpeed: startSpeed, stepSpeed: stepSpeed, ceilingSpeed: ceilingSpeed,
                        repeatsPerStep: repeatsPerStep, enabled: enabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable speed ramp", isOn: $enabled)
                        .tint(PocketColor.active)
                } footer: {
                    Text("Plays \(loop.name) from the start speed and steps up as it repeats, "
                         + "until it reaches the target — then holds.")
                }

                Section("Ramp") {
                    speedRow("Start", value: $startSpeed)
                    LabeledContent("Step") {
                        Stepper(String(format: "+%.2f×", stepSpeed), value: $stepSpeed,
                                in: 0.01...0.50, step: 0.01)
                    }
                    speedRow("Target", value: $ceilingSpeed)
                    LabeledContent("Every") {
                        Stepper("\(repeatsPerStep) pass\(repeatsPerStep == 1 ? "" : "es")",
                                value: $repeatsPerStep, in: 1...16)
                    }
                }

                Section { summary }
            }
            .navigationTitle("Automator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// A labelled speed slider (0.25–2.0×) with a mono readout, plus the BPM equivalent
    /// when the song's tempo is known.
    private func speedRow(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(label) {
                Text(speedLabel(value.wrappedValue)).font(.pocketMono(.body))
            }
            Slider(value: value, in: 0.25...2.0, step: 0.05).tint(PocketColor.active)
        }
    }

    @ViewBuilder private var summary: some View {
        if draft.ceilingSpeed > draft.startSpeed, draft.stepSpeed > 0 {
            LabeledContent("Steps to target") {
                Text("\(draft.stepCount)").font(.pocketMono(.body))
            }
        } else {
            Text("Target is at or below the start — no ramp (plays at the start speed).")
                .font(.footnote)
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    private func speedLabel(_ speed: Double) -> String {
        guard let bpm = song.bpm else { return String(format: "%.2f×", speed) }
        return String(format: "%.2f×  ·  %d BPM", speed, TempoMath.effectiveBPM(songBPM: bpm, speed: speed))
    }

    private func save() {
        loop.automator = draft   // writes start (= loop.speed) + the automator fields through
        onSave()
        dismiss()
    }
}
