import SwiftUI

/// A loop's span history in its edit sheet (ADR 0201) — reading back what ADR 0199 records.
///
/// **It has no cockpit surface, deliberately.** Recording a narrowing is a write, not chrome, and
/// the practice screen has no room to spare: the status line already holds Loop controls, Follow
/// and Grid, and the transport is full. This is a sheet with room, reached by the 0.4s hold that
/// every loop row already has — so the history costs the screen nothing and appears where the rest
/// of a loop's practice state already lives.
///
/// Each row carries the span **and** the speed, because the narrowing and the slowing are one
/// behaviour rather than two facts: *narrowed · 0.85×* is the sentence worth being able to read.
///
/// Nothing here is a verdict. It says what the span did and when — never whether that was good.
///
/// **It shows three, and grows only when asked** (ADR 0202 D5). The history has no end: a loop
/// worked on for a month accumulates a row per edit, and an unbounded list would push *Delete* —
/// and everything else in the sheet — a scroll away, for a log almost nobody reads past the top of.
/// The newest rows are the ones with anything to say, and the **Widen back** action stays outside
/// the fold, because an action buried under *Show all* is an action nobody finds.
struct LoopSpanSection: View {
    let loop: Loop
    /// Widen back to an earlier span — dismisses the sheet and lifts it as a live A/B span, so the
    /// wider loop is **auditioned before it is saved**, the same contract Adjust range has.
    let onWiden: (TimeInterval, TimeInterval) -> Void

    /// How many rows show before the list has to be asked for.
    private static let collapsedRowCount = 3

    @State private var showingAll = false

    private var changes: [LoopSpanChange] { loop.spanChangesByRecent }

    private var visibleChanges: [LoopSpanChange] {
        showingAll ? changes : Array(changes.prefix(Self.collapsedRowCount))
    }

    private var widenTarget: (start: Double, end: Double)? {
        SpanHistory.widenTarget(currentWidth: loop.end - loop.start,
                                previous: changes.map { (start: $0.previousStart, end: $0.previousEnd) })
    }

    var body: some View {
        if !changes.isEmpty {
            Section {
                ForEach(visibleChanges) { change in
                    row(change)
                }
                if changes.count > Self.collapsedRowCount {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showingAll.toggle() }
                    } label: {
                        Text(showingAll
                             ? "Show fewer"
                             : "Show all \(changes.count) changes")
                            .font(.futura(.footnote, weight: .medium))
                            .foregroundStyle(PocketColor.active)
                    }
                }
                if let target = widenTarget, let duration = loop.song?.duration, duration > 0 {
                    Button {
                        onWiden(target.start * duration, target.end * duration)
                    } label: {
                        Label("Widen back to \(timecode(target.start * duration))–\(timecode(target.end * duration))",
                              systemImage: "arrow.left.and.right")
                    }
                    .accessibilityHint("Try the wider loop. Nothing is saved until you save it")
                }
            } header: {
                Text("How it got here")
            } footer: {
                // Says what the list is, not how the player is doing.
                Text(changes.count > Self.collapsedRowCount && !showingAll
                     ? "The last \(Self.collapsedRowCount) times you changed this loop's range."
                     : "Every time you changed this loop's range.")
            }
        }
    }

    /// One recorded edit: when, the span it became, and what that did to it.
    private func row(_ change: LoopSpanChange) -> some View {
        let kind = SpanHistory.kind(fromStart: change.previousStart, end: change.previousEnd,
                                    toStart: change.start, end: change.end)
        let duration = change.songDuration ?? loop.song?.duration ?? 0
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(change.changedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 8)
                if duration > 0 {
                    Text("\(timecode(change.start * duration))–\(timecode(change.end * duration))")
                        .font(.pocketMono(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            HStack(spacing: 6) {
                Text(LoopSpanSection.label(for: kind))
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                if let speed = change.speed {
                    Text("· \(LoopSpanSection.speedLabel(speed))")
                        .font(.pocketMono(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Plain past-tense description. **`moved` is its own word**: a span that keeps its width and
    /// slides along the song is neither narrowed nor widened, and calling it either would state
    /// something that did not happen (ADR 0199 D4).
    static func label(for kind: SpanHistory.Kind) -> String {
        switch kind {
        case .narrowed: "Narrowed"
        case .widened: "Widened"
        case .moved: "Moved"
        }
    }

    /// The speed as the app writes it everywhere else — a `×` of the original.
    static func speedLabel(_ speed: Double) -> String {
        String(format: "%.2f×", speed)
    }
}
