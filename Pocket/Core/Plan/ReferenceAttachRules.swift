import Foundation

/// Where a player stands with the plan, in the three states the References rules tell apart (ADR 0264
/// D6). The share extension's snapshot carries the same three (D9).
///
/// **Nothing moves a player from `lapsed` back to `neverBought`**: StoreKit's record of a past purchase
/// never goes away. So a copy of this that has gone stale can only be wrong in the lock, never in what
/// is offered, and D9 leans on that.
enum PlanStanding: String, Equatable, Sendable {
    /// Never bought the plan.
    case neverBought
    /// Bought it once and it has ended: a monthly that ran out, or a refund.
    case lapsed
    /// The plan is on.
    case onPlan

    /// From what `PlanStore` knows. The same two facts the wall reads to greet a returning player
    /// (`PlanAccess.greetsReturningPlayer`), which is exactly `lapsed`.
    init(access: PlanAccess, hasBoughtBefore: Bool) {
        if access.isOn {
            self = .onPlan
        } else if hasBoughtBefore {
            self = .lapsed
        } else {
            self = .neverBought
        }
    }
}

/// **What a reference can be attached to** (ADR 0264 D6), for the owner picker that *Attach to…* (slice
/// 3) and the share extension (slice 4) both draw. Pure, so each rule is a test.
///
/// References themselves are free (ADR 0263: keeping is free). The line inside them follows what the
/// player can open: a song and a loop are free, an exercise and a routine are the plan's.
enum ReferenceAttachRules {

    /// How one destination appears in the picker.
    enum Offer: Equatable, Sendable {
        /// Offered, and it opens.
        case open
        /// Offered with a lock: the reference attaches, and the place opens again with the plan.
        case locked
        /// Not offered at all.
        case hidden
    }

    /// *Keep for later* is `nil`: it is no owner, and it is always open.
    static func offer(_ kind: ReferencePlaceKind?, for standing: PlanStanding) -> Offer {
        switch kind {
        case nil, .song, .loop:
            return .open
        case .exercise, .routine:
            switch standing {
            case .onPlan: return .open
            // Tomisin: "they'd still be able to attach it to a lesson, they just wouldn't be able to
            // access that lesson."
            case .lapsed: return .locked
            // Tomisin: "A free user won't have access to a lesson, so they wouldn't be able to share it."
            case .neverBought: return .hidden
            }
        }
    }

    /// What a locked row says under its name, after its kind: *Exercise · opens with the plan*, as drawn.
    static let lockedCaption = "opens with the plan"

    /// The picker's footer. `nil` on the plan, where there is nothing to explain.
    static func footer(for standing: PlanStanding) -> String? {
        switch standing {
        case .neverBought: "Exercises and routines come with the plan."
        // The wall's returning sentence (ADR 0263 D4), read from there so a lapsed player hears one
        // thing about their drills.
        case .lapsed: PlanWallCopy.explanation(returning: true)
        case .onPlan: nil
        }
    }
}
