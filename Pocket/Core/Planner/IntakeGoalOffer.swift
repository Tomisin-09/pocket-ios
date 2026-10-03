import Foundation

/// The first run's goals card (ADR 0246) — which long-term goal templates the intake offers, in what
/// order for the dream the player just named, and whether it asks at all. Pure / Foundation-only, so
/// the rule that matters is a unit test rather than a promise: **no goal the card offers may come to
/// nothing on a new install.**
///
/// The card exists because the dream, on its own, only tilted the planner by `dreamLift` (×1.3) and
/// nothing on screen ever showed it. The goals it creates are ordinary `LongTermGoal`s, so they
/// appear in Today's session, the Practice log's echo and Practice ▸ Long-term goals the moment the
/// intake closes.
enum IntakeGoalOffer {

    /// How many the card takes. Three, not the tier's ten (`LongTermRank.maxGoals`): on a first run,
    /// three ranked goals give a direction, and ten would be homework.
    static let maxPicks = 3

    /// The templates the card may offer, in `GoalTemplateLibrary` order. **Each one must derive at
    /// least one candidate from the first-run library** (`IntakeGoalOfferTests`). A goal that gives
    /// Today's session nothing turns the player's first answer into nothing, on the day they are
    /// deciding whether the app is worth keeping.
    ///
    /// Left off for that reason, as of 2026-10-03: *Play a specific song* (it needs a song, and a new
    /// install has none) and *Train your ear* (none of the first-run drills works on its skills). They
    /// stay in the editor, where a player who has the material for them will find them. *Tighten your
    /// timing* was left off too, until ADR 0247 seeded a strumming drill for it. If the first-run set
    /// gains a drill that reaches another, add it here; the test says whether it qualifies.
    static let offeredIDs: [String] = [
        "build-speed", "improvise", "timing", "chord-changes", "fretboard", "fretting-hand", "write",
        "general"
    ]

    /// Whether the intake asks at all. **Not after "Just unwind"**: giving homework to someone who
    /// came to unwind is the pressure ADR 0070 rules out. A skipped dream still gets the card, because
    /// skipping one question is not a statement about the next.
    ///
    /// **Nor for someone who doesn't play guitar or bass** (ADR 0248): their first run seeds no drills, so
    /// by this card's own rule every template comes to nothing. `nil` — the question skipped — is asked as
    /// it always was, about the guitar.
    static func asksForGoals(after dream: MusicalDream?, plays: PlayedInstrument? = nil) -> Bool {
        dream != .unwind && plays?.leansOnSongs != true
    }

    /// The card's templates: the dream's closest first, then the rest in library order. With no dream
    /// (skipped) it is library order throughout.
    static func templates(for dream: MusicalDream?) -> [GoalTemplate] {
        let offered = offeredIDs.compactMap(GoalTemplateLibrary.template)
        let leading = dream.map(preferredIDs) ?? []
        let first = leading.compactMap { id in offered.first { $0.id == id } }
        return first + offered.filter { !leading.contains($0.id) }
    }

    /// Each dream's closest templates, best first. Ids the card does not offer are skipped by
    /// `templates(for:)`, so this can name a template before it qualifies without breaking the card.
    static func preferredIDs(for dream: MusicalDream) -> [String] {
        switch dream {
        case .playSongs: return ["chord-changes", "timing", "ear", "improvise"]
        case .writeMusic: return ["write", "chord-changes", "fretboard", "improvise"]
        case .getGood: return ["build-speed", "fretting-hand", "timing", "fretboard"]
        case .unwind: return []
        }
    }

    /// Tap a template: picking appends it, so **tap order is rank**; picking it again removes it and
    /// the ones after move up. A pick past `maxPicks` is ignored rather than replacing one, because
    /// the card shows the unpicked rows dimmed by then and a dimmed row that still worked would lie.
    static func toggling(_ id: String, in picks: [String]) -> [String] {
        if picks.contains(id) { return picks.filter { $0 != id } }
        guard picks.count < maxPicks else { return picks }
        return picks + [id]
    }
}
