import Foundation

/// The unit the standalone tempo automator steps on (ADR 0043): every N **bars** or
/// every N **seconds**. Bars is the musical unit (count downbeats elapsed in the
/// generated beat sequence); seconds rides the same session wall-clock the tracker
/// keeps. A closed two-case set, stored on `MetronomeExercise` through a `String`
/// backing field, never as a raw enum attribute (the SwiftData enum-attribute
/// migration rule — see `Loop.loopTypeRaw`).
enum MetronomeIntervalUnit: String, CaseIterable, Identifiable, Codable {
    case bars
    case seconds

    var id: String { rawValue }

    /// Picker/menu label.
    var label: String {
        switch self {
        case .bars: return "Bars"
        case .seconds: return "Seconds"
        }
    }

    /// "N <unit>" phrasing for the configuration summary — pluralised, with seconds
    /// abbreviated ("4 bars", "1 bar", "30 sec").
    func interval(count: Int) -> String {
        switch self {
        case .bars: return count == 1 ? "1 bar" : "\(count) bars"
        case .seconds: return "\(count) sec"
        }
    }
}
