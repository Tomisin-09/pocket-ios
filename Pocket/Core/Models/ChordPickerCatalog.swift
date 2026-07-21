import Foundation

/// Pure, SwiftUI-free helpers for the **chord picker** (ADR 0103) — the search-first Insert grid that
/// replaced the flat insert `Menu`. Kept out of the view so the search match and the movable browse set
/// are unit-testable (the repo's pure-logic rule). The view reads `ChordVoicing.library`, the
/// `SavedChord` `@Query`, and these grips; nothing here is persisted.
enum ChordPicker {
    /// The movable grips offered as browsable **Insert** chips (ADR 0103 D4) — the everyday barre shapes:
    /// E-/A-shape major · minor · dom7. Deliberately a small set (the ones worth a one-tap-to-root
    /// browse); the fuller movable vocabulary (sus / 6 / 9, both families) stays in **Build → Movable
    /// shape** via the `MovableChordSheet`.
    static let insertMovableGrips: [ChordGrip] = [
        .eShapeMajor, .eShapeMinor, .eShapeDom7,
        .aShapeMajor, .aShapeMinor, .aShapeDom7
    ]

    /// The player-facing subtitle for a movable Insert chip — the shape family it belongs to ("E-shape
    /// barre"). The chip's title is the quality (`grip.quality.displayName`); together they read
    /// root-agnostically, because the root is chosen on tap.
    static func movableSubtitle(_ grip: ChordGrip) -> String { "\(grip.name) barre" }

    /// The text a movable chip matches search against — its quality **and** family ("Major E-shape
    /// barre"), so "minor", "e-shape", "dom", and "barre" all filter it.
    static func movableSearchText(_ grip: ChordGrip) -> String {
        "\(grip.quality.displayName) \(grip.name) barre"
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
