import SwiftUI

/// The **row rendering** for `RoutineLibraryView` — the ▶/body split and the two caption lines — split out when the library gained search and sort (ADR 0178) and the
/// view reached the 400-line cap.
///
/// The division is deliberate rather than arbitrary: what is left in `RoutineLibraryView` decides
/// *which* routines are on screen and *in what order*; this file decides what one of them looks
/// like. The members are internal only because a same-module extension cannot see `private`.
extension RoutineLibraryView {

    /// A routine row — a ▶ that plays the session, then a tappable name + one-line block summary
    /// that opens the editor. Two independent plain buttons so the two actions never collide.
    func row(for routine: Routine, facts: RoutineListFacts) -> some View {
        HStack(spacing: 14) {
            Button { play(routine) } label: {
                Image(systemName: "play.circle.fill")
                    .font(.futura(.title2))
                    .foregroundStyle(PocketColor.practice)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(routine.name.isEmpty ? "routine" : routine.name)")

            Button { edit(routine) } label: {
                rowBody(for: routine, facts: facts)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    /// The tappable half of a row: name (+ favourite star), block summary, the routine's estimated
    /// length, and a chevron.
    ///
    /// **The length is trailing and right-aligned, not appended to the caption** (ADR 0178). Sorting
    /// by a fact the list does not show is a sort you cannot check, and a right-aligned column of
    /// numbers can be *scanned* — inside `8 blocks · 3 rests · ~12 min` it would have to be hunted
    /// for on every row, and ADR 0173 had already warned against growing that first caption.
    func rowBody(for routine: Routine, facts: RoutineListFacts) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(routine.name.isEmpty ? "Untitled routine" : routine.name)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    if routine.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.futura(.caption2))
                            .foregroundStyle(PocketColor.practice)
                            .accessibilityLabel("Favourite")
                    }
                }
                Text(routine.blockSummary)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.practice)
                if let line = self.history(for: routine, facts: facts) {
                    Text(line)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            Spacer(minLength: 8)
            if let minutes = facts.minutes[routine.uid], minutes > 0 {
                Text("~\(minutes) min")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .accessibilityLabel("About \(minutes) minutes")
            }
            Image(systemName: "chevron.right")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .contentShape(Rectangle())
    }

    /// "Practised 11 times · 3 days ago" — what the routine has *come to*, or `nil` when it has
    /// never been run (ADR 0173 D6).
    ///
    /// A second line rather than more of the first: the two answer different questions, and four
    /// facts on one caption wrap to three lines on a long name at a large text size.
    ///
    /// **A routine with no runs returns `nil` rather than "Not yet."** The detail screen has room to
    /// say that kindly beside a date; a list does not, and thirty rows each announcing a thing not
    /// done reads as a nag however neutral the words are (design-brief §3.5).
    func history(for routine: Routine, facts: RoutineListFacts) -> String? {
        guard let sessions = facts.counts[routine.uid], sessions > 0 else { return nil }
        var parts = [sessions == 1 ? "Practised once" : "Practised \(sessions) times"]
        if let last = facts.dates[routine.uid] {
            parts.append(last.formatted(.relative(presentation: .named)))
        }
        return parts.joined(separator: " · ")
    }
}
