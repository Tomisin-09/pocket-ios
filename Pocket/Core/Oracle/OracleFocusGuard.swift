import Foundation

/// The second guard (ADR 0187 D23): the Oracle never phrases an instruction at the body.
///
/// `OracleToneGuard` catches **verdicts** — sentences that grade the player. This catches the other
/// way copy can work against them, which is **where the sentence points their attention**.
///
/// ### Why a guard and not a style note
///
/// Wulf's external-focus findings are among the most replicated results in motor learning: an
/// instruction directed at the *effect* — the sound, the string, the note ringing — produces better
/// immediate performance **and** better retention than the same instruction directed at the body
/// part producing it. *"Let the note ring cleanly"* and *"curl your finger more"* ask for the same
/// thing and do not produce the same result. This is the one place the app's own words touch what
/// the player attends to while playing, and therefore what they retain.
///
/// Same family as D12, `.swiftlint.yml`'s two custom rules and `check-manual.py`'s C7: pure,
/// table-driven, Foundation-only, and sharing `OracleWordMatch`'s tokeniser rather than writing a
/// second one. A rule in a system prompt is a request; this is a check.
///
/// ### It rejects wholesale, exactly as D12 does
///
/// A tripped reading is discarded in full and the `LocalOracle` fallback shown in its place. Scope
/// is **every sentence the Oracle addresses to the player**: reading paragraphs, the single
/// rationale line D9 allows on an exercise proposal, a goal restatement, and any explanation of a
/// generated session. D9's rationale is where this bites first, and is why the guard could not wait
/// for the reading to go live — a one-line rationale on a drill is precisely the sentence most
/// likely to reach for a finger.
///
/// ### The exemption already exists, and is structural
///
/// A player writing *"my wrist hurts"* must pass through untouched. That is not a table entry here:
/// `OracleReadingText.guardedText` never hands this guard a paragraph marked
/// `isQuotedFromPlayer`, and genuine pain is D13's branch, not a guard's. What the tables below do
/// instead is refuse to fire on a **bare** body noun — only on one inside an instruction.
enum OracleFocusGuard {

    /// What tripped, so a test can assert *which* rule fired and a rejection can be counted without
    /// the phrase itself ever being logged. Mirrors `OracleToneGuard.Trip` deliberately: two guards
    /// with the same job report it the same way.
    struct Trip: Equatable, Sendable {
        /// The body noun the sentence pointed at.
        let bodyWord: String
        /// The instruction that pointed at it — a cue verb, or `your` for the possessive form.
        let cue: String
    }

    /// Body parts a guitarist has. Matched as whole tokens, never substrings.
    ///
    /// **Four obvious members are deliberately absent, and each is a guitar part before it is a
    /// body part**: `neck`, `body`, `arm` (a tremolo arm) and `back`. A guard that fires on *"go
    /// back to the top of the neck"* would reject readings for saying something entirely correct,
    /// and unlike D12 — where false positives are the cheap direction — the sentences this guard
    /// protects are the ones that name what the player should attend to. `hand` stays in, because
    /// *"your fretting hand"* is the exact construction Wulf's findings are about, and it only ever
    /// fires inside an instruction.
    static let bodyWords: Set<String> = [
        "finger", "fingers", "fingertip", "fingertips", "thumb", "thumbs",
        "wrist", "wrists", "elbow", "elbows", "shoulder", "shoulders",
        "knuckle", "knuckles", "forearm", "forearms", "palm", "palms",
        "pinky", "pinkie", "hand", "hands", "posture"
    ]

    /// Verbs that make the words after them an instruction.
    ///
    /// `bend` is **not** here and must not be added: bending a string is the technique, and
    /// *"the bend in bar 9"* is the app naming a thing the player did. Nor is `play`, for the same
    /// reason. What is here is the vocabulary of positioning a body — the sentences that would send
    /// attention inwards.
    static let instructionCues: Set<String> = [
        "curl", "curled", "curling", "relax", "relaxed", "relaxing",
        "loosen", "loosened", "tighten", "tightened", "arch", "arched",
        "straighten", "straightened", "flatten", "flattened", "rotate", "rotated",
        "squeeze", "squeezing", "anchor", "anchored", "press", "pressing",
        "lift", "lifting", "plant", "planted", "position", "reposition",
        "keep", "hold", "place", "angle"
    ]

    /// How far back from a body noun `your` still binds to it.
    ///
    /// Two tokens, so *"your fretting hand"* and *"your first finger"* are caught and a `your`
    /// belonging to some other noun a clause away is not.
    static let possessiveReach = 2

    /// Sentence terminators. The instruction context is a **sentence**, not a token window.
    ///
    /// A window was the first design and was wrong: *"Press down with the very tip of the index
    /// finger"* puts nine tokens between the verb and the noun it governs, and any window wide
    /// enough for that reaches across a full stop into the next thought. A sentence is the unit an
    /// instruction actually occupies, and it is the unit a reader parses it in.
    static let sentenceBreaks: Set<Character> = [".", "!", "?", "\n", ";", ":"]

    /// The first trip, or `nil` when the prose points outwards.
    ///
    /// First rather than all, for `OracleToneGuard`'s reason: the caller's only decision is
    /// reject-or-not, and collecting every fault in a paragraph about to be thrown away is work
    /// nobody reads.
    static func check(_ text: String) -> Trip? {
        for sentence in text.split(whereSeparator: { sentenceBreaks.contains($0) }) {
            let tokens = OracleWordMatch.tokenise(String(sentence))
            guard let trip = trip(in: tokens) else { continue }
            return trip
        }
        return nil
    }

    /// Whether the prose is safe to show. The whole guard, as one question.
    static func passes(_ text: String) -> Bool { check(text) == nil }

    // MARK: - Matching

    /// One sentence's verdict: a body noun, and the instruction it sits inside.
    ///
    /// Two forms, and the possessive is the sharper of them. *"your wrist"* is a sentence about the
    /// player's own body no matter which verb governs it, and one intervening adjective is allowed
    /// so *"your fretting hand"* and *"your first finger"* are caught. A cue verb anywhere in the
    /// same sentence covers the rest.
    ///
    /// Every body noun in the sentence is tried, not only the first: *"the tone is in the hands,
    /// so relax your shoulder"* must trip on the second one after the first turns out to be bare.
    ///
    /// `my` and `me` are **not** possessives here. The app never writes them about a player, so a
    /// sentence containing one is either quoted — in which case `guardedText` has already removed
    /// it — or is the Oracle writing in a voice it does not have.
    private static func trip(in tokens: [String]) -> Trip? {
        let bodyIndices = tokens.indices.filter { bodyWords.contains(tokens[$0]) }
        guard !bodyIndices.isEmpty else { return nil }

        for index in bodyIndices
        where tokens[max(0, index - possessiveReach)..<index].contains("your") {
            return Trip(bodyWord: tokens[index], cue: "your")
        }
        guard let cue = tokens.first(where: { instructionCues.contains($0) }),
              let body = bodyIndices.first else { return nil }
        return Trip(bodyWord: tokens[body], cue: cue)
    }
}
