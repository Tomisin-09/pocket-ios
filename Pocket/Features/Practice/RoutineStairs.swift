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
    /// The **command** tempo — used to pin the BPM signpost to the dwell plateau by tempo, not by
    /// "which bar is widest" (which lands on the warm-up when the dwell is a single interval).
    let command: Int
    let tint: Color
    /// The plateau the run is currently on — lit while a training run plays. `nil` in the
    /// stopped setup preview, where every bar reads at one even weight (the dwell is conveyed by
    /// its width, not a permanent highlight).
    var currentIndex: Int?

    /// Fixed height of the bar region; the `<bpm> BPM` signpost sits in a reserved strip above it
    /// so it never clips the tallest bar.
    private static let barAreaHeight: CGFloat = 96
    private static let labelStripHeight: CGFloat = 15
    /// Height of the phase-caption row below the bars — a touch taller than the top signpost strip so
    /// descenders ("warm-up") don't clip.
    private static let captionHeight: CGFloat = 18

    /// How bright a given bar reads: the live plateau is lit, its neighbours dim while running;
    /// in the stopped preview every bar sits at one even weight.
    private func fill(forIndex index: Int) -> Double {
        guard let currentIndex else { return 0.55 }
        return index == currentIndex ? 0.95 : 0.25
    }

    /// The **command dwell** plateau — the one held *at command*, signposted with its BPM so the
    /// anchor tempo is legible without reading the summary above. Identified by tempo (`bpm ==
    /// command`, unique: the warm-up climbs *below* command, reach/backoff sit above/below it), so the
    /// signpost stays on the command bar even when the dwell is a single interval and so no longer the
    /// widest bar. Falls back to the widest bar if no plateau sits exactly at command (defensive).
    private var dwellIndex: Int? {
        guard !plateaus.isEmpty else { return nil }
        return plateaus.firstIndex { $0.bpm == command }
            ?? plateaus.indices.max { plateaus[$0].intervals < plateaus[$1].intervals }
    }

    /// The **summit** plateau — the highest-BPM bar, which splits the post-dwell tail into the
    /// *reach* (the climb from command up to and including this peak) and the *back off* (the descent
    /// after it). Unique by construction: the warm-up climbs below command, the reach climbs above,
    /// and the backoff steps back down, so the max BPM is the peak. Falls back to the dwell when the
    /// run has no summit above command (`target ≤ command`), which correctly leaves no *reach* group.
    private var summitIndex: Int? {
        guard !plateaus.isEmpty else { return nil }
        return plateaus.indices.max { plateaus[$0].bpm < plateaus[$1].bpm }
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
            captionRow
        }
    }

    /// The phase captions, each **centred under the bars it names** — `warm-up` over the climb, `dwell`
    /// over the command bar (sharing the BPM signpost's x), then `reach` over the ascent to the summit
    /// and `back off` over the descent as two **separate** labels (they name distinct phases, so they
    /// read clearer split than joined). Centring every caption on its own group (rather than an even
    /// split, which floated them off their unequal-width bars) keeps each lined up with its step. A
    /// caption is omitted when its phase has no bars — no warm-up climb, no reach above command, or no
    /// backoff tail.
    private var captionRow: some View {
        GeometryReader { geo in
            let totalIntervals = max(1, plateaus.reduce(0) { $0 + $1.intervals })
            let spacing: CGFloat = 4
            let usableWidth = geo.size.width - spacing * CGFloat(plateaus.count - 1)
            ZStack {
                if let dwell = dwellIndex {
                    let midY = geo.size.height / 2
                    let summit = summitIndex ?? dwell
                    if dwell > 0 {
                        caption("warm-up", PocketColor.textSecondary, weight: .regular)
                            .position(x: centerX(of: 0..<dwell, usableWidth: usableWidth,
                                                 spacing: spacing, totalIntervals: totalIntervals),
                                      y: midY)
                    }
                    caption("command", tint, weight: .semibold)
                        .position(x: centerX(of: dwell..<(dwell + 1), usableWidth: usableWidth,
                                             spacing: spacing, totalIntervals: totalIntervals),
                                  y: midY)
                    // reach: the climb above command through the summit (only when there is one)
                    if summit > dwell {
                        caption("reach", PocketColor.textSecondary, weight: .regular)
                            .position(x: centerX(of: (dwell + 1)..<(summit + 1), usableWidth: usableWidth,
                                                 spacing: spacing, totalIntervals: totalIntervals),
                                      y: midY)
                    }
                    // back off: the descent after the summit (only when there is a tail)
                    if summit < plateaus.count - 1 {
                        caption("back off", PocketColor.textSecondary, weight: .regular)
                            .position(x: centerX(of: (summit + 1)..<plateaus.count, usableWidth: usableWidth,
                                                 spacing: spacing, totalIntervals: totalIntervals),
                                      y: midY)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: Self.captionHeight)
    }

    private func caption(_ text: String, _ color: Color, weight: Font.Weight) -> some View {
        Text(text).font(.futura(.caption2, weight: weight)).foregroundStyle(color).fixedSize()
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
                .position(x: centerX(of: dwell..<(dwell + 1), usableWidth: usableWidth,
                                     spacing: spacing, totalIntervals: totalIntervals),
                          y: labelY)
        }
    }

    /// The mid-x of a **contiguous group** of bars (`range`) — the leading offset to the group plus
    /// half the group's own width. Used to centre each phase caption (and the single-bar BPM signpost)
    /// under the bars it names, so every label lines up with its step whatever the bar widths.
    private func centerX(of range: Range<Int>, usableWidth: CGFloat, spacing: CGFloat,
                         totalIntervals: Int) -> CGFloat {
        func width(_ index: Int) -> CGFloat {
            usableWidth * CGFloat(plateaus[index].intervals) / CGFloat(totalIntervals)
        }
        var leading: CGFloat = 0
        for index in 0..<range.lowerBound { leading += width(index) + spacing }
        var groupWidth: CGFloat = 0
        for index in range { groupWidth += width(index) }
        groupWidth += spacing * CGFloat(max(0, range.count - 1))
        return leading + groupWidth / 2
    }
}

#Preview("Routine stairs") {
    RoutineStairs(plateaus: CommandRamp(working: 70, command: 96, target: 110, stepBPM: 8,
                                        intervalCount: 4, unit: .bars, dwellIntervals: 4,
                                        includeBackoff: true).plateaus,
                  command: 96, tint: PocketColor.practice)
        .padding()
        .background(PocketColor.background)
}
