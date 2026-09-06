import Foundation

/// Home's **Jump back in** preference (ADR 0193) — which kind of unit the resume card offers.
///
/// Its own file rather than a few more lines in `AppSettings.swift` for the reason
/// `AppSettings+Tuner.swift` is: that file sits *exactly* on SwiftLint's 400-line cap, so the next
/// setting to land anywhere has to land beside it, not in it.
///
/// **The key stays in `AppSettings.Key`** — a nested enum and a single alphabet of every key the app
/// has ever written. Scattering it across extensions is how two keys end up with the same string.
extension AppSettings {

    /// The default kind the resume card offers when the player has never chosen: **most recent**,
    /// which is precisely what Home did before this setting existed, so an upgrading install sees no
    /// change at all.
    ///
    /// Named rather than written as a literal for the reason `exerciseAnimatesDefault` is: the value
    /// an `@AppStorage` declares is what SwiftUI actually uses for an unset key, and it does **not**
    /// consult the accessor below. Here that drift would be visible — Settings claiming one thing
    /// while Home showed another — so both sites read this. Do not inline it back.
    static let jumpBackInPreferenceDefault = JumpBackInPreference.default

    /// Which kind Home's resume card offers (ADR 0193). Default `.mostRecent`.
    static var jumpBackInPreference: JumpBackInPreference {
        resolvedJumpBackIn(storedValue: UserDefaults.standard.string(forKey: Key.jumpBackIn))
    }

    /// Pure default-resolution: a missing or unrecognised stored value falls back to `.mostRecent`
    /// rather than crashing on a bad raw value (mirrors `resolvedTempoWarning`). Unrecognised
    /// degrading to the default is the right direction — a value written by a later build that knows
    /// a fourth kind shows the newest thing you practised, which is never wrong, only unspecific.
    static func resolvedJumpBackIn(storedValue: String?) -> JumpBackInPreference {
        guard let storedValue else { return jumpBackInPreferenceDefault }
        return JumpBackInPreference(rawValue: storedValue) ?? jumpBackInPreferenceDefault
    }

    /// Clear the resume preference (ADR 0193), beside `resetJournalFilters`.
    ///
    /// **Called once at launch under `-uiTesting`, and nowhere else**, for the reason spelled out
    /// there: a simulator keeps its `UserDefaults` between runs, so a test that pins the card to
    /// *Routine* leaves it pinned for the next test and for the next *run*. On Home that is the
    /// expensive version of the trap — `reference/home` is shot through this card, and a pinned
    /// preference would return a clean, plausible photograph of the wrong unit with nothing in the
    /// run to object.
    static func resetJumpBackInPreference(store: UserDefaults = .standard) {
        store.removeObject(forKey: Key.jumpBackIn)
    }
}
