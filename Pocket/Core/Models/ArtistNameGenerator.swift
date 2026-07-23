import Foundation

/// The **artist-name generator** (ADR 0113 Slice 4): a pure `seed → name` selection over small,
/// hand-curated word pools in the **Red Moon register** — mythic, dusk-lit, cinematic — that upgrades
/// the naming ceremony from a blank field to an *offered* name ("Vega", "Velvet Wolf", "Midnight
/// Ash"). It is a spark, never an imposition: the sheet lets the player accept, spin again, or type
/// their own, and the greeting is indifferent to which they chose.
///
/// **Safe by construction.** Every name is composed from curated pools (the primary safety story) and
/// then screened against a `blocklist`; a blocked composition deterministically advances the seed and
/// retries, so no seed can ever surface an unfortunate word. Both properties are unit-tested over a
/// wide seed sweep.
///
/// **Deterministic, then random.** `name(seed:)` is a pure function of its seed — same seed, same
/// name — so the ceremony can offer a *fated* first name seeded from the player's intake answers
/// (`seed(experience:genres:dream:)`) and then spin freely (a fresh random seed per reroll). Pure /
/// Foundation-only per AGENTS.md, so the whole thing is unit-tested and free of SwiftUI/SwiftData.
enum ArtistNameGenerator {

    // MARK: - Curated pools (Red Moon register)

    /// First words of a two-word name — dusk-lit, textural adjectives. Disjoint from `nouns` so a
    /// two-word name never doubles a word ("Ember Ember").
    static let adjectives = [
        "Velvet", "Midnight", "Hollow", "Crimson", "Ashen", "Silver", "Pale", "Golden", "Lonesome",
        "Ragged", "Restless", "Feral", "Gilded", "Smoke", "Amber", "Cobalt", "Wilder", "Dusk",
        "Iron", "Weathered"
    ]

    /// Second words of a two-word name — evocative, concrete nouns.
    static let nouns = [
        "Wolf", "Moon", "Crow", "Fox", "Thorn", "Rivers", "Halo", "Ghost", "Tide", "Bells", "Wren",
        "Sparrow", "Ridge", "Wire", "Fable", "Vale", "Reed", "Harbor", "Ember", "Ash"
    ]

    /// Single strong words offered on their own — the occasional one-word name (ADR: "Vega · Ember").
    static let singles = [
        "Vega", "Nova", "Onyx", "Sable", "Vesper", "Halcyon", "Marrow", "Cinder", "Rook", "Lark",
        "Ember", "Fable", "Cirrus", "Wren", "Sol"
    ]

    /// Substrings that veto a composed name (case-insensitive, checked with spaces removed). The
    /// curated pools are the primary safeguard; this is the belt-and-braces net that guarantees no
    /// pool addition can ever ship an unfortunate combination. Non-exhaustive by design — a curated
    /// generator doesn't need an exhaustive list, only a mechanism.
    static let blocklist = [
        "damn", "hell", "kill", "die", "hate", "slur", "nazi"
    ]

    /// Relative pattern weights: mostly two-word combos, the occasional single strong word.
    static let twoWordWeight: UInt64 = 7
    static let singleWeight: UInt64 = 3

    /// Guard on the blocked-name retry loop — with clean pools this never trips, but it bounds the
    /// (impossible) worst case and yields the safe `fallbackName` rather than looping.
    static let maxAttempts = 8
    /// The guaranteed-safe name returned only if every retry were blocked (pools make this unreachable).
    static let fallbackName = "Vega"

    // MARK: - Generation

    /// The name for a given seed — pure and deterministic. Composes from the pools, screening each
    /// candidate against the `blocklist` and advancing the seed on a (curated-away) hit.
    static func name(seed: UInt64) -> String {
        var state = seed
        for _ in 0..<maxAttempts {
            let candidate = compose(&state)
            if !isBlocked(candidate) { return candidate }
        }
        return fallbackName
    }

    /// Compose one candidate name from the pools, advancing `state` as it draws. A single-word or
    /// two-word pattern is chosen by weight, then the words are drawn from the matching pools.
    private static func compose(_ state: inout UInt64) -> String {
        let pattern = nextValue(&state) % (twoWordWeight + singleWeight)
        if pattern < singleWeight {
            return draw(singles, &state)
        }
        return "\(draw(adjectives, &state)) \(draw(nouns, &state))"
    }

    /// Draw one element from `pool` using the next PRNG value (pool is never empty).
    private static func draw(_ pool: [String], _ state: inout UInt64) -> String {
        pool[Int(nextValue(&state) % UInt64(pool.count))]
    }

    /// Whether a composed name trips the blocklist — case-insensitive, whitespace-stripped substring
    /// match, so "Velvet Wolf" is screened as "velvetwolf".
    static func isBlocked(_ name: String) -> Bool {
        let folded = name.lowercased().filter { !$0.isWhitespace }
        return blocklist.contains { folded.contains($0) }
    }

    // MARK: - Seeding

    /// A **deterministic** seed derived from the player's intake answers, so the *first* offered name
    /// feels fated / theirs and is stable across launches. Order-independent in genres. Returns `nil`
    /// when nothing was declared (a fully-skipped intake) — the caller then spins from a random device
    /// seed, so a name is always on offer.
    static func seed(experience: ArtistExperience?, genres: [MusicGenre], dream: MusicalDream?) -> UInt64? {
        guard experience != nil || !genres.isEmpty || dream != nil else { return nil }
        // FNV-1a over the raw values — a *stable* hash (Swift's `Hasher` is per-run randomised, so it
        // can't seed a value meant to persist across launches).
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func fold(_ text: String) {
            for byte in text.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01b3
            }
        }
        if let experience { fold("e:" + experience.rawValue) }
        for genre in genres.map(\.rawValue).sorted() { fold("g:" + genre) }
        if let dream { fold("d:" + dream.rawValue) }
        return hash
    }

    // MARK: - PRNG

    /// One step of splitmix64 — a small, pure, well-distributed PRNG. Mutates `state` and returns the
    /// next value, so sequential draws from one seed are decorrelated (pattern, then each word).
    private static func nextValue(_ state: inout UInt64) -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
