import StoreKit
import SwiftData
import SwiftUI

/// The one-time **profile moments** the home screen orchestrates (ADR 0113), split out of `HomeView`
/// so that view stays within SwiftLint's file/type-length caps. Both are full-screen covers wired in
/// `HomeView.body`; this decides which (if either) to surface on a given appearance — and, since
/// ADR 0214, whether to ask for an App Store review once they are all done with.
extension HomeView {
    /// Decide which one-time moment (if any) to surface on this Home appearance, keeping the covers
    /// mutually exclusive. The **first-launch intake** comes first — until it's been seen it takes
    /// the screen. Once it's done, the **"you've earned a name"** invitation can surface, but only
    /// after the player has done real work and hasn't named themselves yet. The **review ask** is
    /// last, and is the only rung that draws nothing of our own. (An analytics disclosure sat between
    /// the two until ADR 0239 removed analytics.)
    ///
    /// A home-appearance check rather than a per-action callback — for a loop, that just means the
    /// offer surfaces when they return to Home after leaving the song, the calmer moment.
    func maybeOfferProfileMoment() {
        // Under UI testing the app launches fresh, so the first-launch intake would cover Home and
        // block the cards the tests drive. Suppress both first-run moments there (they're exercised
        // on device and in unit tests instead), matching the `-seedScreenshots` launch-arg convention.
        //
        // The review ask inherits this guard by sitting below it, and needs it more than the covers
        // do: a driven run that reached `requestReview` would spend part of the **device's** real
        // three-per-year budget, on a machine nobody is going to rate the app from.
        if UITestRuntime.isActive { return }
        if !artistIntakeSeen {
            showingIntake = true
            return
        }
        if !artistNamePromptSeen, profiles.first?.artistName == nil, hasEarnedAName {
            showingNamePrompt = true
            return
        }
        maybeAskForReview()
        // Last, and unconditionally: every path that gets here has decided this appearance, and the
        // next one is no longer a launch.
        homeHasAppearedThisLaunch = true
    }

    /// Ask for an App Store review, if `ReviewPromptPlan` says we may (ADR 0214).
    ///
    /// Every decision lives in the plan; this supplies the two things only a view can know — what is
    /// on screen, and how to reach the system — and nothing else.
    private func maybeAskForReview() {
        ReviewPrompt.askIfDue(screenIsSettled: screenIsSettled,
                              sittingCount: completedSittingCount(),
                              ask: { requestReview() })
    }

    /// Whether this appearance is a calm one, i.e. nothing else has the screen or is about to take
    /// it. Three separate rules, and all three are silent when they go wrong — a prompt asked
    /// underneath something else is simply gone, and the app is never told it was.
    ///
    /// 1. **Not the launch appearance.** A cold launch is the player arriving with something to do;
    ///    the ask waits for a return, which is what the player was promised ("when you next come back
    ///    to the home screen"). This once also kept the ask out from under the launch paywall's
    ///    cover; ADR 0237 removed the paywall, and the rule stands on the first reason alone.
    /// 2. **No reminder landing.** A tapped practice reminder pushes a routine on this very
    ///    appearance (ADR 0186 D6, wired in `HomeView.body`).
    /// 3. **Nothing else pushing** — an import's "open on create", or the library.
    ///
    /// **`.onAppear` on the stack root does not re-fire when a cover dismisses**, and this rung
    /// depends on that: the ask lands on the first Home *return*, which after five sittings is
    /// almost always the walk back from a practice session. Nobody should later "fix" that with an
    /// `.onChange` — it would move the ask onto the frame a cover disappears, which is the one frame
    /// it must not be on.
    private var screenIsSettled: Bool {
        homeHasAppearedThisLaunch
            && notificationRouter.pendingRoutineUID == nil
            && openingRoutine == nil
            && openingSong == nil
            && !showingLibrary
    }

    /// How many practice **sittings** the log holds.
    ///
    /// Fetched on demand rather than added as a seventh `@Query` — an unbounded query over the whole
    /// practice log, re-run on every redraw of the app's front door, is exactly what `HomeStatsStrip`
    /// refused. It runs only when `ReviewPromptPlan` has exhausted its cheap gates, which on a normal
    /// launch is never, and after the ask has happened is never again.
    ///
    /// `fetchCount` first: it is a count in the store with no rows materialised, and sittings can
    /// never exceed runs, so a log too small to matter costs one count and no objects. The fetch
    /// that follows is unfiltered and mapped in memory, per `docs/swiftdata-gotchas.md` — an optional
    /// `#Predicate` is the freeze this project has already hit.
    private func completedSittingCount() -> Int {
        let descriptor = FetchDescriptor<PracticeRun>(sortBy: [SortDescriptor(\.startedAt)])
        guard let runs = try? context.fetchCount(descriptor),
              runs >= ReviewPromptPlan.sittingsBeforeAsking,
              let rows = try? context.fetch(descriptor) else { return 0 }
        return PracticeLog.sittings(rows.map(\.record)).count
    }

    /// Whether the player has done something that earns the naming invitation: they've **completed at
    /// least one exercise** (any exercise carries a `lastPracticed` stamp) **or captured at least one
    /// loop**.
    var hasEarnedAName: Bool {
        exercises.contains { $0.lastPracticed != nil } || !loops.isEmpty
    }
}
