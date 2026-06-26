import SwiftUI

/// The loaded exercise's **light progress** on the metronome screen (ADR 0043, slice 7): a
/// slim current→target chip kept clear of the beat dots and the big tempo readout, which
/// taps open to steppers that **manually** edit the working tempo (nudged up across sessions)
/// and the target tempo (adjust the goal).
///
/// The bump is deliberately manual. With the automator sweeping to its ceiling every run,
/// playback can't tell you an *achieved* tempo (the live click always reaches the ceiling),
/// so you assert the new working tempo yourself — the ADR keeps the cross-session number
/// from being auto-rewritten.
///
/// Reads the exercise's `currentTempo`/`targetTempo` directly (it's an observable `@Model`),
/// so a nudge re-renders just this chip and persists through SwiftData autosave. The working
/// tempo here is **distinct** from the live click in the big readout — "where I practise",
/// not "what's sounding now".
struct ExerciseProgressChip: View {
    let exercise: MetronomeExercise
    @State private var expanded = false

    private var progress: ExerciseProgress { exercise.progress }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                header
            }
            .buttonStyle(.plain)

            if expanded { nudgeRow }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.metronome.opacity(0.10)))
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(progress.readout)
                    .font(.pocketMono(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer()
                if progress.isAtTarget {
                    Label("At target", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PocketColor.metronome)
                } else {
                    Text(progress.status)
                        .font(.caption)
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            TempoProgressBar(fraction: progress.fraction)
        }
        .contentShape(Rectangle())
    }

    private var nudgeRow: some View {
        VStack(spacing: 10) {
            tempoStepper(label: "Working tempo", value: exercise.currentTempo,
                         keyPath: \.currentTempo)
            tempoStepper(label: "Target tempo", value: exercise.targetTempo,
                         keyPath: \.targetTempo)
        }
        .transition(.opacity)
    }

    private func tempoStepper(label: String, value: Int,
                              keyPath: ReferenceWritableKeyPath<MetronomeExercise, Int>)
        -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(PocketColor.textSecondary)
            Spacer()
            stepButton(symbol: "minus", label: "Lower \(label)") { adjust(keyPath, by: -1) }
            Text("\(value)")
                .font(.pocketMono(.body))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(minWidth: 44)
                .contentTransition(.numericText())
            stepButton(symbol: "plus", label: "Raise \(label)") { adjust(keyPath, by: 1) }
        }
    }

    /// Edit a persisted tempo on the loaded exercise (working or target), clamped to the
    /// metronome's range. Mutating the `@Model` autosaves and re-renders the bar.
    private func adjust(_ keyPath: ReferenceWritableKeyPath<MetronomeExercise, Int>, by delta: Int) {
        let range = StandaloneMetronomeEngine.bpmRange
        exercise[keyPath: keyPath] = min(range.upperBound,
                                         max(range.lowerBound, exercise[keyPath: keyPath] + delta))
        haptic(.light)
    }

    private func stepButton(symbol: String, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(PocketColor.metronome.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
