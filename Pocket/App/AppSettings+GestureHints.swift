import Foundation

/// **Hold tips** (ADR 0244) — the song player's tags for the holds it hides. No schema: two
/// `UserDefaults` keys, the switch and the retired set. The rules are `GestureHintPolicy`; this file
/// only stores what it is told.
extension AppSettings {

    /// On until the player turns it off. ADR 0195 learned on a device that a setting which starts off
    /// is found by nobody, and a tip nobody sees teaches nothing.
    ///
    /// Named, not a literal, for the reason `jumpBackInPreferenceDefault` is: an `@AppStorage`
    /// default is what SwiftUI uses for an unset key and it does not consult anything here, so the
    /// song player and Settings both bind to this.
    static let gestureHintsDefault = true

    /// Retire a tag for good (D4): its hold was used, or its ✕ was tapped. Called from every hold the
    /// tags describe, shown or not — a player who finds a hold unaided is never told about it.
    /// Writes only when the set changes, so a hold used every day costs a read.
    static func retireGestureHint(_ hint: GestureHint, store: UserDefaults = .standard) {
        let stored = store.string(forKey: Key.gestureHintsRetired) ?? ""
        let next = GestureHintPolicy.retiring(hint, in: stored)
        guard next != stored else { return }
        store.set(next, forKey: Key.gestureHintsRetired)
    }

    /// Settings' *Show the tips again*: every tag back in play.
    static func restoreGestureHints(store: UserDefaults = .standard) {
        store.removeObject(forKey: Key.gestureHintsRetired)
    }

    /// Every tag back and the switch back to its default. Called at launch under `-uiTesting
    /// -gestureHints` — a simulator keeps its `UserDefaults`, so the second run would find every tag
    /// retired by the first, and a test may have turned them off — and from Settings ▸ Developer.
    static func resetGestureHints(store: UserDefaults = .standard) {
        restoreGestureHints(store: store)
        store.removeObject(forKey: Key.gestureHints)
    }
}
