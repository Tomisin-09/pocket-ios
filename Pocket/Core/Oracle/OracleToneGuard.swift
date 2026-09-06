import Foundation

/// The last thing between a model's prose and the player (ADR 0187 D12).
///
/// Pure, table-driven and Foundation-only — the same family as the two `custom_rules` in
/// `.swiftlint.yml` and `check-manual.py`'s C7, all of which exist because prose that looked fine
/// in review shipped anyway. A tone rule that lives in a system prompt is a request. This is a
/// check.
///
/// ### It rejects wholesale, and never scrubs
///
/// A tripped reading is discarded **in full** and the `LocalOracle` fallback shown in its place.
/// It is not redacted, because a partially scrubbed sentence is still a sentence somebody wrote in
/// order to judge you, and the half that survives redaction is not reliably the harmless half.
/// "You've been consistent this week, and the bends are cleaner" does not become safe by losing
/// its first clause; it becomes a grade with the evidence removed.
///
/// ### Two bands
///
/// The **habit** band guards ADR 0070's oldest line: Red Moon never grades practice, and a
/// sentence about how *often* someone showed up is a grade whether or not it carries a number.
///
/// The **tempo** band matters more, not less. `TempoRecord` is literally "faster than you'd played
/// it before" and sits one adjective away from a scoreboard; `TempoTrajectory`'s own doc comment
/// has to say out loud that a line going down is not a regression. Those types are careful because
/// the material is genuinely one word from a leaderboard, and this band is where that word gets
/// caught.
///
/// ### False positives are the safe direction, and are accepted
///
/// A reading wrongly rejected costs the player a model-written paragraph and gains them a
/// deterministic one. A reading wrongly passed costs them the promise the app is built on. So the
/// table is deliberately blunt — `record` trips even though a take is something you record —
/// and the asymmetry is the design, not a rough edge to file down later.
enum OracleToneGuard {

    enum Band: String, Equatable, Sendable, CaseIterable {
        /// Sentences about how often the player showed up (ADR 0070).
        case habit
        /// Sentences that rank a tempo against a past one (ADR 0016, ADR 0070 §2).
        case tempo
    }

    /// What tripped, so a test can assert *which* rule fired rather than only that one did, and so
    /// a rejection can be counted by band without the phrase itself ever being logged.
    struct Trip: Equatable, Sendable {
        let band: Band
        let phrase: String
    }

    /// Single words. Matched as whole tokens, never as substrings: `behind` must not fire on
    /// "behind-the-beat", and more to the point `consistent` must not be reached inside a longer
    /// word that means something else.
    static let habitWords: Set<String> = [
        "streak", "streaks", "consistent", "consistently", "consistency",
        "behind", "lazy", "discipline", "disciplined", "undisciplined", "excuses"
    ]

    static let tempoWords: Set<String> = [
        "plateau", "plateaued", "plateauing", "stalled", "stalling",
        "regressed", "regression", "regressing", "slipped", "slipping",
        "backwards", "record", "records", "pb"
    ]

    /// Multi-word phrases, matched over adjacent tokens so punctuation and casing between them do
    /// not matter — "You should, honestly, …" trips on `you should` exactly as the bare phrase does.
    static let habitPhrases: [[String]] = [
        ["on", "track"], ["you", "should"], ["you", "must"],
        ["push", "through"], ["no", "excuses"], ["fallen", "off"], ["falling", "off"]
    ]

    static let tempoPhrases: [[String]] = [
        ["personal", "best"], ["personal", "bests"], ["faster", "than", "you"]
    ]

    /// The gap `only … days` is allowed to span. "only three days", "only 4 days off" and "only a
    /// couple of days" are all the same sentence — an absence being counted at the player — and a
    /// fixed adjacency check would miss every one of them.
    static let onlyDaysSpan = 4

    /// The first trip, or `nil` when the prose is clean.
    ///
    /// First rather than all: the caller's only decision is reject-or-not, and stopping at the
    /// first match keeps the guard from assembling a list of everything wrong with a paragraph it
    /// is about to throw away.
    static func check(_ text: String) -> Trip? {
        let tokens = tokenise(text)
        guard !tokens.isEmpty else { return nil }

        for (index, token) in tokens.enumerated() {
            if habitWords.contains(token) { return Trip(band: .habit, phrase: token) }
            if tempoWords.contains(token) { return Trip(band: .tempo, phrase: token) }
            if token == "only", onlyDays(from: index, in: tokens) {
                return Trip(band: .habit, phrase: "only … days")
            }
        }
        if let phrase = OracleWordMatch.firstPhrase(habitPhrases, in: tokens) {
            return Trip(band: .habit, phrase: phrase.joined(separator: " "))
        }
        if let phrase = OracleWordMatch.firstPhrase(tempoPhrases, in: tokens) {
            return Trip(band: .tempo, phrase: phrase.joined(separator: " "))
        }
        return nil
    }

    /// Whether the prose is safe to show. The whole guard, as one question.
    static func passes(_ text: String) -> Bool { check(text) == nil }

    // MARK: - Matching

    /// Lower-cased whole words. See `OracleWordMatch` for why the tokeniser is shared with D13's
    /// matchers rather than written twice.
    static func tokenise(_ text: String) -> [String] { OracleWordMatch.tokenise(text) }

    private static func onlyDays(from index: Int, in tokens: [String]) -> Bool {
        let end = min(tokens.count, index + onlyDaysSpan + 1)
        guard index + 1 < end else { return false }
        return tokens[(index + 1)..<end].contains { $0 == "day" || $0 == "days" }
    }
}
