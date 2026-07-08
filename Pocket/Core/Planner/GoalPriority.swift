import Foundation

/// A **coarse goal priority** — the three-level UI surface for a `Goal`'s `weight` (ADR 0015 S5).
/// The goal editor presents Low / Normal / High rather than a raw slider (a personal app wants a
/// decision, not a dial), and this pure enum owns the two mappings: level → stored `weight`, and an
/// existing arbitrary `weight` → the nearest level (so editing a seeded or migrated goal lands on a
/// sensible segment). Kept Foundation-only so both directions are unit-tested.
enum GoalPriority: String, CaseIterable, Identifiable {
    case low
    case normal
    case high

    var id: String { rawValue }

    /// The stored `Goal.weight` this level maps to. `normal` is the model's neutral `1.0`; `low`
    /// halves the pull, `high` doubles it — the deriver multiplies this into candidate priority.
    var weight: Double {
        switch self {
        case .low: return 0.5
        case .normal: return 1.0
        case .high: return 2.0
        }
    }

    /// Short segmented-control label.
    var label: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }

    /// The level whose `weight` is closest to an arbitrary stored weight — so opening an existing goal
    /// (or one seeded off-grid) selects the nearest segment rather than snapping to a default. Ties
    /// resolve to the lower level (stable, deterministic).
    static func nearest(toWeight weight: Double) -> GoalPriority {
        allCases.min(by: { abs($0.weight - weight) < abs($1.weight - weight) }) ?? .normal
    }
}
