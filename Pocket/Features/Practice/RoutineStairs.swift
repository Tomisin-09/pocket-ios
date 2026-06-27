import SwiftUI

/// A command-anchored routine drawn as a staircase: one bar per plateau, height ∝ BPM
/// (normalised across the routine's span) and **width ∝ how long it holds**, so the command
/// dwell reads as the wide bar and the backoff tail as the dip after the summit. A faithful
/// picture of what a run will play (ADR 0045/0046).
///
/// Shared between the Practice run screen (`ExerciseRunView`) and the legacy in-metronome
/// Training Mode sheet — extracted from the latter so it survives the Slice 4 dismantling and
/// has one home in the Practice feature.
struct RoutineStairs: View {
    let plateaus: [CommandRamp.Plateau]
    let tint: Color
    /// The plateau the run is currently on — lit while a training run plays. `nil` in the
    /// stopped setup preview, where every bar reads at one even weight (the dwell is conveyed by
    /// its width, not a permanent highlight).
    var currentIndex: Int?

    /// How bright a given bar reads: the live plateau is lit, its neighbours dim while running;
    /// in the stopped preview every bar sits at one even weight.
    private func fill(forIndex index: Int) -> Double {
        guard let currentIndex else { return 0.55 }
        return index == currentIndex ? 0.95 : 0.25
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let low = plateaus.map(\.bpm).min() ?? 0
                let high = plateaus.map(\.bpm).max() ?? 1
                let span = max(1, high - low)
                let totalIntervals = max(1, plateaus.reduce(0) { $0 + $1.intervals })
                let spacing: CGFloat = 4
                let usableWidth = geo.size.width - spacing * CGFloat(plateaus.count - 1)
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(plateaus.enumerated()), id: \.offset) { index, plateau in
                        let heightFraction = 0.3 + 0.7 * Double(plateau.bpm - low) / Double(span)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(tint.opacity(fill(forIndex: index)))
                            .frame(width: usableWidth * CGFloat(plateau.intervals)
                                   / CGFloat(totalIntervals),
                                   height: geo.size.height * heightFraction)
                            .animation(.easeInOut(duration: 0.25), value: currentIndex)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 96)
            HStack {
                Text("warm-up").font(.caption2).foregroundStyle(PocketColor.textSecondary)
                Spacer()
                Text("dwell at command").font(.caption2.weight(.semibold)).foregroundStyle(tint)
                Spacer()
                Text("reach · back off").font(.caption2).foregroundStyle(PocketColor.textSecondary)
            }
        }
    }
}

#Preview("Routine stairs") {
    RoutineStairs(plateaus: CommandRamp(working: 70, command: 96, target: 110, stepBPM: 8,
                                        intervalCount: 4, unit: .bars, dwellIntervals: 4,
                                        includeBackoff: true).plateaus,
                  tint: PocketColor.practice)
        .padding()
        .background(PocketColor.background)
}
