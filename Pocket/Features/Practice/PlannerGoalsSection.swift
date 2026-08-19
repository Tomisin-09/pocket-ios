import SwiftUI

/// The planner's **short-term goal list** — what you want out of *this* sitting (ADR 0171).
///
/// Extracted from `PlannerView` when the `Build from` control and the read-only long-term section
/// landed (ADR 0171 D10) and pushed that type's body past the 250-line lint ceiling. It takes
/// values and closures rather than the model context, so the owning screen keeps sole responsibility
/// for presenting sheets and mutating the store — the split is about the file, not about moving
/// behaviour somewhere harder to find.
struct PlannerGoalsSection: View {
    let activeGoals: [Goal]
    let metGoals: [Goal]
    /// Whether Generate will also follow the standing list — it changes what the empty state can
    /// honestly claim, since with a long-term goal standing the session is no longer due-only.
    let usesLongTerm: Bool
    let onAdd: () -> Void
    let onEdit: (Goal) -> Void
    /// Ask to clear every active goal. The owning screen confirms — this only reports the tap.
    let onClear: () -> Void
    let onDelete: (Goal) -> Void

    var body: some View {
        thisSessionSection
        if !metGoals.isEmpty { metSection }
    }

    var thisSessionSection: some View {
        Section {
            if activeGoals.isEmpty {
                // With a long-term goal standing, Generate is no longer due-only — saying so
                // would be false, and the player would wonder why their ranking did nothing.
                Text(usesLongTerm
                     ? "Nothing extra for today — Generate will follow your long-term goals. "
                       + "Add one here to steer this session in particular."
                     : "No goals yet — Generate builds a quick, due-based session from your "
                       + "exercises. Add a goal to steer what you practise.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(activeGoals) { goal in
                    goalRow(goal)
                }
            }
            Button(action: onAdd) {
                Label("Add a goal for this session", systemImage: "plus.circle.fill")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.practice)
            }
            .listRowBackground(PocketColor.background)
            // Only with something to clear. A permanently-present destructive row on a screen whose
            // ordinary state is one or two goals would be the loudest thing on it — and swiping a
            // single goal away is already the cheaper gesture. This earns its place when the list
            // has accumulated enough that clearing one at a time is the annoyance.
            if !activeGoals.isEmpty {
                Button(role: .destructive, action: onClear) {
                    Label("Clear this session's goals", systemImage: "xmark.circle")
                        .font(.futura(.body))
                        // `role: .destructive` reddens the *title* only; the glyph keeps the list's
                        // tint, so the row renders as red text beside a blue icon. Colour the whole
                        // label explicitly.
                        .foregroundStyle(PocketColor.danger)
                }
                .listRowBackground(PocketColor.background)
            }
        } header: {
            // "Goals" alone stopped being unambiguous when the long-term tier arrived
            // (ADR 0171 D8) — both tiers use the word, so the headers carry the distinction.
            Text("This session")
        }
    }

    var metSection: some View {
        Section("Met") {
            ForEach(metGoals) { goal in
                Button { onEdit(goal) } label: {
                    HStack {
                        Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textSecondary)
                            .strikethrough()
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(PocketColor.background)
                .swipeActions(edge: .trailing) { deleteAction(goal) }
            }
        }
    }

    func goalRow(_ goal: Goal) -> some View {
        Button { onEdit(goal) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(subtitle(for: goal))
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.practice)
                }
                Spacer(minLength: 8)
                Text(GoalPriority.nearest(toWeight: goal.weight).label.uppercased())
                    .font(.futura(.caption2, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(PocketColor.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(PocketColor.background)
        .swipeActions(edge: .trailing) { deleteAction(goal) }
    }

    /// Trailing swipe → remove a goal outright from this screen — no need to open the editor just to
    /// delete. Deleting a `Goal` nullifies its optional `targetSong` link (default to-one rule), so no
    /// song is touched; a met goal is removable the same way.
    func deleteAction(_ goal: Goal) -> some View {
        Button(role: .destructive) { onDelete(goal) } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    /// "3 skills · Little Wing" — the goal's shape at a glance; the target song appended when set.
    func subtitle(for goal: Goal) -> String {
        let count = goal.skillIDs.count
        var parts = ["\(count) skill\(count == 1 ? "" : "s")"]
        if let song = goal.targetSong, !song.title.isEmpty { parts.append(song.title) }
        return parts.joined(separator: " · ")
    }
}
