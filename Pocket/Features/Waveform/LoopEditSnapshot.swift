import Foundation

/// The loop fields `LoopEditSheet` writes on Done — captured **before** the write so an Undo can
/// restore them (ADR 0019 undo, extended from delete to save). Colour is snapshotted as its two
/// mutually-exclusive backing fields (`colorIndex` / `customColorHex`) rather than the picker
/// choice, so restore is a direct write with no re-derivation. `Equatable` so a no-op Done (open,
/// change nothing, tap Done) shows no toast.
struct LoopEditSnapshot: Equatable {
    var name: String
    var mastery: Int?
    var focus: Int?
    var commandTempo: Double?
    var loopType: LoopType
    var tags: [String]
    var colorIndex: Int?
    var customColorHex: String?

    init(_ loop: Loop) {
        name = loop.name
        mastery = loop.mastery
        focus = loop.focus
        commandTempo = loop.commandTempo
        loopType = loop.loopType
        tags = loop.tags
        colorIndex = loop.colorIndex
        customColorHex = loop.customColorHex
    }

    func restore(to loop: Loop) {
        loop.name = name
        loop.mastery = mastery
        loop.focus = focus
        loop.commandTempo = commandTempo
        loop.loopType = loopType
        loop.tags = tags
        loop.colorIndex = colorIndex
        loop.customColorHex = customColorHex
    }
}
