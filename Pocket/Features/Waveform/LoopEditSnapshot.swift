import Foundation

/// The loop fields `LoopEditSheet` writes on Done — captured **before** the write so an Undo can
/// restore them (ADR 0019 undo, extended from delete to save). Colour is snapshotted as its two
/// mutually-exclusive backing fields (`colorIndex` / `customColorHex`) rather than the picker
/// choice, so restore is a direct write with no re-derivation. `Equatable` so a no-op Done (open,
/// change nothing, tap Done) shows no toast.
struct LoopEditSnapshot: Equatable {
    var name: String
    var mastery: Int?
    /// The command speed that rating was given at (ADR 0169) — snapshotted so an Undo restores the
    /// reading's *conditions*, not just its number.
    var masteryAtSpeed: Double?
    var focus: Int?
    var commandTempo: Double?
    var loopType: LoopType
    var tags: [String]
    var colorIndex: Int?
    var customColorHex: String?
    /// The favourite pin (ADR 0119), editable here since ADR 0125 — so Undo covers it too.
    var isFavorite: Bool
    /// The backing-track flag (ADR 0135 B1) — set on this sheet, so Undo has to cover it or a
    /// mis-tapped toggle would survive the "Saved changes" undo that appears to have reverted it.
    var isBackingTrack: Bool

    init(_ loop: Loop) {
        name = loop.name
        mastery = loop.mastery
        masteryAtSpeed = loop.masteryAtSpeed
        focus = loop.focus
        commandTempo = loop.commandTempo
        loopType = loop.loopType
        tags = loop.tags
        colorIndex = loop.colorIndex
        customColorHex = loop.customColorHex
        isFavorite = loop.isFavorite
        isBackingTrack = loop.isBackingTrack
    }

    func restore(to loop: Loop) {
        loop.name = name
        // Restored **verbatim**, not through `rateMastery` (ADR 0169): this is an undo, so the
        // reading has to come back exactly as it was, conditions included. Re-stamping here would
        // silently re-date a rating the player is in the middle of *discarding* an edit to.
        loop.mastery = mastery
        loop.masteryAtSpeed = masteryAtSpeed
        loop.focus = focus
        loop.commandTempo = commandTempo
        loop.loopType = loopType
        loop.tags = tags
        loop.colorIndex = colorIndex
        loop.customColorHex = customColorHex
        loop.isFavorite = isFavorite
        loop.isBackingTrack = isBackingTrack
    }
}
