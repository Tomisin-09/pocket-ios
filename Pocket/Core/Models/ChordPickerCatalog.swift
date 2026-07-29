import Foundation

/// Pure, SwiftUI-free helpers for the **chord picker** (ADR 0103) — the search-first Insert grid that
/// replaced the flat insert `Menu`. Kept out of the view so the search match and the movable browse set
/// are unit-testable (the repo's pure-logic rule). The view reads `ChordVoicing.library`, the
/// `SavedChord` `@Query`, and these grips; nothing here is persisted.
enum ChordPicker {
    /// The movable grips offered as browsable **Insert** chips (ADR 0103 D4, extended ADR 0106) — **all
    /// of Tier 1** (ADR 0122): major · minor · dom7 · min7 · maj7 · power chord on both CAGED root
    /// strings. The first cut showed six of these twelve on a "keep the grid small" argument, which read
    /// on device as a vocabulary gap rather than a curation — the shapes already existed, so a player who
    /// wanted a movable **m7** had to leave Insert for Build → Movable shape to reach one that was
    /// sitting right there. The section is collapsible (ADR 0109), so the taller grid costs nothing when
    /// it isn't wanted. `ChordGrip.tier1`'s own order (family, then quality) lays each family out on
    /// exactly two rows of the three-column grid. Tier 2 (sus / 6 / 9) still stays in **Build**.
    static let insertMovableGrips: [ChordGrip] = ChordGrip.tier1

    /// The player-facing subtitle for a movable Insert chip — the shape family it belongs to ("E-shape
    /// barre"). The chip's title is the quality (`grip.quality.displayName`); together they read
    /// root-agnostically, because the root is chosen on tap. A **power chord is not a barre** (root + 5th,
    /// two/three fingers), so its subtitle drops "barre" and reads just the family ("E-shape").
    static func movableSubtitle(_ grip: ChordGrip) -> String {
        grip.quality == .fifth ? grip.name : "\(grip.name) barre"
    }

    /// The text a movable chip matches search against — its quality **and** family ("Major E-shape
    /// barre"), so "minor", "e-shape", "dom", and "barre" all filter it. Power chords omit "barre" (they
    /// aren't one) but pick up "power chord" / "5" via `quality.displayName` / `nameSuffix`.
    static func movableSearchText(_ grip: ChordGrip) -> String {
        let barre = grip.quality == .fifth ? "" : " barre"
        return "\(grip.quality.displayName) \(grip.name)\(barre)"
    }

    /// **Tier 2** as Insert chips (ADR 0122) — the suspensions, 6ths and 9ths. These were the whole
    /// reason `MovableChordSheet` existed; with them here, browsing a chip and picking a root reaches the
    /// same voicing in two taps instead of four (family → quality → root → confirm), so the sheet was
    /// retired rather than left as a second, slower door to the same shapes. Placed **last** and starting
    /// **collapsed** (`ChordPickerSheet.initiallyCollapsed`): it's the advanced end of the vocabulary, and
    /// a live search force-expands it anyway, so nothing hides behind the chevron.
    static let insertTier2Grips: [ChordGrip] = ChordGrip.tier2

    /// The **triad** grips offered as Insert chips (ADR 0109) — major / minor on the three upper string
    /// sets (G-B-e, D-G-B, A-D-G), root position. Small three-note shapes, slid to any root like the
    /// movable barres; browsed in their own collapsible Insert section.
    static let insertTriadGrips: [ChordGrip] = ChordGrip.triads

    /// A triad chip's subtitle — the **string set** and **inversion** it voices ("G-B-e · 1st inv"). The
    /// chip title is the quality; together they read root-agnostically since the root is chosen on tap.
    static func triadSubtitle(_ grip: ChordGrip) -> String { "\(grip.name) · \(grip.inversionName)" }

    /// The text a triad chip matches search against — quality, "triad", the string set, and the inversion,
    /// so "triad", "major", "g-b-e", "inversion", and "1st" all filter it.
    static func triadSearchText(_ grip: ChordGrip) -> String {
        "\(grip.quality.displayName) triad \(grip.name) \(grip.inversionName) inversion"
    }

    /// Case- and diacritic-insensitive substring match driving the picker's live search (ADR 0103 D1).
    /// An empty or whitespace-only query matches everything.
    static func matches(query: String, in text: String) -> Bool {
        let needle = normalized(query)
        guard !needle.isEmpty else { return true }
        return normalized(text).contains(needle)
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }
}
