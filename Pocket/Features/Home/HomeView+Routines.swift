import SwiftData
import SwiftUI

/// Home's **routine** surfaces, split out of `HomeView` to keep that file under the 400-line cap:
/// the recent-routines rail, and — since ADR 0186 — the two things Home does for practice reminders
/// that nowhere else can.
///
/// **Why the reminder work is here and not in `PracticeReminder`.** Both jobs need to turn a `uid`
/// into a routine, which needs a `ModelContext`. `PracticeReminder` is deliberately given only
/// `uid`s: it schedules and cancels, and knows nothing about the store. Home is the first screen in
/// the app and already owns the container, so it is where the two meet.
extension HomeView {

    /// The last few routines you actually **practised** (newest first). A tap **reopens the routine's
    /// detail** (`RoutineDetailView` — blocks + Edit + Start), rather than replaying it straight into
    /// the player, so you can glance at the blocks or tweak before starting (device feedback
    /// 2026-07-11; supersedes ADR 0066's one-tap replay *from home* — the library ▶ still replays
    /// directly). Reads `Routine.lastPracticed` (stamped on run); never-run routines don't appear.
    var recentRoutinesRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent routines")
                .font(.futura(.title3, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentRoutines) { routine in
                        // Gated for the same reason as "Jump back in" — a rail card is another door
                        // into a Pro surface (ADR 0144 D4).
                        proGated(.routine) {
                            RoutineDetailView(container: context.container, existing: routine)
                        } label: {
                            RecentRoutineCard(routine: routine, locked: !isPro)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Reminders (ADR 0186)

    /// Where a tapped reminder lands (D6).
    ///
    /// **Not wrapped in `proGated`**, unlike the rail card above, and the difference is deliberate:
    /// the player set this appointment themselves, and answering it with a paywall would be the app
    /// using a reminder they asked for as a sales surface. The routine screen carries the same Pro
    /// gates it always has, so nothing is unlocked by arriving this way — only the door is the one
    /// they knocked on.
    @ViewBuilder
    var openedRoutineDestination: some View {
        if let routine = openingRoutine {
            RoutineDetailView(container: context.container, existing: routine)
        }
    }

    /// Resolve a pending reminder tap into a routine and push it.
    ///
    /// Called from both `onChange` (a tap while the app is running) and `onAppear` (a **cold**
    /// launch, where the delegate is handed the tap before any view exists) — one path, so the
    /// launch case cannot be the one that was never tested.
    ///
    /// **The uid is consumed whether or not it resolves.** An unresolved uid means the routine is
    /// gone: Home simply opens and says nothing, which is D3's failure mode after the sweep has been
    /// missed, and D6 requires it to degrade quietly rather than trap. Leaving it unconsumed would
    /// retry the same dead lookup on every appear.
    func openRoutineFromReminder() {
        guard let uid = notificationRouter.consumeRoutineUID() else { return }
        let all = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        openingRoutine = all.first { $0.uid == uid }
    }

    /// The launch sweep (D3): drop every pending reminder whose routine no longer exists.
    ///
    /// The delete path cancels too, and that is the version which looks correct in review and fails
    /// on a path nobody listed — a cascade delete, a Pro-lapse sweep, a future bulk action. This one
    /// asks the *system* what it is still holding, which is the only source of truth about a request
    /// that has already left the app.
    ///
    /// **A failed fetch does nothing, rather than sweeping.** `reconcile` takes the set of live
    /// routines and cancels everything outside it, so an empty result from a store that simply
    /// failed to read would cancel every reminder the player has. Same reason the caller awaits
    /// seeding first: a store mid-population also looks like a store with no routines in it.
    func sweepOrphanedReminders() async {
        guard let all = try? context.fetch(FetchDescriptor<Routine>()) else { return }
        await practiceReminder.reconcile(liveRoutineUIDs: Set(all.map(\.uid)))
    }
}
