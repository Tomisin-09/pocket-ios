import SwiftUI

/// **The card at the top of the feed** (ADR 0207 D8) — one entry from a year ago, quoted, with the
/// day it was written.
///
/// ### Why this is the answer to "nothing makes me want to write the next one"
///
/// Every conventional lever here is refused: no streak, no count, no badge, no heatmap, no
/// auto-highlighting of a *good* entry. What is left is the thing a journal is actually for — being
/// ambushed by your own past. The reward for writing is that the app hands it back to you, unasked,
/// a year later. That is a reason to write which never once grades the writing.
///
/// ### Why it is not the strip ADR 0176 refused
///
/// That refusal was specific: a summary strip *"puts a permanent number above a timeline whose entire
/// content is words"* and hands a fresh install a zero to read. This carries **words**, which is what
/// the screen is for; it is **not permanent** — it lives inside the `List` and scrolls away with
/// everything else; and it is **absent entirely** when there is nothing to show, the same rule
/// `HomeStatsStrip` follows for a week with no runs.
///
/// The quoting treatment is the Oracle's own (`QuotedNoteView`), in gold rather than crimson.
struct JournalLookbackCard: View {

    /// "A year ago today" / "…this week" / "…this month" — the rung the ladder actually reached, so
    /// the card never claims a precision it does not have.
    let heading: String
    let text: String
    /// The entry's owner caption, or `nil` for a standalone note that never had one.
    let ownerLabel: String?
    let day: Date
    /// Scrolls the feed to `day`. The whole card is the target.
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                Text(heading.uppercased())
                    .font(.futura(.caption2, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(PocketColor.journal)
                QuotedNoteView(text: text, tint: PocketColor.journal)
                HStack(spacing: 4) {
                    Text(footnote)
                        .font(.futura(.caption))
                        .lineLimit(1)
                    Image(systemName: "chevron.forward")
                        .font(.futura(.caption2, weight: .semibold))
                }
                .foregroundStyle(PocketColor.journal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 14).fill(PocketColor.journalCardWash)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(heading). \(text). \(footnote)")
        .accessibilityHint("Scrolls the journal to that day")
    }

    /// "Slow Bend · Verse riff · 8 Sep 2025", or just the date for a note that belongs to nothing.
    private var footnote: String {
        let date = day.formatted(date: .abbreviated, time: .omitted)
        guard let ownerLabel, !ownerLabel.isEmpty else { return date }
        return "\(ownerLabel) · \(date)"
    }
}

#Preview("Look-back card") {
    VStack(spacing: 16) {
        JournalLookbackCard(
            heading: "A year ago today",
            text: "Can't get past bar 9 at any tempo. Might be the wrong fingering entirely.",
            ownerLabel: "Slow Bend · Verse riff",
            day: Date(timeIntervalSinceNow: -365 * 86_400),
            onOpen: {})
        // The widened rung, and a note with no owner — the two cases the footnote has to survive.
        JournalLookbackCard(
            heading: "A year ago this month",
            text: "Nothing is working today. Putting it down.",
            ownerLabel: nil,
            day: Date(timeIntervalSinceNow: -380 * 86_400),
            onOpen: {})
    }
    .padding(20)
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
