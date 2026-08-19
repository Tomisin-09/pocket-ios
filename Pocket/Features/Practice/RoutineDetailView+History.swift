import SwiftData
import SwiftUI

/// The routine's **length and history** section (ADR 0173), split out of `RoutineDetailView` to keep
/// that file under the 400-line cap.
///
/// **Why one section and not two.** The estimate and the history were near-complements: the old
/// `lengthSection` showed only on a routine that is *not* in the store, and a history can only exist
/// on one that *is*. Two sections would have meant the screen showed one of them and never both,
/// with the estimate — the single most useful thing to choose a routine by — hidden on precisely the
/// routines you would be choosing between. One section, and it says something true in every state:
///
/// | state | shows |
/// |---|---|
/// | provisional, something playable | estimated length + the soft budget hint (unchanged) |
/// | provisional, nothing playable | nothing — no history to have, and no length worth stating |
/// | saved, something playable | estimated length · last practised · how many times |
/// | saved, nothing playable | last practised · how many times (an all-rest or all-orphaned routine estimates at 0 min, and "~0 min" is a worse answer than no row) |
///
/// **A provisional routine shows no history on purpose.** It has a `uid`, so the read would succeed
/// and return zero — but zero here reports on something the player has not yet decided to keep, and
/// "Not yet" against a routine that does not exist reads as a reproach for not having done a thing
/// that was never offered.
///
/// Facts, never verdicts (design-brief §3.5, ADR 0070/0117). A count and a date are what the brief
/// names as permitted; there is no denominator, no week-over-week delta, no streak, and no word
/// anywhere for whether the number is a good one.
extension RoutineDetailView {

    @ViewBuilder
    var lengthAndHistorySection: some View {
        if existsInStore {
            Section {
                if hasPlayableBlock { estimatedLengthRow }
                RoutineHistoryRows(routineUID: routine.uid)
            }
        } else if hasPlayableBlock {
            Section {
                estimatedLengthRow
            } footer: {
                if let budgetHint {
                    Text(budgetHint)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        }
    }

    /// Lifted verbatim out of `+Length` so both states render the identical row rather than two rows
    /// that merely look alike.
    private var estimatedLengthRow: some View {
        HStack {
            Text("Estimated length")
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
            Spacer()
            Text("~\(estimatedMinutes) min")
                .font(.futura(.body, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .listRowBackground(PocketColor.background)
    }
}

/// The two facts the practice log remembers about one routine, as rows.
///
/// **It is a separate view owning its own `@Query`, for two reasons.** `RoutineDetailView` is at the
/// file-length cap and cannot take another stored property with the doc comment it would need. And
/// this is the one thing on this screen that must read the **app** context rather than the editing
/// sandbox: `@Query` resolves against the environment's context, which here is `appContext`, and
/// that is exactly where the practice log lives. It is the mirror image of the warning in
/// `RoutineDetailView+References`, where reading the app context *would* have been the bug.
///
/// It is handed a **`UUID`, not the `Routine`**, and that is what makes the above safe: a `uid` is a
/// value and is identical in both contexts, so nothing here can form a cross-context reference.
///
/// The whole log is fetched and filtered in memory. That is the house pattern (`PlannerView`,
/// `ExerciseDetailSheet`, `LongTermGoalEchoSection`) and it is not laziness: a `#Predicate` on the
/// optional `routineUID` is the documented way to starve the main thread
/// (`docs/swiftdata-gotchas.md`).
struct RoutineHistoryRows: View {
    let routineUID: UUID

    @Query(sort: \PracticeRun.startedAt) private var runs: [PracticeRun]

    private var history: PracticeLog.RoutineHistory {
        PracticeLog.routineHistory(for: routineUID, in: runs.map(\.record))
    }

    var body: some View {
        LabeledContent("Last practised") {
            Text(lastPractisedText)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .font(.futura(.body))
        .foregroundStyle(PocketColor.textPrimary)
        .listRowBackground(PocketColor.background)

        if let countLine {
            Text(countLine)
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .listRowBackground(PocketColor.background)
        }
    }

    /// "3 days ago", or **"Not yet"** — the neutral register `LongTermGoalEchoSection` established,
    /// whose own note says in as many words that it is not a reproach.
    private var lastPractisedText: String {
        guard let date = history.lastPracticed else { return "Not yet" }
        return date.formatted(.relative(presentation: .named))
    }

    /// How many sittings hold a run of this routine, or `nil` when there are none.
    ///
    /// Omitted entirely at zero rather than saying "Practised no times": "Not yet" in the row above
    /// has already said it, and a second sentence about a thing not done is the register the brief
    /// rules out.
    ///
    /// Note the deliberate meaning shift from `ExerciseProgressSection`'s identical wording — there
    /// "N times" counts *runs*, here it counts *sessions*, because one run of this routine writes one
    /// row per block. Both read to a player as "how many times you practised this thing", which is
    /// exactly why `PracticeLog.routineHistory` groups into sittings rather than counting rows.
    private var countLine: String? {
        switch history.sessionCount {
        case 0: return nil
        case 1: return "Practised once."
        default: return "Practised \(history.sessionCount) times."
        }
    }
}
