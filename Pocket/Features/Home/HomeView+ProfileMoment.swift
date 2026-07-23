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
        if !artistIntakeSeen {
            showingIntake = true
            return
        }
        guard !artistNamePromptSeen,
              profiles.first?.artistName == nil,
              hasEarnedAName else { return }
        showingNamePrompt = true
    }

    /// Whether the player has done something that earns the naming invitation: they've **completed at
    /// least one exercise** (any exercise carries a `lastPracticed` stamp) **or captured at least one
    /// loop**.
    var hasEarnedAName: Bool {
        exercises.contains { $0.lastPracticed != nil } || !loops.isEmpty
    }
}
