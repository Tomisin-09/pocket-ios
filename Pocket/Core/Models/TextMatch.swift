import Foundation

/// **The** substring rule for every search field in the app.
///
/// Four screens used to answer "does this text match what I typed?" four different ways, and a
/// player searching *Andalusian* for *Andalusían* got a different answer depending on which screen
/// they were standing on. That is not a strict library, it reads as a broken one — so the rule is
/// stated once, here, and called from everywhere rather than re-derived per surface.
///
/// **Case- and diacritic-insensitive containment.** Both folds exist for the same reason: what a
/// player types is what they *remember*, not what was stored. Accents are the clearest case, but
/// capitalisation is the common one.
///
/// Pure `Foundation` and free of SwiftUI, so the rule is unit-tested rather than eyeballed through a
/// text field (AGENTS.md). Deliberately *not* a `String` extension: a bare `contains` on every
/// string in the app is exactly how a fifth variant gets written by accident.
enum TextMatch {

    /// Whether `haystack` contains `needle`, ignoring case and diacritics.
    ///
    /// An **empty needle matches everything**, which is what `range(of:)` already returns for one —
    /// stated here because callers rely on it in opposite directions and must not each re-decide it.
    static func contains(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    /// Whether **every** whitespace-separated token in `query` appears somewhere in `haystack`.
    ///
    /// Token-AND is a narrowing search: "scales jul" means scale-template items *in July*, not items
    /// matching either word. An empty or all-whitespace query matches everything, so clearing a
    /// search field restores the full list rather than emptying it.
    static func matchesAllTokens(_ haystack: String, query: String) -> Bool {
        let tokens = query.split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty else { return true }
        return tokens.allSatisfy { contains(haystack, String($0)) }
    }
}
