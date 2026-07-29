import SwiftUI

/// The one-time **profile moments** the home screen orchestrates (ADR 0113), split out of `HomeView`
/// so that view stays within SwiftLint's file/type-length caps. Both are full-screen covers wired in
/// `HomeView.body`; this decides which (if either) to surface on a given appearance.
extension HomeView {
    /// Decide which one-time profile moment (if any) to surface on this Home appearance, keeping the
    /// two full-screen covers mutually exclusive. The **first-launch intake** comes first — until it's
    /// been seen it takes the screen. Once it's done, the **"you've earned a name"** invitation can
    /// surface, but only after the player has done real work and hasn't named themselves yet. A
    /// home-appearance check rather than a per-action callback — for a loop, that just means the offer
    /// surfaces when they return to Home after leaving the song, the calmer moment.
    func maybeOfferProfileMoment() {
        // Under UI testing the app launches fresh, so the first-launch intake would cover Home and
        // block the cards the tests drive. Suppress both first-run moments there (they're exercised
        // on device and in unit tests instead), matching the `-seedScreenshots` launch-arg convention.
        if CommandLine.arguments.contains("-uiTesting") { return }
        if !artistIntakeSeen {
            showingIntake = true
            return
        }
        if !artistNamePromptSeen, profiles.first?.artistName == nil, hasEarnedAName {
            showingNamePrompt = true
            return
        }
        // The analytics consent ask (ADR 0120) sits **last** on the ladder so it never competes with
        // a profile moment, and is gated on a completed practice rather than on launch — the ask is
        // deliberately kept out of the activation flow it exists to measure.
        guard !analyticsPromptSeen, AppSettings.firstPracticeCompleted else { return }
        showingAnalyticsConsent = true
    }

    /// Whether the player has done something that earns the naming invitation: they've **completed at
    /// least one exercise** (any exercise carries a `lastPracticed` stamp) **or captured at least one
    /// loop**.
    var hasEarnedAName: Bool {
        exercises.contains { $0.lastPracticed != nil } || !loops.isEmpty
    }
}
