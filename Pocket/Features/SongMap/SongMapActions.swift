import SwiftUI

/// What the board's controls do, handed down to every row rather than a closure apiece.
struct SongMapActions {
    /// Tap a piece: its tab.
    let view: (UUID) -> Void
    /// A mode picked from a piece's hold menu.
    let open: (UUID, LoopRunMode) -> Void
    /// Tap a section heading or a pin.
    let openMarker: (UUID) -> Void
    /// Tap *as Verse 1*: go to the section it names (ADR 0232 D8).
    let showSection: (TimeInterval) -> Void
    /// How far a piece repeats, from its hold menu (D14, D15): `nil` when it doesn't.
    let setRepeats: (UUID, SongMap.RepeatsTo?) -> Void
    /// Tap a gap in a lane: offer *Make a piece here* (D9).
    let makePiece: (SongMap.Gap) -> Void
    /// *Copy to…*, from a piece's hold menu (D16).
    let copy: (UUID) -> Void
}

/// The colours of the two layers (ADR 0232 D2): Indigo for chords, Teal for notes. Lane colours only,
/// never a status (D4).
enum SongMapStyle {
    static func tint(_ layer: SongMap.Layer) -> Color {
        switch layer {
        case .chords: PocketColor.toolkit
        case .notes: PocketColor.practice
        }
    }

    static func name(_ layer: SongMap.Layer) -> String { layer.name }
}
