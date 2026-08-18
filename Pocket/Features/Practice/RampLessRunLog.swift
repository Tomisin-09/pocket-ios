import SwiftData
import SwiftUI

/// The practice-log clock for a **ramp-less run** — ear training (ADR 0104) and improvising
/// (ADR 0135) — written where the two modes' *shared core* lives rather than on each host.
///
/// **Why it sits on the core.** Both modes are one core view with several hosts: a sheet from the
/// loop settings, a pushed screen from the Loops library, and a routine block. The `PracticeLogWriter`
/// call originally lived in the routine host only, so the four standalone hosts silently logged
/// nothing — minutes and days quietly lost for every ear-training or improvise session started
/// outside a routine (found 2026-08-18). Putting the clock on the core is what makes a new host
/// inherit logging instead of having to remember it.
///
/// **Leaving the screen is the completion.** These modes have no ramp to run its course, so there is
/// no hand-stop to distinguish from a natural end (ADR 0104): the player deciding they're done *is*
/// the end of the run, exactly as `EarLoopRunView`'s Done button is inside a routine. The
/// `PracticeLogWriter.minimumSeconds` floor drops the merely-glanced-at.
///
/// **No-op inside a routine.** There the routine player owns the completion seam — Done and the
/// planned length log and advance, while **skip and exit deliberately log nothing** — so the block
/// host keeps its own writer call and this modifier stands down. Passing the `RoutineRunContext`
/// through the core is what states which of the two seams is in force.
///
/// **No tempo is recorded**, matching both routine hosts: ear training isn't practised *at* a tempo,
/// and a jam's live percent is a comfort setting rather than an achievement.
struct RampLessRunLog: ViewModifier {
    /// What the run was — `.earLoop` or `.improvise`. Named by the host's mode, not by the unit.
    let kind: PracticeRunKind
    /// The `uid` of the loop that was practised. A loose copy, as every log row's references are.
    let unitUID: UUID
    /// The routine hosting this run, if any. Non-`nil` disables the modifier entirely.
    let routineContext: RoutineRunContext?

    @Environment(\.modelContext) private var modelContext
    /// When the run began. Set on appearance rather than on a transport action — these screens have
    /// no Start, and the ear-training bed plays from arrival. Cleared once logged so the write can't
    /// fire twice.
    @State private var startedAt: Date?

    private var isStandalone: Bool { routineContext == nil }

    func body(content: Content) -> some View {
        content
            .onAppear { if isStandalone, startedAt == nil { startedAt = .now } }
            .onDisappear(perform: logCompletedRun)
    }

    private func logCompletedRun() {
        guard isStandalone, let startedAt else { return }
        self.startedAt = nil
        PracticeLogWriter.log(kind: kind,
                              startedAt: startedAt,
                              unitUID: unitUID,
                              into: modelContext)
    }
}

extension View {
    /// Log this ramp-less run when the screen goes away (ADR 0117). Applied by `EarTrainingView` and
    /// `ImproviseView` so **every** host of those cores logs; a no-op when `routineContext` is
    /// present, since a routine block logs at its own completion seam instead.
    func logsRampLessRun(kind: PracticeRunKind,
                         unitUID: UUID,
                         routineContext: RoutineRunContext?) -> some View {
        modifier(RampLessRunLog(kind: kind, unitUID: unitUID, routineContext: routineContext))
    }
}
