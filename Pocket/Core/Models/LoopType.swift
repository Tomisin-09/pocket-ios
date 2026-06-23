import Foundation

/// What kind of musical material a loop is (ADR 0036): a closed, single-select set.
/// A loop is exactly one type — free text would lose the mutual exclusivity the planner
/// and filters rely on. `.unset` is the declaration default so SwiftData lightweight
/// migration fills pre-0036 loops without a store wipe (the ADR 0012 / CoreData 134110
/// rule, ADR 0036 migration note 3); the field is brand new, so there are no legacy
/// free-text values to fold (unlike `MusicalKey`) and the enum is stored directly.
enum LoopType: String, CaseIterable, Identifiable, Codable {
    case unset = ""
    case lick               // melodic
    case riff               // melodic + rhythm
    case chords             // rhythmic
    case passage            // composite — multiple licks/riffs/chords in one stretch

    var id: String { rawValue }

    /// Picker/menu label; `.unset` reads as a dash.
    var label: String {
        switch self {
        case .unset: return "—"
        case .lick: return "Lick"
        case .riff: return "Riff"
        case .chords: return "Chords"
        case .passage: return "Passage"
        }
    }

    /// Picker order: unset first, then the three single-element types in increasing
    /// density, and finally `.passage` — the composite that spans more than one of them.
    static var pickerOrder: [LoopType] { [.unset, .lick, .riff, .chords, .passage] }
}
