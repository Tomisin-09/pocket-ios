import Foundation
import SwiftData

/// Sets aside every rating **a command has already moved off** (ADR 0250), run at launch beside the
/// other backfills.
///
/// Under ADR 0169 a promote left the rating in place and marked it stale; under 0250 the same move
/// sets it aside, so the drill reads unrated at its new tempo and the old number is captioned "Last
/// rated…". A store written before 0250 still holds the 0169 shape, and the Done screen would
/// pre-fill that stale 5 and lean the offer toward yet another raise. This brings those ratings into
/// the 0250 shape once, through the models' own `setRatingAside()`, so there is one rule, not two.
///
/// **Runs every launch**, not once, for `PieceDateBackfill`'s reason: an archive restored from an
/// older build can carry a stale rating too. It writes only to a stale one, so a re-run changes
/// nothing. An **unstamped** rating (pre-0169) is left alone: unknown conditions are not moved ones.
enum MasteryStaleBackfill {

    /// Set aside every stale rating in the store. Fetches **all** exercises and loops and filters in
    /// memory, never an optional `#Predicate` (the SwiftData optional-predicate freeze).
    static func run(into context: ModelContext) {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let loops = (try? context.fetch(FetchDescriptor<Loop>())) ?? []
        // Every unit is visited: `map` first, so a `contains` can't stop at the first write.
        let wrote = exercises.map(apply(to:)) + loops.map(apply(to:))
        guard wrote.contains(true) else { return }
        try? context.save()
    }

    /// The per-exercise rule, apart from the store so it's unit-tested. Returns whether it wrote.
    @discardableResult
    static func apply(to exercise: Exercise) -> Bool {
        guard exercise.masteryIsStale else { return false }
        exercise.setRatingAside()
        return true
    }

    /// The per-loop rule. Returns whether it wrote.
    @discardableResult
    static func apply(to loop: Loop) -> Bool {
        guard loop.masteryIsStale else { return false }
        loop.setRatingAside()
        return true
    }
}
