import SwiftUI

/// The presentational cards for the home hub (`HomeView`), split out to keep the hub file under the
/// 400-line limit. Each is a small, self-contained view; the hub owns their data and navigation.

/// One titled **home section** (ADR 0102): an uppercase eyebrow header over a stack of nav strips. The
/// home's destinations used to sit in one flat run of same-weight, one-hue-each strips; once that hit
/// five it read as clutter and left no calm slot for a sixth (Red Moon Oracle). Grouping restores
/// hierarchy so new destinations join a *section* rather than becoming another peer strip. The header
/// carries the `.isHeader` trait so VoiceOver announces the grouping too. The owning strips (with their
/// `NavigationLink`s + accessibility labels) are passed in unchanged by the hub.
struct HomeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.futura(.caption, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PocketColor.textSecondary)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

/// One home **navigation strip** — the shared chrome behind the Song library / Metronome / Practice /
/// Toolkit rows: an accent glyph in a washed circle, a title + one-line subtitle, and a chevron, on a
/// washed rounded card. The four rows are visually identical bar their hue and copy, so they route
/// through this one component (each home card just supplies its icon/title/subtitle and its `PocketColor`
/// trio); the owning `NavigationLink`/`Button` and accessibility label stay in `HomeView`.
struct HomeNavCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let cardWash: Color
    let circleWash: Color
    /// Whether this destination is behind the Pro wall (ADR 0144 D4). Swaps the chevron for a lock,
    /// matching the "Start today's session" CTA's grammar: the card stays fully visible and reads as
    /// **inviting-but-locked**, never hidden and never broken. Defaults to `false` — the Toolkit and
    /// the Metronome never pass it.
    var locked: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.futura(.title2))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(circleWash))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(subtitle)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: locked ? "lock.fill" : "chevron.right")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardWash))
    }
}

/// The "Jump back in" card: the unit you last practised — a song, a routine or an exercise, per the
/// player's preference (ADR 0193) — with when you last touched it and a trailing readout. Resumes it
/// on tap; a song resumes at its last-practiced tempo (ADR 0044). Neutral chrome — the metronome card
/// owns the screen's one accent colour.
///
/// **The eyebrow does not vary.** `JUMP BACK IN` names the card's *job*, and a card that renamed
/// itself with its contents would read as three different cards that happen to share a slot. Only the
/// body changes shape.
struct JumpBackInCard: View {
    /// What the card is offering, flattened out of the model so the card draws a song, a routine and
    /// an exercise through one body rather than three branches. The hub owns the mapping; this view
    /// knows nothing about `Song`, and so has no opinion about where a tap goes.
    struct Content {
        let title: String
        /// The artist for a song, the family for an exercise; `nil` where there is nothing to say.
        let subtitle: String?
        let practiced: Date?
        let trailing: Trailing
    }

    /// The readout on the right. A routine has **no mastery** and never gains one (ADR 0070 keeps
    /// grades off practice), so it cannot borrow `MasteryReadout`'s `nil` — that renders an em dash
    /// meaning *unrated*, which for a routine would state something untrue rather than nothing.
    enum Trailing {
        /// A song or an exercise: its mastery out of five, or `nil` for genuinely unrated.
        case mastery(Int?)
        /// A routine: how many playable blocks it holds, the same figure `RecentRoutineCard` shows.
        case blocks(Int)
    }

    let content: Content
    /// Whether this card is behind the Pro wall (ADR 0144 D4). The card is a *second* door into the
    /// Song library's Pro surface and has always routed through `proGated(.song)`; the lock makes that
    /// visible, matching `HomeNavCard` and the recent-routines rail. Rides on the eyebrow rather than
    /// the content row, which already ends in `MasteryReadout`.
    var locked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("JUMP BACK IN")
                    .font(.futura(.caption2, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(PocketColor.textSecondary)
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.futura(.footnote, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        // Spoken, because an unlabelled glyph would leave VoiceOver describing an
                        // openable card.
                        .accessibilityLabel("Requires Red Moon Pro")
                }
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(content.title)
                        .font(.futura(.title3, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                        .lineLimit(1)
                    if let subtitle = content.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.futura(.subheadline))
                            .foregroundStyle(PocketColor.textSecondary)
                            .lineLimit(1)
                    }
                    if let practiced = content.practiced {
                        Text("Last practised \(Self.relative(practiced))")
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                switch content.trailing {
                case .mastery(let mastery):
                    MasteryReadout(mastery: mastery)
                case .blocks(let count):
                    Text("\(count) block\(count == 1 ? "" : "s")")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.surfaceStandard))
    }

    /// "2 days ago" — a relative, human description of the last practice time.
    private static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

/// One card in the home "Recent routines" rail: a practised routine's name, its block count, and how
/// long ago it was run. Tapping (handled by the rail) *replays* it exactly. Plum chrome — it's
/// practice content, kept clear of the blue library strip and the filled today's-session CTA.
struct RecentRoutineCard: View {
    let routine: Routine
    /// Whether this rail card is behind the Pro wall (ADR 0144 D4). Same grammar as `HomeNavCard`:
    /// the tile stays fully visible and reads as **inviting-but-locked**. The rail has always *been*
    /// gated — it routes through `proGated(.routine)` — but it drew no lock, so it was the one door
    /// on Home that looked open while it wasn't.
    var locked: Bool = false

    /// Playable blocks (rests excluded) — the "3 blocks" line, so the card previews the session's size.
    private var blockCount: Int {
        routine.orderedItems.filter { $0.kind != .rest && $0.hasResolvableUnit }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The lock sits opposite the glyph on the top row, where `HomeNavCard` puts it — trailing,
            // secondary, replacing nothing the tile needs.
            HStack(alignment: .top, spacing: 0) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.futura(.title3))
                    .foregroundStyle(PocketColor.practice)
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.futura(.footnote, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            Text(routine.name.isEmpty ? "Routine" : routine.name)
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Text("\(blockCount) block\(blockCount == 1 ? "" : "s")")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
            if let practiced = routine.lastPracticed {
                Text(Self.relative(practiced))
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .padding(14)
        .frame(width: 150, height: 132, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practiceCardWash))
        .accessibilityElement(children: .combine)
        // `.combine` swallows the lock glyph (it carries no label of its own), so the locked state
        // has to be spoken here or VoiceOver would announce an ordinary, openable tile.
        .accessibilityHint(locked ? "Requires Red Moon Pro" : "Replays this routine")
    }

    /// "2 days ago" — a relative, human description of the last practice time.
    private static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

/// The three shapes one card takes (ADR 0193), side by side — the check the build cannot make:
/// that a routine's block count and an exercise's command line sit where a song's artist and mastery
/// do, and that the fixed eyebrow still reads as one card rather than three.
#Preview("Jump back in — three shapes") {
    VStack(spacing: 16) {
        JumpBackInCard(content: .init(title: "Slow Bend", subtitle: "Jack Trader",
                                      practiced: .now.addingTimeInterval(-3600),
                                      trailing: .mastery(3)))
        JumpBackInCard(content: .init(title: "Evening warm-up", subtitle: nil,
                                      practiced: .now.addingTimeInterval(-86_400),
                                      trailing: .blocks(4)))
        JumpBackInCard(content: .init(title: "Minor pentatonic, position 1",
                                      subtitle: "Command 90 → 120 BPM · 8ths",
                                      practiced: .now.addingTimeInterval(-172_800),
                                      trailing: .mastery(nil)), locked: true)
    }
    .padding(20)
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
