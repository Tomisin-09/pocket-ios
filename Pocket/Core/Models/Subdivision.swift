import Foundation

/// How many clicks sound *per beat* on the standalone metronome (ADR 0043). A closed,
/// single-select set: a beat is subdivided exactly one way at a time. `.none` is the
/// plain one-click-per-beat default; the others add evenly-spaced sub-beat ticks (the
/// quieter third `ClickVoice` level, added in slice 5). Stored on `MetronomeExercise`
/// through a `String` backing field, never as a raw enum attribute (the SwiftData
/// enum-attribute migration rule — see `Loop.loopTypeRaw`).
enum Subdivision: String, CaseIterable, Identifiable, Codable {
    case none = ""        // one click per beat (quarters in 4/4)
    case eighths          // 2 per beat
    case triplets         // 3 per beat
    case sixteenths       // 4 per beat

    var id: String { rawValue }

    /// Evenly-spaced ticks sounded per beat, including the beat itself. Drives both the
    /// generator's sub-beat emission (slice 5) and the picker label.
    var ticksPerBeat: Int {
        switch self {
        case .none: return 1
        case .eighths: return 2
        case .triplets: return 3
        case .sixteenths: return 4
        }
    }

    /// Picker/menu label.
    var label: String {
        switch self {
        case .none: return "None"
        case .eighths: return "Eighths"
        case .triplets: return "Triplets"
        case .sixteenths: return "Sixteenths"
        }
    }

    /// Picker order: simplest (no subdivision) first, then increasing density.
    static var pickerOrder: [Subdivision] { [.none, .eighths, .triplets, .sixteenths] }
}
