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
    /// The unit the plateau tempos read in (ADR 0082) — `.bpm` for an exercise (the default),
    /// `.percent` for a loop, so the signpost reads "85%" not a mislabelled "85 BPM".
    var unit: TempoUnit = .bpm
    /// The plateau the run is currently on — lit while a training run plays. `nil` in the
    /// stopped setup preview, where every bar reads at one even weight (the dwell is conveyed by
    /// its width, not a permanent highlight).
    var currentIndex: Int?
    /// The plateau the ramp is **about to** move to, pre-lit while a tempo-change warning is showing
    /// (ADR 0131). `nil` the rest of the time, including at the end of the ramp where there is no next
    /// bar to light.
    var nextIndex: Int?
    /// The phase whose row is open in Practice Settings (ADR 0221 D1): its bars at full weight, the
    /// rest dimmed, its caption in the tint — what ties a control to the bars it changes. Ignored while
    /// a run plays, where the live cursor owns the lighting. `nil` reads as it always has.
    var highlightedPhase: RampPhase?
    /// The run's length, stated under the captions (ADR 0221 D10) — `≈ 1 min 5 s · 16 bars`. A total,
    /// not a countdown: the host passes the same string while the run plays. `nil` draws no line.
    var lengthLine: String?

    /// Fixed height of the bar region; the `<bpm> BPM` signpost sits in a reserved strip above it
    /// so it never clips the tallest bar.
    private static let barAreaHeight: CGFloat = 96
    private static let labelStripHeight: CGFloat = 15
    /// Height of the phase-caption row below the bars — a touch taller than the top signpost strip so
    /// descenders ("warm-up") don't clip.
    private static let captionHeight: CGFloat = 18

    /// How bright a given bar reads: the live plateau is lit, its neighbours dim while running;
    /// in the stopped preview every bar sits at one even weight. While a tempo-change warning is
    /// showing, the plateau being warned about pre-lights to a middle weight (ADR 0131) — brighter
    /// than dim so it reads as *coming*, dimmer than the cursor so it can't be mistaken for *here*.
    private func fill(forIndex index: Int) -> Double {
        guard let currentIndex else {
            guard let lit = litRange else { return 0.55 }
            return lit.contains(index) ? 0.95 : 0.22
        }
        if index == currentIndex { return 0.95 }
        return index == nextIndex ? 0.55 : 0.25
    }

    /// Which bars each phase drew — the one source for the captions and the open-row lighting.
    private var phaseRanges: [RampPhase: Range<Int>] {
        CommandRamp.phaseRanges(of: plateaus, command: command)
    }

    /// The bars an open row lights, while stopped — `nil` when no row is open, a run is playing, or the
    /// open phase drew nothing.
    private var litRange: Range<Int>? {
        guard currentIndex == nil, let highlightedPhase else { return nil }
        return phaseRanges[highlightedPhase]
    }

    /// The **command dwell** plateau — the one held *at command*, signposted with its BPM so the
    /// anchor tempo is legible without reading the summary above. Found by tempo, not by "which bar is
    /// widest" (see `CommandRamp.phaseRanges`), so the signpost stays on command even when the dwell
    /// is a single interval.
    private var dwellIndex: Int? { phaseRanges[.command]?.lowerBound }

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
            if let lengthLine {
                Text(lengthLine)
                    .font(.futura(.caption2))
                    .monospacedDigit()
                    .foregroundStyle(PocketColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Run length \(lengthLine)")
            }
        }
    }

    /// Narrowest group that still gets a caption. Below this the label would be unreadable however
    /// far it scaled down, so the phase goes unnamed rather than adding noise — the bars still show it.
    private static let minCaptionWidth: CGFloat = 26

    /// The phase captions, each **centred under the bars it names** — `warm-up` over the climb, `dwell`
    /// over the command bar (sharing the BPM signpost's x), then `reach` over the ascent to the summit
    /// and `back off` over the descent as two **separate** labels (they name distinct phases, so they
    /// read clearer split than joined). Centring every caption on its own group (rather than an even
    /// split, which floated them off their unequal-width bars) keeps each lined up with its step. A
    /// caption is omitted when its phase has no bars — no warm-up climb, no reach above command, or no
    /// backoff tail.
    ///
    /// Each label is **bounded by its own group's width** rather than sized to its text. Free-sized
    /// labels overlapped whenever one phase dominated the staircase: a fitted ramp gave the command
    /// plateau most of the width and printed "reach" and "back off" on top of each other. Constrained,
    /// two captions can abut but can never collide; a tight-but-legible one scales down, and one with
    /// no room at all (`minCaptionWidth`) is dropped.
    private var captionRow: some View {
        GeometryReader { geo in
            let totalIntervals = max(1, plateaus.reduce(0) { $0 + $1.intervals })
            let spacing: CGFloat = 4
            let usableWidth = geo.size.width - spacing * CGFloat(plateaus.count - 1)
            let metrics = CaptionMetrics(usableWidth: usableWidth, spacing: spacing,
                                         totalIntervals: totalIntervals, midY: geo.size.height / 2)
            ZStack {
                ForEach(RampPhase.allCases) { phase in
                    if let range = phaseRanges[phase] {
                        let style = captionStyle(for: phase)
                        caption(phase.caption, style.color, weight: style.weight, over: range,
                                metrics: metrics)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: Self.captionHeight)
    }

    /// How a phase's caption reads. With a row open, only that phase's is in the tint; otherwise
    /// command's is, as the anchor.
    private func captionStyle(for phase: RampPhase) -> (color: Color, weight: Font.Weight) {
        let lit = litRange != nil ? highlightedPhase == phase : phase == .command
        return lit ? (tint, .semibold) : (PocketColor.textSecondary, .regular)
    }

    /// The bar-layout figures every caption placement needs — grouped so each caption call site takes
    /// one parameter instead of three.
    private struct CaptionMetrics {
        let usableWidth: CGFloat
        let spacing: CGFloat
        let totalIntervals: Int
        /// Vertical centre of the caption row — the same for every label.
        let midY: CGFloat
    }

    /// One phase caption, centred on and bounded by the bars it names.
    @ViewBuilder
    private func caption(_ text: String, _ color: Color, weight: Font.Weight,
                         over range: Range<Int>, metrics: CaptionMetrics) -> some View {
        let width = groupWidth(of: range, metrics: metrics)
        if width >= Self.minCaptionWidth {
            Text(text)
                .font(.futura(.caption2, weight: weight))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: width)
                .position(x: centerX(of: range, usableWidth: metrics.usableWidth,
                                     spacing: metrics.spacing, totalIntervals: metrics.totalIntervals),
                          y: metrics.midY)
        }
    }

    /// The on-screen width of a contiguous group of bars, including the spacing between them.
    private func groupWidth(of range: Range<Int>, metrics: CaptionMetrics) -> CGFloat {
        let bars = range.reduce(CGFloat(0)) { total, index in
            total + metrics.usableWidth * CGFloat(plateaus[index].intervals)
                / CGFloat(metrics.totalIntervals)
        }
        return bars + metrics.spacing * CGFloat(max(0, range.count - 1))
    }

    /// A bar's height as a share of the bar area — 30% at the run's lowest tempo, full at its highest.
    /// A run that holds one tempo throughout (command only, ADR 0221 D2) has no span to scale against,
    /// so it draws at a fixed 62% rather than sitting on the 30% floor as if it were the slowest bar.
    private func heightFraction(_ bpm: Int, _ low: Int, _ span: Int) -> Double {
        guard plateaus.contains(where: { $0.bpm != low }) else { return 0.62 }
        return 0.3 + 0.7 * Double(bpm - low) / Double(span)
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
            Text(unit.signpost(plateaus[dwell].bpm))
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
    RoutineStairs(plateaus: CommandRamp(working: 70, command: 96, target: 110, warmupSteps: 2,
                                        intervalCount: 4, unit: .bars, dwellIntervals: 4,
                                        includeBackoff: true).plateaus,
                  command: 96, tint: PocketColor.practice)
        .padding()
        .background(PocketColor.background)
}
