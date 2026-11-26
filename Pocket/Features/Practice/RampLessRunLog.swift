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
/// **The length is the time the loop sounded** (ADR 0321), read from the player, which counts its
/// own audio across every stop. Until ADR 0321 it was the time the screen was open, which is the length
/// ADR 0117 and ADR 0141 L7 had refused: leaving Red Moon doesn't close the screen, so a loop stopped in
/// the evening and the app left in the background logged 755 minutes when the sheet closed the next
/// morning, and a jam logged 290. Time on the screen with the loop stopped (reading, writing a note)
/// isn't counted; a slice played for Name the notes is.
///
/// **Leaving the screen is still the completion.** These modes have no ramp to run its course, so
/// there is no hand-stop to distinguish from a natural end (ADR 0104): the player deciding they're done
/// *is* the end of the run. A visit that never played the loop logs nothing, and
/// `PracticeLogWriter.minimumSeconds` drops a second's tap of ▶.
///
/// **No-op inside a routine — for the log.** There the routine player owns the completion seam — Done
/// and the planned length log and advance, while **skip and exit deliberately log nothing** — so the
/// block host takes the same sounded run itself and this modifier's write stands down. Passing the
/// `RoutineRunContext` through the core is what states which of the two seams is in force.
///
/// **No tempo is recorded**, matching both routine hosts: ear training isn't practised *at* a tempo,
/// and a jam's live percent is a comfort setting rather than an achievement.
struct RampLessRunLog: ViewModifier {
    /// What the run was — `.earLoop` or `.improvise`. Named by the host's mode, not by the unit.
    let kind: PracticeRunKind
    /// The loop that was practised. The row copies its `uid`, its song and its name (ADR 0241) when
    /// the run ends rather than when it starts, so a loop renamed mid-session logs under the new name.
    let loop: Loop
    /// What plays the loop, and so what counts how long it sounded.
    let player: ContinuousLoopPlayer
    /// The routine hosting this run, if any. Non-`nil` stands the write down.
    let routineContext: RoutineRunContext?

    @Environment(\.modelContext) private var modelContext

    private var isStandalone: Bool { routineContext == nil }

    func body(content: Content) -> some View {
        // An interruption needs nothing here: the engine pauses itself and the player stops with it
        // (ADR 0323), so the count stops because the audio did.
        content.onDisappear(perform: logSoundedRun)
    }

    private func logSoundedRun() {
        guard isStandalone, let run = player.takeSoundedRun() else { return }
        PracticeLogWriter.log(kind: kind,
                              startedAt: run.start,
                              endedAt: run.end,
                              unitUID: loop.uid,
                              songSourceID: loop.song?.sourceID,
                              unitLabel: loop.name,
                              into: modelContext)
    }
}

extension View {
    /// Log this ramp-less run when the screen goes away (ADR 0117), for the time `player` sounded
    /// (ADR 0321). Applied by `EarTrainingView` and `ImproviseView` so **every** host of those cores
    /// logs; the write is a no-op when `routineContext` is present, since a routine block logs at its own
    /// completion seam instead.
    func logsRampLessRun(kind: PracticeRunKind,
                         loop: Loop,
                         player: ContinuousLoopPlayer,
                         routineContext: RoutineRunContext?) -> some View {
        modifier(RampLessRunLog(kind: kind, loop: loop, player: player, routineContext: routineContext))
    }
}
