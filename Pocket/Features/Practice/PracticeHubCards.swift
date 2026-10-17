import SwiftUI

/// The pieces the **Practice hub's shelves** are built from (ADR 0257): a shelf's header, the tile a
/// category or a song is drawn as, the dashed tile that makes a new thing, a goal chip, and a routine
/// card. Each is a plain view taking plain values, so `PracticeView` decides *what* is on a shelf and
/// these decide only how one thing looks.

/// A shelf's title and its **All N ›** link to the whole library.
///
/// The link keeps the accessibility label the hub's old row had — `Routines, 11` — because the UI
/// tests and the manual's shoot find each library by it (D8), and because it says what opens.
struct ShelfHeader<Destination: View>: View {
    let title: String
    /// What the link reads: `All 11`, or `All` when there is nothing to count. `nil` draws no link.
    let linkText: String?
    let linkAccessibilityLabel: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.futura(.title3, weight: .bold))
                .foregroundStyle(PocketColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let linkText {
                NavigationLink(destination: destination) {
                    Text("\(linkText) ›")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.practice)
                        // A 44 pt target on a one-line link (design-brief: touch targets).
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(linkAccessibilityLabel)
            }
        }
        .padding(.horizontal, 16)
    }
}

/// One tile on the Exercises or Loops shelf: a glyph in its wash, a name, and a count.
struct ShelfTile: View {
    let icon: String
    let tint: Color
    let wash: Color
    let title: String
    let caption: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(wash))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(1)
                Text(caption)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: PracticeHubMetrics.tileWidth, alignment: .leading)
        .frame(minHeight: PracticeHubMetrics.tileHeight)
        .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.surfaceStandard))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

/// The dashed tile at the end of a shelf that makes a new thing: **New routine**, **New exercise**.
struct DashedNewTile: View {
    let title: String
    var width: CGFloat = PracticeHubMetrics.tileWidth
    var stacked = false

    var body: some View {
        Group {
            if stacked {
                VStack(spacing: 8) { glyph; label }
            } else {
                HStack(spacing: 10) { glyph.frame(width: 34); label; Spacer(minLength: 0) }
            }
        }
        .padding(12)
        .frame(width: width)
        .frame(minHeight: PracticeHubMetrics.tileHeight, maxHeight: .infinity)
        .foregroundStyle(PocketColor.practice)
        .background(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(PocketColor.practice.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var glyph: some View {
        Image(systemName: "plus").font(.futura(.title3, weight: .semibold))
    }

    private var label: some View {
        Text(title).font(.futura(.subheadline))
    }
}

/// One long-term goal on the Today's session card. A flag, never a score (ADR 0070).
struct GoalChip: View {
    let title: String
    var isAdd = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isAdd ? "plus" : "flag")
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
            Text(title)
                .font(.futura(.subheadline))
                .foregroundStyle(isAdd ? PocketColor.practice : PocketColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            if isAdd {
                Capsule().strokeBorder(PocketColor.practice.opacity(0.6),
                                       style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            } else {
                Capsule().fill(PocketColor.surfaceStandard)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Capsule())
    }
}

/// A routine on the Routines shelf (D3): a ▶ that starts it, and a body that opens it.
///
/// **Two sibling controls, never one inside the other.** The ▶ is a plain button and the body a
/// navigation link, side by side in one card, the shape the Routines library row already has.
struct RoutineShelfCard<Destination: View>: View {
    let name: String
    let isFavorite: Bool
    /// "4 blocks · 2 rests · ~8 min".
    let summary: String
    let line: PracticeHubShelves.RoutineCardLine
    let onPlay: () -> Void
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.futura(.largeTitle))
                        .foregroundStyle(PocketColor.practice)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, -6)
                .accessibilityLabel("Play \(name)")
                Spacer()
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.futura(.caption2))
                        .foregroundStyle(PocketColor.practice)
                        .accessibilityLabel("Favourite")
                }
            }
            NavigationLink(destination: destination) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                        .lineLimit(1)
                    Text(summary)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.practice)
                        .lineLimit(1)
                    thirdLine
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this routine")
        }
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 14, trailing: 14))
        .frame(width: PracticeHubMetrics.routineCardWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.surfaceStandard))
    }

    @ViewBuilder private var thirdLine: some View {
        switch line {
        case .nextReminder(let date):
            Label(PracticeReminderPlan.nextText(date), systemImage: "bell")
                .labelStyle(CompactLabelStyle())
        case .practised(let times, let last):
            if let text = PracticeHubShelves.historyLine(sessions: times, last: last) {
                Text(text).modifier(CardCaption())
            }
        case .nothing:
            EmptyView()
        }
    }
}

/// The grey third line of a routine card.
private struct CardCaption: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
            .lineLimit(1)
    }
}

/// A small glyph beside a caption, tighter than the system label.
private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
        .modifier(CardCaption())
    }
}

/// The hub's fixed sizes, in one place so the shelves and their tiles agree.
enum PracticeHubMetrics {
    /// Wide enough for "Chords & Strum" and a two-digit count beside a 34 pt glyph.
    static let tileWidth: CGFloat = 168
    static let tileHeight: CGFloat = 64
    /// A routine card is wider than a tile because it is a whole session (canvas note on B).
    static let routineCardWidth: CGFloat = 210
    static let newRoutineWidth: CGFloat = 120
    static let shelfSpacing: CGFloat = 10
}
