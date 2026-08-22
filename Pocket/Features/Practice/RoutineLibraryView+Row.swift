import SwiftUI

/// The **row rendering** for `RoutineLibraryView` — the ▶/body split, the entitlement affordances
/// and the two caption lines — split out when the library gained search and sort (ADR 0178) and the
/// view reached the 400-line cap.
///
/// The division is deliberate rather than arbitrary: what is left in `RoutineLibraryView` decides
/// *which* routines are on screen and *in what order*; this file decides what one of them looks
/// like. The members are internal only because a same-module extension cannot see `private`.
extension RoutineLibraryView {

    /// A routine row — a ▶ that plays the session, then a tappable name + one-line block summary
    /// that opens the editor. Two independent plain buttons so the two actions never collide.
    ///
    /// Entitlement-aware (ADR 0112), and the two halves gate **differently**: ▶ asks `canRunRoutine`
    /// (so the curated free-taste routine plays for a free player) while the body asks
    /// `canAuthorRoutine` (so that same routine still can't be *edited* — run the freebie, don't
    /// author it, exactly as the free-taste exercises behave). A routine a free player can neither run
    /// nor edit stays **visible but badged** — "locked, not hidden".
    func row(for routine: Routine, facts: RoutineListFacts) -> some View {
        let isDemo = AccessPolicy.isFreeTasteRoutine(slug: routine.presetSlug)
        let runnable = AccessPolicy.canRunRoutine(isPro: isPro, isFreeTasteRoutine: isDemo)
        return HStack(spacing: 14) {
            Button { play(routine) } label: {
                Image(systemName: runnable ? "play.circle.fill" : "lock.circle.fill")
                    .font(.futura(.title2))
                    .foregroundStyle(runnable ? PocketColor.practice : PocketColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(runnable
                                ? "Play \(routine.name.isEmpty ? "routine" : routine.name)"
                                : "Locked — Red Moon Pro")

            Button { edit(routine) } label: {
                rowBody(for: routine, openable: runnable, facts: facts)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    /// The tappable half of a row: name (+ favourite star), block summary, the routine's estimated
    /// length, and the trailing entitlement affordances.
    ///
    /// **The length is trailing and right-aligned, not appended to the caption** (ADR 0178). Sorting
    /// by a fact the list does not show is a sort you cannot check, and a right-aligned column of
    /// numbers can be *scanned* — inside `8 blocks · 3 rests · ~12 min` it would have to be hunted
    /// for on every row, and ADR 0173 had already warned against growing that first caption. `openable` means the row leads somewhere for this player — true for
    /// any routine when Pro, and for the curated demo when free. The PRO capsule and the padlock both
    /// mark the rows that don't, so the demo reads as ordinary and the rest read as locked.
    func rowBody(for routine: Routine, openable: Bool, facts: RoutineListFacts) -> some View {
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
                Text(summary(for: routine))
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.practice)
                if let line = self.history(for: routine, facts: facts) {
                    Text(line)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            Spacer(minLength: 8)
            // The length **stands down for the PRO badge** rather than sitting beside it. Both want
            // the same trailing slot, and three trailing elements plus a chevron is a crowded row —
            // but the deciding argument is that they answer different questions: how long a routine
            // takes is not what you are weighing up about one you cannot run.
            if openable, let minutes = facts.minutes[routine.uid], minutes > 0 {
                Text("~\(minutes) min")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .accessibilityLabel("About \(minutes) minutes")
            }
            if !openable { proBadge }
            Image(systemName: openable ? "chevron.right" : "lock.fill")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .contentShape(Rectangle())
    }

    /// The "PRO" capsule marking a routine a free player cannot run (ADR 0112). Matches the exercise
    /// library's badge, and is deliberately absent from the curated free-taste routine, which plays.
    var proBadge: some View {
        Text("PRO")
            .font(.futura(.caption2, weight: .bold))
            .foregroundStyle(PocketColor.background)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(PocketColor.practice))
    }

    /// "3 blocks · 1 rest" — what is *in* the routine; "Empty" before any blocks.
    ///
    /// **Blocks, not units.** The detail screen's own section header says `Blocks` and the model
    /// calls them blocks; this row was the only surface calling them units, which left the two
    /// screens disagreeing about what the things in a routine are.
    ///
    /// **Not "exercise blocks"**, which was tried and rejected the same day: `kind.carriesUnit` is
    /// true for a loop and a song block as well as an exercise one (ADR 0129/0134), so a routine of
    /// two loops and a song would have read "3 exercise blocks". "Blocks" is true of all three.
    func summary(for routine: Routine) -> String {
        let items = routine.items
        guard !items.isEmpty else { return "Empty" }
        let blocks = items.filter(\.kind.carriesUnit).count
        let rests = items.count - blocks
        var parts = ["\(blocks) block\(blocks == 1 ? "" : "s")"]
        if rests > 0 { parts.append("\(rests) rest\(rests == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
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
