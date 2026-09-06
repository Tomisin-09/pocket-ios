import Foundation

/// Pain and distress, matched **on the device and before the request** (ADR 0187 D13).
///
/// Two deterministic matchers, Foundation-only, run over the journal excerpt and — when there is
/// one — the player's prompt, *before* anything is sent. Neither asks a model what it thinks; that
/// is the whole design. A model asked to respond to an injury will respond to an injury.
///
/// ### The honest caveat, recorded rather than glossed
///
/// A keyword matcher has false negatives and always will. Somebody will write "my hand is killing
/// me" and this will not fire. **It is a floor, not a guarantee.** What actually bounds the harm is
/// D7–D12: the Oracle cannot prescribe, cannot extend a session, cannot set a tempo, and cannot be
/// talked to. If this file is ever cited as the reason something is safe, that citation is wrong,
/// and the person making it should read this paragraph instead.
///
/// ### Both fail towards the safe branch
///
/// On ambiguity, they fire. A guitarist writes "wrist" innocuously — *wrist position*, *wrist
/// vibrato* — and this treats it as pain. That is a deliberately cheap mistake: the cost is a
/// reading without a routine proposal and one fixed line of copy, which is a mild outcome, and the
/// cost of the opposite mistake is a practice plan handed to someone whose tendon hurts.
enum OracleSafetySignal: Equatable, Sendable {

    /// Nothing matched. The reading proceeds normally.
    case none

    /// Pain or strain language. **Effect:** the routine and exercise capabilities are suppressed
    /// for this reading, and a fixed, owner-written, non-diagnostic line is shown. The reading
    /// itself still happens — someone who wrote about their wrist has not forfeited the reflection,
    /// they have forfeited being handed more drills.
    case pain

    /// Self-worth, giving-up and hopelessness language. **Effect: the model is not called at all.**
    /// A fixed, human-written card with real signposting is shown instead. No token is spent and no
    /// paragraph is generated, because there is no version of a generated paragraph that is the
    /// right answer to this.
    case distress

    /// Scan every piece of player text going into one request.
    ///
    /// **Distress outranks pain**, and outranks it before either is reported: a single finding is
    /// returned rather than a set, because the two have different effects and the more protective
    /// one has to win outright rather than be merged with the other.
    static func scan(_ texts: [String]) -> OracleSafetySignal {
        let tokens = texts.flatMap { OracleWordMatch.tokenise($0) }
        guard !tokens.isEmpty else { return .none }
        if isDistress(tokens: tokens) { return .distress }
        if isPain(tokens: tokens) { return .pain }
        return .none
    }

    /// Convenience for the common shape: the notes in a built context, plus an optional prompt.
    static func scan(context: OracleContext, prompt: String? = nil) -> OracleSafetySignal {
        var texts = context.notes.map(\.text)
        if let prompt { texts.append(prompt) }
        return scan(texts)
    }

    // MARK: - Pain

    /// The words D13 names, plus the obvious inflections. Bare words rather than phrases, because
    /// the consequence is mild and the miss is what costs.
    static let painWords: Set<String> = [
        "pain", "painful", "hurts", "hurting", "hurt", "sore", "soreness",
        "ache", "aches", "aching", "achy",
        "wrist", "wrists", "tendon", "tendons", "tendonitis", "tendinitis",
        "tingling", "tingle", "numb", "numbness", "rsi", "strain", "strained",
        "inflamed", "inflammation", "cramping", "cramps"
    ]

    static let painPhrases: [[String]] = [
        ["carpal", "tunnel"], ["pins", "and", "needles"], ["trigger", "finger"]
    ]

    static func isPain(tokens: [String]) -> Bool {
        OracleWordMatch.firstWord(painWords, in: tokens) != nil
            || OracleWordMatch.firstPhrase(painPhrases, in: tokens) != nil
    }

    // MARK: - Distress

    /// Mostly **phrases**, unlike the pain table, and the asymmetry is deliberate.
    ///
    /// The consequence here is the heavier one — no model call, and a card about where to get help
    /// — so a false positive is genuinely jarring rather than merely quiet. Phrases carry enough
    /// context to be worth acting on; the bare words that would fire on a bad practice day
    /// ("useless", "failing", "hate") are not in the single-word table for exactly that reason.
    static let distressPhrases: [[String]] = [
        ["giving", "up"], ["give", "up"], ["gave", "up"],
        ["no", "point"], ["whats", "the", "point"], ["what", "is", "the", "point"],
        ["waste", "of", "time"], ["wasting", "my", "time"],
        ["not", "good", "enough"], ["never", "be", "good", "enough"],
        ["hate", "myself"], ["hate", "my", "playing"],
        ["cant", "do", "this"], ["cannot", "do", "this"],
        ["why", "bother"], ["never", "get", "there"], ["never", "going", "to", "get"],
        ["should", "just", "quit"], ["want", "to", "quit"], ["packing", "it", "in"],
        ["dont", "want", "to", "be", "here"], ["end", "it"]
    ]

    /// The few single words strong enough to stand alone.
    static let distressWords: Set<String> = [
        "worthless", "hopeless", "pointless", "despair", "suicidal"
    ]

    static func isDistress(tokens: [String]) -> Bool {
        OracleWordMatch.firstWord(distressWords, in: tokens) != nil
            || OracleWordMatch.firstPhrase(distressPhrases, in: tokens) != nil
    }
}
