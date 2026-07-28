import Foundation

/// How each fretboard note is captioned (ADR 0065 build 2). A viewing preference the player toggles —
/// note names, scale-degree intervals, or nothing — persisted globally so the creation preview and
/// the live practice board agree. Intervals need a tonal centre (`FretboardDrill.rootPitchClass`); a
/// rootless drill (a spider walk, a hand-drawn board) can't spell them, so it offers `.available(hasRoot:)`
/// instead of the raw cases and resolves an inherited `.interval` down to `.none`.
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

    /// The modes a surface can actually offer. Interval is dropped where the drill names no root —
    /// it would render nothing at all, which read as a broken option rather than an inapplicable one
    /// (device feedback 2026-07-28).
    static func available(hasRoot: Bool) -> [FretLabelMode] {
        hasRoot ? allCases : allCases.filter { $0 != .interval }
    }

    /// This mode as a rootless surface should render it. The preference is **global**, so a player who
    /// chose Interval on a scale then opens a hand-drawn drill inherits a mode that can't be spelled;
    /// resolving it to `.none` here keeps the picker's selection in range and matches what the board
    /// actually draws. The stored preference itself is untouched — going back to a scale restores it.
    func resolved(hasRoot: Bool) -> FretLabelMode {
        (self == .interval && !hasRoot) ? .none : self
    }
}
