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

    /// Fixed height of the bar region; the `<bpm> BPM` signpost sits in a reserved strip above it
    /// so it never clips the tallest bar.
    private static let barAreaHeight: CGFloat = 96
    private static let labelStripHeight: CGFloat = 15

    /// How bright a given bar reads: the live plateau is lit, its neighbours dim while running;
    /// in the stopped preview every bar sits at one even weight.
    private func fill(forIndex index: Int) -> Double {
        guard let currentIndex else { return 0.55 }
        return index == currentIndex ? 0.95 : 0.25
    }

    /// The **command dwell** plateau — the one that holds the longest, drawn as the widest bar.
    /// Signposted with its BPM so the anchor tempo is legible without reading the summary above.
    private var dwellIndex: Int? {
        guard !plateaus.isEmpty else { return nil }
        return plateaus.indices.max { plateaus[$0].intervals < plateaus[$1].intervals }
    }

    private static let chartHeight = barAreaHeight + labelStripHeight + 4

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let low = plateaus.map(\.bpm).min() ?? 0
                let high = plateaus.map(\.bpm).max() ?? 1
                let span = max(1, high - low)
                let totalIntervals = max(1, plateaus.reduce(0) { $0 + $1.intervals })
                let spacing: CGFloat = 4
                let usableWidth = geo.size.width - spacing * CGFloat(plateaus.count - 1)
                ZStack(alignment: .topLeading) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(plateaus.enumerated()), id: \.offset) { index, plateau in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(tint.opacity(fill(forIndex: index)))
                                .frame(width: usableWidth * CGFloat(plateau.intervals)
                                       / CGFloat(totalIntervals),
                                       height: Self.barAreaHeight * heightFraction(plateau.bpm, low, span))
                                .animation(.easeInOut(duration: 0.25), value: currentIndex)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    dwellLabel(low: low, span: span, usableWidth: usableWidth,
                               spacing: spacing, totalIntervals: totalIntervals)
                }
            }
            .frame(height: Self.chartHeight)
            HStack {
                Text("warm-up").font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
                Spacer()
                Text("dwell at command").font(.futura(.caption2, weight: .semibold)).foregroundStyle(tint)
                Spacer()
                Text("reach · back off").font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
            }
        }
    }

    private func heightFraction(_ bpm: Int, _ low: Int, _ span: Int) -> Double {
        0.3 + 0.7 * Double(bpm - low) / Double(span)
    }

    /// The `<bpm> BPM` signpost, centred over the dwell bar and dropped down to sit just above that
    /// bar's top edge. `.position` centres the label regardless of its own width, so a wide label can
    /// overhang a narrow bar without disturbing layout. The y is clamped into the reserved top strip
    /// so it never clips when the command bar is itself the tallest (a no-reach routine).
    @ViewBuilder
    private func dwellLabel(low: Int, span: Int, usableWidth: CGFloat, spacing: CGFloat,
                            totalIntervals: Int) -> some View {
        if let dwell = dwellIndex {
            let barTop = Self.chartHeight - Self.barAreaHeight * heightFraction(plateaus[dwell].bpm, low, span)
            let labelY = max(Self.labelStripHeight / 2, barTop - Self.labelStripHeight / 2 - 2)
            Text("\(plateaus[dwell].bpm) BPM")
                .font(.futura(.caption2, weight: .semibold))
                .foregroundStyle(tint)
                .fixedSize()
                .position(x: dwellCenterX(dwell, usableWidth: usableWidth, spacing: spacing,
                                          totalIntervals: totalIntervals),
                          y: labelY)
        }
    }

    /// The mid-x of the dwell bar, summing the widths + gaps of the bars before it.
    private func dwellCenterX(_ dwell: Int, usableWidth: CGFloat, spacing: CGFloat,
                              totalIntervals: Int) -> CGFloat {
        func width(_ index: Int) -> CGFloat {
            usableWidth * CGFloat(plateaus[index].intervals) / CGFloat(totalIntervals)
        }
        var leading: CGFloat = 0
        for index in 0..<dwell { leading += width(index) + spacing }
        return leading + width(dwell) / 2
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
