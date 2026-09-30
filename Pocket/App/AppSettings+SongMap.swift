import Foundation

/// The song map's one remembered thing (ADR 0232 D7): which songs have already been offered *Use your
/// markers as sections?*. It's offered once, and answering it either way (using them, or *Not now*)
/// counts, so it never comes back to nag.
///
/// Kept on the device rather than on the song: it's where the screen has got to, not the player's
/// music, so a backup doesn't carry it. A restored song may be offered again, once. Its own file because
/// `AppSettings.swift` sits on SwiftLint's 400-line cap; the key stays in `AppSettings.Key`.
extension AppSettings {

    /// Whether the song with this `sourceID` has been offered sections from its markers.
    static func sectionOfferMade(for songID: String, store: UserDefaults = .standard) -> Bool {
        (store.stringArray(forKey: Key.songMapSectionOffers) ?? []).contains(songID)
    }

    /// Record that it has. Idempotent.
    static func recordSectionOffer(for songID: String, store: UserDefaults = .standard) {
        var offered = store.stringArray(forKey: Key.songMapSectionOffers) ?? []
        guard !offered.contains(songID) else { return }
        offered.append(songID)
        store.set(offered, forKey: Key.songMapSectionOffers)
    }
}
