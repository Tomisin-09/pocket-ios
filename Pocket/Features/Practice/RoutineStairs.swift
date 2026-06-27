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
                    ForEach(Array(plateaus.enumerated()), id: \.offset) { _, plateau in
                        let heightFraction = 0.3 + 0.7 * Double(plateau.bpm - low) / Double(span)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(tint.opacity(plateau.intervals > 1 ? 0.9 : 0.55))
                            .frame(width: usableWidth * CGFloat(plateau.intervals)
                                   / CGFloat(totalIntervals),
                                   height: geo.size.height * heightFraction)
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
