import Foundation

/// The first-launch intake's cards, in order (ADR 0113, 0246, 0248). Pure, so the order is a unit test
/// rather than a `switch` inside a view: which cards a player sees follows from two of their answers.
enum IntakeStep: Equatable, CaseIterable {
    /// *What do you play?* First, because the next card asks where they are with it (ADR 0248).
    case plays
    case experience
    case genres
    case dream
    /// *What are you working toward?* — only when `IntakeGoalOffer.asksForGoals` says so.
    case goals
    case minutes

    /// The cards for these answers so far. Changing either answer on its own card cannot move the
    /// player: *plays* is first and *dream* comes before the one card they decide.
    static func steps(plays: PlayedInstrument?, dream: MusicalDream?) -> [IntakeStep] {
        IntakeGoalOffer.asksForGoals(after: dream, plays: plays)
            ? [.plays, .experience, .genres, .dream, .goals, .minutes]
            : [.plays, .experience, .genres, .dream, .minutes]
    }
}
