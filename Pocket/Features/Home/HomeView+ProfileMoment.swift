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
        if UITestRuntime.isActive { return }
        if !artistIntakeSeen {
            showingIntake = true
            return
        }
        if !artistNamePromptSeen, profiles.first?.artistName == nil, hasEarnedAName {
            showingNamePrompt = true
            return
        }
        // The analytics sheet sits **last** on the ladder so it never competes with a profile moment.
        // What it's for now depends on the region's consent model (ADR 0147):
        //
        // - `.ask` (EEA + CH) — unchanged from ADR 0120: an actual consent ask, gated on a completed
        //   practice so it stays out of the activation flow it exists to measure.
        // - `.notify` (UK + rest of world) — a **catch-up for pre-existing installs only**. A fresh
        //   install is told by the intake footnote and must never see this, which is what the
        //   `artistIntakeSeen` check below encodes: reaching here with the intake seen but the
        //   disclosure unseen means this install passed through an intake that predates the
        //   footnote. `hasPracticed` is deliberately *not* required — they are already being
        //   counted, so telling them is owed now, not after another practice.
        guard !analyticsDisclosureSeen else { return }
        switch AnalyticsPolicy.consentModel(regionCode: Locale.current.region?.identifier) {
        case .ask:
            guard AppSettings.hasPracticed else { return }
        case .notify:
            guard artistIntakeSeen else { return }
        }
        showingAnalyticsConsent = true
    }

    /// Whether the player has done something that earns the naming invitation: they've **completed at
    /// least one exercise** (any exercise carries a `lastPracticed` stamp) **or captured at least one
    /// loop**.
    var hasEarnedAName: Bool {
        exercises.contains { $0.lastPracticed != nil } || !loops.isEmpty
    }
}
