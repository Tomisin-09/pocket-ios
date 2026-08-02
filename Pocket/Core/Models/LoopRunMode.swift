import Foundation

/// How a **loop** block in a routine is run (ADR 0104 Slice 2): the standard command-anchored loop
/// **trainer** (`LoopRunView`, an audio ramp) or **ear** training (`EarLoopRunView`, ears-only
/// continuous playback + hum/sing + note capture). A loop can appear in a routine either way; this
/// distinguishes the two without a second unit type — the block still references the same `Loop`.
///
/// Stored on `RoutineItem` as a `String` raw value (`loopRunModeRaw`) with a computed accessor —
/// **never** a raw enum attribute on the `@Model` (the SwiftData enum-attribute migration rule;
/// `RoutineItemKind`/`LoopType`/`EntryKind` are the precedents). Unrecognised/empty decodes to
/// `.trainer`, so every loop block saved before this reads as the standard trainer with no migration.
///
/// Foundation-only (no SwiftData/SwiftUI) so the pure pacing/stepping layer can reason over it.
enum LoopRunMode: String, CaseIterable, Identifiable, Codable {
    /// The command-anchored loop trainer — the default and the only mode before ADR 0104 Slice 2.
    case trainer
    /// Ear training — ears-only playback to internalise the loop by ear (ADR 0104).
    case ear
    /// Improvising over the loop as a **backing track** (ADR 0135) — continuous playback of the
    /// section at one live-adjustable tempo, with no ramp and no end the app decides. Reached only by
    /// a loop the player has flagged `isBackingTrack`; the flag *is* the mode's precondition
    /// (`LoopModeAccess`).
    case improvise

    var id: String { rawValue }

    /// How the mode reads as an action — a row menu item, a screen title.
    var label: String {
        switch self {
        case .trainer: "Practice"
        case .ear: "Train your ear"
        case .improvise: "Improvise"
        }
    }

    /// The compact form, for a caption under an icon where "Train your ear" doesn't fit. Matches the
    /// `EntryKind` label each mode's Journal notes carry, so a row and a journal chip agree.
    var rowLabel: String {
        switch self {
        case .trainer: "Practice"
        case .ear: "Ear"
        case .improvise: "Improv"
        }
    }

    /// The SF Symbol a surface draws for this mode. A `String` name, so this file stays
    /// Foundation-only and the pure layer can still reason over the enum.
    var symbolName: String {
        switch self {
        case .trainer: "play.circle"
        case .ear: "ear"
        case .improvise: "guitars"
        }
    }

    /// The neutral fallback: any unrecognised/empty stored raw value reads as the standard trainer.
    static let `default`: LoopRunMode = .trainer

    /// Decode a stored raw value, folding empty/unknown to the default.
    init(raw: String) { self = LoopRunMode(rawValue: raw) ?? .default }
}
