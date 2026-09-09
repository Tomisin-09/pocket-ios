import SwiftData
import SwiftUI

/// Home's **This week** strip (ADR 0196) — three numbers over the practice log: minutes, days, and
/// notes, all describing the same seven days.
///
/// It is the *promise* half of the two-tier design ADR 0117 drafted for Home and could not place —
/// and since **ADR 0208 it is also the door to the payoff**, which is the whole of that design
/// finally in one screen.
///
/// **ADR 0196 D3 wrote the condition this satisfies.** It left the strip deliberately inert, on the
/// reasoning that a tappable strip *"would reopen 0176's placement as a side effect of adding a
/// number, and settle by accident a decision that deserves to be taken deliberately."* ADR 0208 is
/// that decision taken deliberately; the Journal's *Practice log* row is deleted rather than kept,
/// because two doors to one screen is the thing ADR 0176 was tidying up.
///
/// **The door appears exactly when there is something behind it.** The strip already drew nothing
/// with no runs, so a fresh install gets no strip, no door, and no empty payoff screen — the
/// fresh-install objection this repo keeps re-hitting, answered by a guard that was already here.
///
/// **Its own view, with its own queries.** `HomeView` is close to SwiftLint's 400-line cap and holds
/// six `@Query`s already; two more for a strip it does not otherwise touch would be paid on every
/// Home redraw whether or not anything has been practised. Precedent: `TrialCountdownRow`, which
/// draws nothing until it has something to say.
///
/// **Three effort facts, never a grade (ADR 0070).** Minutes, days and notes are all things that
/// happened. `PracticeStatsCard`'s *Mastered* tile — a count of self-ratings at 5 — is the one this
/// strip refuses: a self-rating is not an achievement the app gets to total up, and a number that
/// only goes up next to two that can fall reads as a score. That card is deleted with this one; see
/// ADR 0196 D2. No goal, no denominator, no streak, no week-over-week delta — all four travel with
/// the deferred streak work (ADR 0117), and none of them are here.
struct HomeStatsStrip: View {
    /// Unfiltered and mapped in memory, like `PracticeLogView` — an optional `#Predicate` starves the
    /// main thread (`docs/swiftdata-gotchas.md`), and the windowing is pure by design anyway.
    @Query(sort: \PracticeRun.startedAt) private var runs: [PracticeRun]
    @Query private var journalEntries: [JournalEntry]

    var body: some View {
        // Nothing logged ⇒ no strip at all, rather than three zeroes. That is the objection recorded
        // against a home summary at `JournalTabView+PracticeLog.swift`: a fresh install would read a
        // row of nothing before it had read anything else. `runs.isEmpty` *is*
        // `PracticeProgress.Summary.hasNoHistory` — lifetime emptiness is run count — so this asks
        // the question without building the two horizons and the inventory it would need to ask it
        // through `summarize`.
        if !runs.isEmpty {
            let week = PracticeProgress.week(records: runs.map(\.record),
                                             now: .now, calendar: .current)
            // A `NavigationLink`, not a flag plus a `navigationDestination` on `HomeView`.
            // `PracticeLogView` takes no model, so none of ADR 0090's reasoning applies — that rule
            // is about a just-inserted `@Model` whose `persistentModelID` flips on first autosave and
            // pops an item-bound destination. A link here costs `HomeView` no state at all.
            NavigationLink {
                PracticeLogView()
            } label: {
                HomeSection(title: "This week", chevron: true) {
                    HStack(spacing: 10) {
                        tile(week.minutes, "Minutes")
                        tile(week.daysActive, "Days")
                        tile(PracticeLog.count(journalEntries.map(\.createdAt), in: week.interval),
                             "Notes")
                    }
                }
            }
            .buttonStyle(.plain)
            // **An identifier, and no label of its own.** The label is left to concatenate from the
            // header and the three tiles, so VoiceOver still hears the numbers — which are the point
            // of the strip. Naming the button "Practice log" for the harness's benefit would replace
            // all of that with a destination name. See `UITestHooks.practiceLogDoor`.
            .accessibilityIdentifier(UITestHooks.practiceLogDoor)
            .accessibilityHint("Opens the practice log")
        }
    }

    /// One stat tile — a big number over a plain-word label, on the standard surface the rest of
    /// Home's cards sit on. All three read in the primary text colour: none of them is the
    /// interesting one.
    private func tile(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.pocketMono(.title2).weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.surfaceStandard))
        .accessibilityElement(children: .combine)
        // Stated, not assembled: the shoot and the manual both name these, and a label built from
        // the children would change the moment the number's font or the label's case does.
        .accessibilityLabel("\(value) \(label) this week")
    }
}

#Preview("This week") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: PracticeRun.self, JournalEntry.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    for offset in [0, 1, 3] {
        container.mainContext.insert(
            PracticeRun(startedAt: .now.addingTimeInterval(Double(-offset) * 86_400),
                        durationSeconds: 900, kind: .exercise, unitUID: UUID()))
    }
    // In a `NavigationStack`, because the strip is a `NavigationLink` since ADR 0208 and a link with
    // no stack around it renders inert.
    return NavigationStack {
        HomeStatsStrip()
            .padding(20)
            .frame(maxWidth: .infinity)
    }
    .background(PocketColor.background)
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
