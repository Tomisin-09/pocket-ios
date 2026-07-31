import SwiftUI

/// The exercise detail sheet's **Progress** section (V2 planner Slice 1): a self-rated mastery
/// dot picker plus a read-only "last practised" readout. Split out of `ExerciseDetailSheet` to keep
/// that file under the 400-line cap, and standalone (not a `private` member) so it is independently
/// previewable.
///
/// Mastery is the self-assessment the planner reads as *need* (ADR 0070: you set it, the app never
/// measures how well you played). Mirrors the loop editor's dot control exactly.
struct ExerciseProgressSection: View {
    /// The edited mastery (0–5, `nil` = unrated), committed by the host sheet on Done.
    @Binding var mastery: Int?
    /// When the exercise was last practised — read-only, stamped by the run path.
    let lastPracticed: Date?
    /// This drill's own tempo history, read off the practice log (ADR 0117), or `nil` when there
    /// isn't one to draw yet. Passed in as a value so this view stays SwiftData-free and previewable.
    var trajectory: TempoTrajectory.Reading?
    /// How many times this drill has been run in total, at any tempo — the honest thing to say while
    /// there are too few points for a trajectory.
    var runCount: Int = 0

    var body: some View {
        Section {
            LabeledContent("Mastery") {
                HStack(spacing: 10) {
                    if mastery == nil {
                        Text("Unrated")
                            .font(.futura(.subheadline))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    ForEach(1...5, id: \.self) { value in
                        Circle()
                            .fill(value <= (mastery ?? 0) ? PocketColor.mastery : PocketColor.barDefault)
                            .frame(width: 18, height: 18)
                            .onTapGesture {
                                // Tap sets the value; tapping the lowest filled dot walks it down,
                                // below 1 clears back to unrated — always a deliberate rating.
                                mastery = (mastery == value) ? (value == 1 ? nil : value - 1) : value
                            }
                            .accessibilityLabel("Set mastery to \(value)")
                    }
                }
            }
            if let lastPracticed {
                LabeledContent("Last practised") {
                    Text(lastPracticed.formatted(.relative(presentation: .named)))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            if let trajectory {
                ExerciseTempoTrajectoryRow(reading: trajectory, runCount: runCount)
            } else if runCount > 0 {
                Text(firstRunsLine)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        } header: {
            Text("Progress")
        } footer: {
            Text("How cleanly you own this drill — you set it, the app never scores you. The planner "
                 + "resurfaces well-learned drills over time on its own.")
        }
    }

    /// What to say when the log has runs but not yet a trajectory — after one run, or when the only
    /// other runs were at a different rhythm and so can't share a line (ADR 0121). States the fact and
    /// what would extend it, without implying the player is behind.
    private var firstRunsLine: String {
        let runs = runCount == 1 ? "Practised once" : "Practised \(runCount) times"
        return "\(runs). A tempo trajectory appears once there are two finished runs at the same rhythm."
    }
}

/// The **tempo trajectory** readout (ADR 0117): where this drill started, where it is now, and the
/// shape between — read straight off the practice log.
///
/// Deliberately a *mirror*, not a verdict (ADR 0070). It states two facts and draws the line between
/// them; a line that goes down is drawn exactly as calmly as one that goes up, with no red, no arrow
/// and no word for it. The rhythm is always named beside the tempos, because a BPM without its note
/// rate is only half a fact (ADR 0121).
private struct ExerciseTempoTrajectoryRow: View {
    let reading: TempoTrajectory.Reading
    let runCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tempo")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 12)
                Text(tempoLine)
                    .font(.pocketMono(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Sparkline(values: reading.points.map(\.bpm))
                .frame(height: 28)
            Text(footnote)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary.opacity(0.8))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tempo trajectory. \(tempoLine). \(footnote)")
    }

    /// "76 → 104 BPM · 16ths" — first logged tempo to latest, with the rhythm they were measured in.
    private var tempoLine: String {
        let tempos = "\(reading.first.bpm) → \(reading.latest.bpm) BPM"
        guard let rate = reading.noteRate else { return tempos }
        return "\(tempos) · \(rate.compactLabel)"
    }

    /// The supporting line: how many runs the line covers and when it starts, plus an admission when
    /// runs at another rhythm were set aside — better to say the history is partial than to show a
    /// shorter one and let it read as the whole story.
    private var footnote: String {
        var text = "\(reading.points.count) runs since "
            + reading.first.date.formatted(.dateTime.day().month(.abbreviated))
        if reading.otherRhythmRuns > 0 {
            let others = reading.otherRhythmRuns == 1 ? "1 run" : "\(reading.otherRhythmRuns) runs"
            text += " · \(others) at another rhythm not shown"
        }
        return text
    }
}

/// A minimal line chart for a short series of tempos — no axes, no gridlines, no labels. It exists to
/// show the **shape**; the two numbers above it carry the values, so anything more would be decoration
/// competing with them. A flat series (every run at the same tempo) draws down the middle rather than
/// dividing by a zero range.
private struct Sparkline: View {
    let values: [Int]

    var body: some View {
        GeometryReader { geometry in
            let points = positions(in: geometry.size)
            ZStack {
                Path { path in
                    guard let start = points.first else { return }
                    path.move(to: start)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(PocketColor.practice, style: StrokeStyle(lineWidth: 2, lineCap: .round,
                                                                 lineJoin: .round))
                if let last = points.last {
                    Circle()
                        .fill(PocketColor.practice)
                        .frame(width: 6, height: 6)
                        .position(last)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func positions(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let lowest = values.min() ?? 0
        let highest = values.max() ?? 0
        let span = Double(highest - lowest)
        let inset = 3.0        // keeps the 6pt end dot inside the frame at either extreme
        let usable = max(0, size.height - inset * 2)
        let stride = size.width / Double(values.count - 1)
        return values.enumerated().map { index, value in
            // A flat line sits mid-height; otherwise low tempos sit low, so the line reads the way
            // the numbers do.
            let fraction = span == 0 ? 0.5 : Double(value - lowest) / span
            return CGPoint(x: Double(index) * stride, y: inset + usable * (1 - fraction))
        }
    }
}

#Preview("Progress — with a trajectory") {
    @Previewable @State var mastery: Int? = 3
    let day = 60.0 * 60 * 24
    let start = Date.now.addingTimeInterval(-day * 40)
    return Form {
        ExerciseProgressSection(
            mastery: $mastery,
            lastPracticed: .now.addingTimeInterval(-day),
            trajectory: TempoTrajectory.Reading(
                points: [76, 80, 78, 88, 92, 96, 104].enumerated().map { index, bpm in
                    TempoTrajectory.Point(date: start.addingTimeInterval(day * Double(index) * 6),
                                          bpm: bpm)
                },
                noteRate: .sixteenths,
                otherRhythmRuns: 2),
            runCount: 9)
    }
}

#Preview("Progress — one run so far") {
    @Previewable @State var mastery: Int?
    return Form {
        ExerciseProgressSection(mastery: $mastery, lastPracticed: .now, runCount: 1)
    }
}
