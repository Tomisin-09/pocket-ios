import Foundation

/// When the **first-song walkthrough** runs (ADR 0149 §2, §4). No schema: two `UserDefaults` keys.
///
/// The life of it is three states — never armed, armed, spent — and it moves forward only:
///
/// - **Armed by the first successful import** (§2), from `SongImporter.persist`, which every import
///   passes through — the starter track included (ADR 0219 D3). Not at install, not at the end of the
///   intake: at first launch there is nothing to guide. An install that already holds a song with
///   audio is not a first import — it goes straight to spent — so a player upgrading into this is
///   never walked through an app they already use.
/// - **Spent by the visit that shows it.** Finished, dismissed or walked away from, it does not
///   return on the next import, the next launch or the next song (§4): guidance that re-offers
///   itself after refusal stops reading as help. It is spent when the card **appears** — once the
///   song's audio has loaded — rather than when the visit ends, so a crash or a force-quit mid-way
///   counts as the walk-away it is, and a song whose audio never loaded spends nothing.
/// - **Re-armed only on request**, from Help & FAQs (§4, §6).
///
/// The ceremony has its own latch, because §5's "exactly once" is about the player, not the run: a
/// re-entry walks the same three beats and ticks them silently.
extension AppSettings {

    /// The walkthrough's persisted state. `String`-raw so a value written by a later build that knows
    /// a fourth state degrades to `.never` rather than crashing.
    enum SongWalkthroughLedger: String {
        case never
        case armed
        case spent
    }

    static func songWalkthroughLedger(store: UserDefaults = .standard) -> SongWalkthroughLedger {
        resolvedSongWalkthroughLedger(storedValue: store.string(forKey: Key.songWalkthrough))
    }

    static func resolvedSongWalkthroughLedger(storedValue: String?) -> SongWalkthroughLedger {
        storedValue.flatMap(SongWalkthroughLedger.init(rawValue:)) ?? .never
    }

    /// Arm it if this import is the player's first (§2); a no-op once anything has been decided.
    ///
    /// An import into a library that already held audio **spends** it instead: that player's first
    /// import happened before this existed, and will not happen again. Writing the answer down also
    /// means the caller's fetch runs once per install, not once per import forever.
    static func armSongWalkthroughIfFirstImport(libraryAlreadyHadAudio: Bool,
                                                store: UserDefaults = .standard) {
        guard songWalkthroughLedger(store: store) == .never else { return }
        let next: SongWalkthroughLedger = libraryAlreadyHadAudio ? .spent : .armed
        store.set(next.rawValue, forKey: Key.songWalkthrough)
    }

    /// Spend an armed walkthrough, reporting whether there was one to spend. The practice screen
    /// calls this once its audio has loaded; `true` means *this* visit runs it.
    static func takeArmedSongWalkthrough(store: UserDefaults = .standard) -> Bool {
        guard songWalkthroughLedger(store: store) == .armed else { return false }
        store.set(SongWalkthroughLedger.spent.rawValue, forKey: Key.songWalkthrough)
        return true
    }

    /// Help & FAQs' *Show me the first-song guide again* (§4): the next song opened runs it.
    static func rearmSongWalkthrough(store: UserDefaults = .standard) {
        store.set(SongWalkthroughLedger.armed.rawValue, forKey: Key.songWalkthrough)
    }

    /// Whether the one ceremony (§5) has been shown on this install.
    static func songWalkthroughCeremonySeen(store: UserDefaults = .standard) -> Bool {
        store.bool(forKey: Key.songWalkthroughCeremonySeen)
    }

    static func recordSongWalkthroughCeremonySeen(store: UserDefaults = .standard) {
        store.set(true, forKey: Key.songWalkthroughCeremonySeen)
    }

    /// Called once at launch under `-uiTesting -walkthrough`, and nowhere else. A simulator keeps
    /// both its store and its `UserDefaults`, so the second run of a suite would find the starter
    /// track already adopted (no import, so nothing arms) and the walkthrough already spent. Arming
    /// it here, ceremony latch cleared, makes every run the first.
    static func resetSongWalkthroughForUITest(store: UserDefaults = .standard) {
        rearmSongWalkthrough(store: store)
        store.removeObject(forKey: Key.songWalkthroughCeremonySeen)
    }
}
