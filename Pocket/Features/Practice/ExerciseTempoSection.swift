import SwiftUI

/// The exercise detail sheet's **Tempo** section (ADR 0071 R4): the working/command/reach anchors,
/// with the **command** nudgeable inline and a short **audio preview** so you can hear the target
/// straight from the sheet. Split out of `ExerciseDetailSheet` to keep that file under the 400-line
/// cap, and standalone (not a `private` member) so it is independently previewable — mirrors how
/// `ExerciseProgressSection` was extracted.
///
/// The command edit is *held* here (a binding) and committed by the host sheet on Done via the
/// canonical `promoteCommand` setter, so the run screen and this surface never diverge (ADR 0057).
/// Working and reach stay read-only — reach is derived from command, and the warm-up floor is tuned
/// on the run screen. No evaluation (ADR 0070): the preview is an audition, nothing is measured.
struct ExerciseTempoSection: View {
    let exercise: Exercise
    /// The edited command tempo, committed by the host sheet on Done. Editable only for a measured
    /// command; an un-measured exercise shows a read-only "not yet measured".
    @Binding var command: Int

    /// A self-contained metronome audio preview — owns its own engine, so it never disturbs a live
    /// practice engine, and auto-stops after a few seconds.
    @State private var preview = CommandTempoPreviewPlayer()

    var body: some View {
        Section {
            LabeledContent("Working") { bpmText(exercise.workingTempo) }
            if exercise.hasMeasuredCommand {
                Stepper(value: $command, in: StandaloneMetronomeEngine.bpmRange) {
                    LabeledContent("Command") { bpmText(command) }
                }
                previewButton
            } else {
                LabeledContent("Command") {
                    Text("not yet measured")
                        .font(.pocketMono(.body))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            LabeledContent("Reach") { bpmText(exercise.derivedTarget) }
        } header: {
            Text("Tempo")
        } footer: {
            Text("Command is the fastest you own it clean; working is the warm-up floor and reach is "
                 + "the goal above command. Nudge command here or hear it, and fine-tune every anchor "
                 + "on the run screen.")
        }
        .onDisappear { preview.stop() }
    }

    /// A short metronome audio preview of the command tempo — an audition, not a run.
    private var previewButton: some View {
        Button {
            preview.toggle(bpm: command, signature: previewSignature)
            haptic(.light)
        } label: {
            Label(preview.isPlaying ? "Stop preview" : "Hear command tempo",
                  systemImage: preview.isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
        }
        .accessibilityHint("Plays a \(CommandTempoPreviewPlayer.previewSeconds)-second metronome "
                           + "click at the command tempo")
    }

    /// The exercise's meter, resolved for the preview click so accents land like a real run.
    private var previewSignature: TimeSignature {
        TimeSignature.forStored(beats: exercise.beatsPerBar, noteValue: exercise.noteValue,
                                accentBeats: exercise.accentBeats)
    }

    private func bpmText(_ bpm: Int) -> some View {
        Text("\(bpm) BPM").font(.pocketMono(.body)).foregroundStyle(PocketColor.textPrimary)
    }
}
