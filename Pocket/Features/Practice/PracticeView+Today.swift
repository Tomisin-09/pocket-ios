import SwiftUI

/// The hub's **Today's session** card (ADR 0257 D2): the planner's door, the long-term goals that
/// shape what it builds, and the session you started and didn't save.
extension PracticeView {

    /// The goals that shape a session: ranked, and not yet met. A met goal no longer pulls on what
    /// gets built (ADR 0015 S6), so it has no chip.
    var activeGoals: [LongTermGoal] {
        LongTermGoalStore.inRankOrder(longTermGoals).filter { !$0.isMet }
    }

    /// The temporary session the card offers a way back to (ADR 0243), or `nil`.
    var unsavedSession: Routine? {
        PracticeHubShelves.unsavedSession(routines, isTemporary: \.isTemporary,
                                          startedAt: { $0.lastPracticed ?? $0.dateAdded })
    }

    var todayCard: some View {
        VStack(spacing: 0) {
            plannerLink
            divider
            goalsBlock
            if let session = unsavedSession {
                divider
                unsavedLine(session)
            }
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(PocketColor.practiceCardWash))
    }

    private var divider: some View {
        Rectangle()
            .fill(PocketColor.textPrimary.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    /// The planner, as the row was: the label UI tests and the shoot look for starts `Today's session`.
    private var plannerLink: some View {
        NavigationLink { PlannerView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.futura(.title2))
                    .foregroundStyle(PocketColor.practice)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(PocketColor.practiceCircleWash))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today's session")
                        .font(.futura(.title3, weight: .bold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text("Choose how long you have")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(EdgeInsets(top: 18, leading: 16, bottom: 16, trailing: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's session")
        .accessibilityHint("Choose how long you have")
        .accessibilityAddTraits(.isButton)
    }

    /// The goals as chips (ADR 0257 D2). A chip opens that goal's editor; *Edit goals* opens the
    /// ranked list, which stays the only place that shows the order (ADR 0171 D6, as amended).
    private var goalsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Shaped by your goals")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                Spacer(minLength: 8)
                if !activeGoals.isEmpty || !longTermGoals.isEmpty {
                    NavigationLink { LongTermGoalListView() } label: {
                        Text("Edit goals")
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.practice)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    // The old row's label (D8): what opens, and what the shoot finds it by.
                    .accessibilityLabel("Long-term goals, \(longTermGoals.count)")
                }
            }
            FlowLayout(spacing: 8) {
                if activeGoals.isEmpty {
                    Button { addingGoal = true; haptic(.light) } label: {
                        GoalChip(title: "Add your first goal", isAdd: true)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(activeGoals, id: \.uid) { goal in
                    Button { editingGoal = StableRef(value: goal); haptic(.light) } label: {
                        GoalChip(title: goal.title.isEmpty ? "Untitled goal" : goal.title)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edits this goal")
                }
            }
        }
        .padding(EdgeInsets(top: 6, leading: 16, bottom: 14, trailing: 16))
    }

    /// The way back to the session you started and didn't save (ADR 0243 D4, "any time later"). It
    /// opens the session's own screen, where **Save** already is.
    private func unsavedLine(_ session: Routine) -> some View {
        let caption = PracticeHubShelves.unsavedCaption(
            minutes: PracticePlanner.estimatedMinutes(forRoutine: session),
            when: session.lastPracticed ?? session.dateAdded)
        return NavigationLink {
            RoutineDetailView(container: context.container, existing: session)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(PocketColor.practiceCircleWash))
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name.isEmpty ? "Unsaved session" : session.name)
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textPrimary)
                        .lineLimit(1)
                    Text(caption)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.futura(.caption, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the session, where you can save it")
    }
}
