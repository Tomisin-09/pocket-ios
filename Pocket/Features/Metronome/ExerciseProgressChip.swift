import SwiftUI

/// The loaded exercise's command-anchored summary on the metronome screen (ADR 0045): a slim
/// **command → reach** chip that is the entry point to **Training Mode**. Tapping it opens the
/// `TrainingModeSheet`, which owns the working/command/target editing, the promote, and the
/// **Start** that arms the routine — so the tempos and the ramp are no longer two disconnected
/// surfaces (the chip used to edit tempos while the separate automator panel had to be armed
/// by hand).
///
/// There is deliberately no progress *bar*: the reach is always a fixed step above command, so
/// a fraction would pin near-full and mislead. The real progress is the command number rising
/// over time — its history is ADR 0045 Phase 2. Reads the observable `@Model` directly, so a
/// promote or edit from the sheet re-renders this summary live.
struct ExerciseProgressChip: View {
    let exercise: MetronomeExercise
    /// Opens Training Mode (the screen owns the sheet presentation).
    let onTap: () -> Void

    private var command: Int { exercise.command }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.hasMeasuredCommand ? "COMMAND" : "SET COMMAND")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(PocketColor.textSecondary)
                    Text("\(command) BPM")
                        .font(.pocketMono(.title3))
                        .foregroundStyle(PocketColor.textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("REACH")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(PocketColor.textSecondary)
                    Text("\(exercise.derivedTarget) BPM")
                        .font(.pocketMono(.subheadline))
                        .foregroundStyle(PocketColor.metronome)
                        .contentTransition(.numericText())
                }
                Label("Train", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PocketColor.metronome)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.metronome.opacity(0.10)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Training Mode. Command \(command), reach \(exercise.derivedTarget) BPM")
        .accessibilityHint("Opens the training routine")
    }
}

#Preview("Promoted") {
    ExerciseProgressChip(exercise: MetronomeExercise(name: "Alternating picking",
                                                     currentTempo: 70, commandTempo: 92),
                         onTap: {})
        .padding()
}
