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

    var id: String { rawValue }

    /// The neutral fallback: any unrecognised/empty stored raw value reads as the standard trainer.
    static let `default`: LoopRunMode = .trainer

    /// Decode a stored raw value, folding empty/unknown to the default.
    init(raw: String) { self = LoopRunMode(rawValue: raw) ?? .default }
}
