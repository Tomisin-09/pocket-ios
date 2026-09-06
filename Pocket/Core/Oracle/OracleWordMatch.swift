import Foundation

/// Whole-word matching over prose, shared by `OracleToneGuard` (ADR 0187 D12) and
/// `OracleSafetySignal` (D13).
///
/// One implementation rather than two, because both are tables of words and phrases and the way
/// they are matched *is* the rule. Two tokenisers would drift, and the day they drifted one of the
/// two guards would quietly start matching substrings.
///
/// Foundation-only and pure. No regular expressions: a word list is clearer as a set than as an
/// alternation, and `range(of:)` has a toolchain-dependent answer for an empty needle — nil on
/// Xcode 16, a range on 26.5 — which is exactly the kind of edge a guard must not inherit.
enum OracleWordMatch {

    /// Lower-cased words, with everything else dropped.
    ///
    /// Split on "not a letter or a digit" rather than on whitespace, so `consistency.` and
    /// `(streak)` tokenise to the bare word — a guard that can be evaded with a full stop is not a
    /// guard. Digits survive because `only 3 days` needs them; they never match a table, which
    /// holds no digits.
    static func tokenise(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    /// Whether `tokens` contains `phrase` as a run of adjacent whole tokens.
    ///
    /// Adjacency is over *tokens*, not characters, so punctuation and casing between the words do
    /// not matter: "You should, honestly, …" matches `you should` exactly as the bare phrase does.
    static func contains(_ phrase: [String], in tokens: [String]) -> Bool {
        guard !phrase.isEmpty, tokens.count >= phrase.count else { return false }
        for start in 0...(tokens.count - phrase.count)
        where Array(tokens[start..<(start + phrase.count)]) == phrase {
            return true
        }
        return false
    }

    /// The first phrase from `phrases` present in `tokens`.
    static func firstPhrase(_ phrases: [[String]], in tokens: [String]) -> [String]? {
        phrases.first { contains($0, in: tokens) }
    }

    /// The first token that is in `words`.
    static func firstWord(_ words: Set<String>, in tokens: [String]) -> String? {
        tokens.first { words.contains($0) }
    }
}
