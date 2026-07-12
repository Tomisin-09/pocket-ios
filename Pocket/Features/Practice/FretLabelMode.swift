import Foundation

/// How each fretboard note is captioned (ADR 0065 build 2). A viewing preference the player toggles —
/// note names, scale-degree intervals, or nothing — persisted globally so the creation preview and
/// the live practice board agree. Intervals need a tonal centre (`FretboardDrill.rootPitchClass`); a
/// rootless drill (a spider walk) shows nothing in interval mode.
enum FretLabelMode: String, CaseIterable, Identifiable {
    case none, note, interval
    var id: String { rawValue }

    /// The control's short label for each mode.
    var pickerLabel: String {
        switch self {
        case .none: return "Off"
        case .note: return "Note"
        case .interval: return "Interval"
        }
    }
}
