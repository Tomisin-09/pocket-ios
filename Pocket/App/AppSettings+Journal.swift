import Foundation

/// The Journal feed's **persisted list controls** (ADR 0190 D8) — and the one function that clears
/// them.
///
/// Its own file rather than a few more lines in `AppSettings.swift` for the reason
/// `AppSettings+Home.swift` and `AppSettings+Tuner.swift` are: that file sits on SwiftLint's
/// 400-line cap, so the next thing to land anywhere has to land beside it. ADR 0207's tag facet is
/// the key that pushed it over.
///
/// **The keys themselves stay in `AppSettings.Key`** — a single alphabet of every key the app has
/// ever written. Scattering them across extensions is how two keys end up with the same string.
extension AppSettings {

    /// Every Journal list control that survives leaving the screen: scope, sort, *Pinned only*, the
    /// two *Show* facets, and the look-back period.
    ///
    /// **Add to this the moment you persist another one.** ADR 0190 made that obligation explicit and
    /// the list has since grown twice, both times under ADR 0207 — a key that joins the screen without
    /// joining this list is a silent hole in the guarantee below, and nothing in a green run would
    /// notice.
    static var journalFilterKeys: [String] {
        [Key.journalScope, Key.journalSortOrder, Key.journalPinnedOnly,
         Key.journalOwnerFilter, Key.journalTagFilter, Key.journalLookbackPeriod]
    }

    /// Clear them all.
    ///
    /// **Called once at launch under `-uiTesting`, and nowhere else.** These are the first filters in
    /// the app that survive leaving a screen, and a simulator keeps its `UserDefaults` between runs —
    /// so without this a test that switches the feed to *Takes* leaves it there for the next test,
    /// and for the next *run*. The manual's shoot is where that bites hardest: `testJournalTakes`
    /// sorts before `testJournalTimeline`, so the timeline figure would be shot through the takes
    /// filter and come back a clean, plausible photograph of the wrong list — with nothing in the run
    /// to object. (`shoot-manual.sh` erases the device first, which handles it *between* runs and not
    /// at all *within* one.)
    ///
    /// A UI test wanting to exercise the persistence itself writes the keys and asserts on them; what
    /// it cannot have is an unstated starting point inherited from whatever ran last.
    static func resetJournalFilters(store: UserDefaults = .standard) {
        for key in journalFilterKeys {
            store.removeObject(forKey: key)
        }
    }
}
