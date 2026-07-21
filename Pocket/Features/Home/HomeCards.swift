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
            Image(systemName: "chevron.right")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardWash))
    }
}

/// The "Jump back in" card: the song you last practised, with its mastery and when you last
/// touched it. Resumes the song (at its last-practiced tempo, ADR 0044) on tap. Neutral
/// chrome — the metronome card owns the screen's one accent colour.
struct JumpBackInCard: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("JUMP BACK IN")
                .font(.futura(.caption2, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(PocketColor.textSecondary)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.futura(.title3, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                        .lineLimit(1)
                    if !song.artist.isEmpty {
                        Text(song.artist)
                            .font(.futura(.subheadline))
                            .foregroundStyle(PocketColor.textSecondary)
                            .lineLimit(1)
                    }
                    if let practiced = song.lastPracticed {
                        Text("Last practised \(Self.relative(practiced))")
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                MasteryReadout(mastery: song.mastery)
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

    /// Playable blocks (rests excluded) — the "3 blocks" line, so the card previews the session's size.
    private var blockCount: Int {
        routine.orderedItems.filter { $0.kind != .rest && $0.hasResolvableUnit }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.futura(.title3))
                .foregroundStyle(PocketColor.practice)
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
        .accessibilityHint("Replays this routine")
    }

    /// "2 days ago" — a relative, human description of the last practice time.
    private static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
