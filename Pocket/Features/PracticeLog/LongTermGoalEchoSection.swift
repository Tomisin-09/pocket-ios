import SwiftData
import SwiftUI

/// The **read-only echo** of the long-term goal list on Progress (ADR 0171 D6/D7) — what pairs the
/// goals with the practice that has accumulated against them.
///
/// **It carries no controls, and that is what makes it legal here.** ADR 0117 rejected reaching
/// Progress from the Practice space with *"Practice is where you do the work; Journal is where you
/// read back what you did"*, and `JournalTabView` puts Progress and the timeline behind one door
/// because *"both are read-only practice history"*. So: no add, no reorder, no edit, no swipe, no
/// tap-through. The editable list lives in Practice and only in Practice.
///
/// **What it shows is a fact, not a score** (ADR 0070). The ranked title, a skill **count**, and
/// when something serving the goal was last practised. Never *"3 of 5 skills covered"*, a
/// percentage, a bar, an ETA or a "behind" state — `PracticeLog` states the reason plainly:
/// *"a denominator states a target, and a target is habit-pressure under another name."* The
/// register is the milestone wall's: a wall you pass, not a ladder you're being timed on.
///
/// Its own view, with its own queries, rather than an extension on `PracticeLogView` — that
/// screen is already near the file-length cap, and the attribution here needs the song library and
/// the goal list, which nothing else on Progress reads.
struct LongTermGoalEchoSection: View {
    @Query private var goals: [LongTermGoal]
    @Query(sort: \PracticeRun.startedAt) private var runs: [PracticeRun]
    @Query private var exercises: [Exercise]
    @Query private var loops: [Loop]
    @Query private var songs: [Song]

    private var ranked: [LongTermGoal] {
        LongTermGoalStore.inRankOrder(goals).filter { !$0.isMet }
    }

    private var met: [LongTermGoal] {
        LongTermGoalStore.inRankOrder(goals).filter(\.isMet)
    }

    /// Readings keyed by goal, from the deriver itself rather than a second skill → unit walk
    /// (ADR 0171 D7) — so this screen attributes exactly what the planner would schedule.
    private var readings: [UUID: LongTermGoalReading] {
        let recency = PracticeLog.lastPracticedByUnit(runs.map(\.record))
        let library = PracticePlanner.library(exercises: exercises, loops: loops, songs: songs,
                                              lastPracticed: recency)
        let values = LongTermGoalEcho.readings(for: ranked.map(\.plannerProjection), library: library)
        return Dictionary(uniqueKeysWithValues: values.map { ($0.goalUID, $0) })
    }

    var body: some View {
        if !goals.isEmpty {
            HomeSection(title: "Long-term goals") {
                let readings = readings
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(ranked.enumerated()), id: \.element.uid) { pair in
                        goalLine(pair.element, rank: pair.offset + 1, reading: readings[pair.element.uid])
                    }
                    if !met.isEmpty { metLines }
                }
            }
        }
    }

    private func goalLine(_ goal: LongTermGoal, rank: Int, reading: LongTermGoalReading?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(rank)")
                .font(.pocketMono(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .frame(width: 14, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(factLine(for: goal, reading: reading))
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Skills, then when something serving this goal was last practised. **"Not yet" is the honest
    /// answer and it is not a reproach** — it is the same neutral register an unreached hour
    /// milestone uses. Nothing here says *by when*.
    private func factLine(for goal: LongTermGoal, reading: LongTermGoalReading?) -> String {
        let count = reading?.skillCount ?? goal.skillIDs.count
        let skills = count == 1 ? "1 skill" : "\(count) skills"
        guard let served = reading?.lastServed else { return "\(skills) · not yet" }
        return "\(skills) · last practised \(served.formatted(.relative(presentation: .named)))"
    }

    /// Met goals, listed without facts — a met goal derives nothing, so a recency line would read
    /// "not yet" about something the player has declared finished.
    private var metLines: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(met, id: \.uid) { goal in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.practice)
                    Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(goal.title), met")
            }
        }
        .padding(.top, 2)
    }
}
