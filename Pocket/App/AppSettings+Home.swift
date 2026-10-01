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

// MARK: - The tile beside Toolkit (ADR 0235 D6)

extension AppSettings {

    /// What the tile beside Toolkit opens until the player changes it: **My tabs**. Named for the reason
    /// `jumpBackInPreferenceDefault` is: an `@AppStorage` default is what SwiftUI uses for an unset key,
    /// and it doesn't consult the resolver, so the tile, its hold menu and Settings all bind to this.
    static let homeToolDefault = ToolkitSection.myTabs

    /// A missing or unknown stored value opens My tabs: a value written by a later build that knows a
    /// seventh tool opens something real rather than nothing.
    static func resolvedHomeTool(storedValue: String?) -> ToolkitSection {
        storedValue.flatMap(ToolkitSection.init(rawValue:)) ?? homeToolDefault
    }

    /// The tile's caption, *Hold to change*, until the tile has been changed once by either door. Like
    /// the empty library's, it's an instruction, and it goes once it's followed (ADR 0197 D3, as amended).
    static func homeToolCaption(chosen: Bool) -> String? {
        chosen ? nil : "Hold to change"
    }

    /// Clear both keys, beside `resetJumpBackInPreference` and for its reason: called once at launch under
    /// `-uiTesting` and nowhere else, so a test that changes the tile doesn't leave it changed for the next
    /// test, the next run, or the Home figures the manual is shot through.
    static func resetHomeTool(store: UserDefaults = .standard) {
        store.removeObject(forKey: Key.homeTool)
        store.removeObject(forKey: Key.homeToolChosen)
    }
}
