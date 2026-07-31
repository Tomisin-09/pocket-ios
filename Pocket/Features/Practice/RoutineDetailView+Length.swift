import SwiftUI

/// The generated-session **length readout + soft budget** (V2 planner R3), split out of
/// `RoutineDetailView` to keep that type under the body-length cap. Shows the estimated total
/// against the length the user asked the planner for — guidance only, never a gate.
extension RoutineDetailView {

    /// Total estimated minutes for the routine as it currently stands — ramp-staircase per exercise,
    /// region×repeats per loop, duration per song, each × the block's reps.
    var estimatedMinutes: Int { PracticePlanner.estimatedMinutes(forRoutine: routine) }

    /// A soft over/under-budget line vs. the requested length, or `nil` when there's no target (a
    /// normal routine, not a generated session). Never blocks anything — guidance only.
    /// Names the **preset** rather than quoting a minute budget, because the player never set one — a
    /// preset is a count of blocks now and the minutes are an estimate (ADR 0129). A freshly generated
    /// session is on-target by construction, so in practice this only speaks up once blocks have been
    /// added or removed on the review screen.
    var budgetHint: String? {
        guard let target = targetMinutes else { return nil }
        let asked = SessionLength(rawValue: target).map { "a \($0.displayName) session" }
            ?? "about \(target) min"
        switch SessionEstimate.fit(estimateMinutes: estimatedMinutes, targetMinutes: target) {
        case .under: return "Room to spare for \(asked). Add a goal for more."
        case .onTarget: return "About right for \(asked)."
        case .over: return "A touch over \(asked) — trim a block if you're short on time."
        }
    }

    /// The estimate + soft-budget readout, shown only on a provisional generated session that has
    /// something runnable. A saved routine has no target, so it isn't shown there.
    @ViewBuilder
    var lengthSection: some View {
        if !existsInStore && hasPlayableBlock {
            Section {
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
            } footer: {
                if let budgetHint {
                    Text(budgetHint)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        }
    }
}
