import SwiftData
import SwiftUI

/// The planner's **read-only view of the standing goal list** (ADR 0171 D10).
///
/// It exists because the planner was quietly dishonest: it listed the short-term goals under a
/// heading, and Generate then also consulted a ranked list the player could not see from that
/// screen. Naming the two tiers in the `Build from` control fixes half of that; showing the
/// long-term list here fixes the rest, so the screen accounts for every input to the button.
///
/// **No controls, and that is deliberate.** Ranking, adding, editing and deleting live in
/// `LongTermGoalListView` and only there (ADR 0171 D6) — a second editable surface is how two lists
/// of the same thing start disagreeing. The one affordance is a way *to* that screen.
///
/// **Hidden entirely when `Build from` excludes it**, rather than dimmed. The first cut greyed it
/// out, reasoning that a section which vanishes teaches nothing about what was switched off — but
/// the labelled segmented control sits directly above and names the state, so the control is the
/// explanation and the greyed copy was only something to scroll past. The owner decides whether to
/// render this at all; by the time it appears, it is in use.
struct PlannerLongTermSection: View {
    let goals: [LongTermGoal]
    /// For a set's song count, which leaves out songs since deleted (ADR 0299).
    @Query private var songs: [Song]

    var body: some View {
        Section {
            ForEach(Array(goals.enumerated()), id: \.element.uid) { pair in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(pair.offset + 1)")
                        .font(.futura(.callout, weight: .bold))
                        .foregroundStyle(PocketColor.practice)
                        .frame(width: 20, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.element.displayTitle)
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                        Text(subtitle(for: pair.element))
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    Spacer(minLength: 8)
                }
                .listRowBackground(PocketColor.background)
                .accessibilityElement(children: .combine)
            }
            NavigationLink {
                LongTermGoalListView()
            } label: {
                Label("Edit long-term goals", systemImage: "arrow.up.arrow.down.circle")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.practice)
            }
            .listRowBackground(PocketColor.background)
        } header: {
            Text("Long-term goals")
        }
    }

    /// The same line the ranked list shows (`longTermGoalLine`).
    private func subtitle(for goal: LongTermGoal) -> String { longTermGoalLine(goal, songs: songs) }
}
