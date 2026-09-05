import Foundation

/// The one seam the Oracle is reached through (ADR 0187 D4).
///
/// Modelled on `SupportSending` (`SupportSender.swift:44-46`) and hired for the same job it states:
/// *"replacing it is a second conformance and a different URL. No view, no test and no ADR has to
/// move."* `Sendable` and free of the main actor, because the call is awaited off the main thread
/// and the only main-actor work is the state the screen flips when it returns.
///
/// ### Why the reading is its own protocol
///
/// D4 splits reading from structured proposal rather than merging them, and the split is not
/// tidiness. The two capabilities have different fallbacks, different quota costs and different
/// on-device feasibility: an Apple Foundation Models conformance will plausibly write a reflective
/// paragraph long before it emits schema-valid structured output. Merged, the weaker half would
/// hold the stronger one back.
///
/// **`OracleRoutineSuggesting`, the second protocol, is not here yet.** It lands with S3, where its
/// first conformance exists — there is no structured output to validate until then, and a protocol
/// with no conformer is a shape nobody has had to satisfy. Its contract is already fixed by D7: it
/// returns `[SessionBlock]`, never a `Routine`, and goes through the shipped
/// `PracticePlanner.materialise`.
///
/// Conformances, in the order they arrive: `LocalOracle` (S1, and the ADR 0092 §A2 deterministic
/// fallback), `RecordingOracle` (tests and previews), `ProxyOracle` (S2), and later an
/// `OnDeviceOracle` that must be `#if canImport(FoundationModels)`-fenced and **not**
/// `#available`-gated — `HomeView.swift:126-128` records why: the symbol is absent on CI's Xcode 16
/// and a runtime check cannot save you from a missing symbol.
protocol OracleReading: Sendable {
    func reading(for request: OracleReadingRequest) async throws -> OracleReadingText
}

/// Everything a reading is asked from.
///
/// **It carries no free text, and that absence is a mechanism** (ADR 0187 D9). The prompt box the
/// owner asked for exists on the exercise-suggestion capability only; putting one here would mean
/// widening this signature, which is the ADR 0186 D1 trick of making the wrong thing structurally
/// awkward rather than merely forbidden. A future author who wants to thread a question into a
/// reading has to change a type that says this in its doc comment first.
struct OracleReadingRequest: Codable, Equatable, Sendable {
    let context: OracleContext
}

/// A reading, as prose.
///
/// Paragraphs rather than one string, because the screen sets them with space between them and
/// joining-then-splitting on newlines is a round trip that loses to the first note containing a
/// blank line.
struct OracleReadingText: Equatable, Sendable {

    let paragraphs: [Paragraph]
    let source: Source

    /// One paragraph, and whether the Oracle wrote it.
    ///
    /// ### The distinction the tone guard depends on
    ///
    /// A reading is at its best when it hands the player their own words back — that is what "a
    /// mirror that cannot grade you" means literally. But a player writes things about themselves
    /// that D12's table exists to catch: *"fell off this week"*, *"stalled on the bend again"*.
    /// Running the guard over a quoted note would reject the reading for something **the player
    /// said about themselves**, and the app would end up refusing to show someone their own
    /// journal.
    ///
    /// So the rule is: **the player may judge themselves; the app may not judge them.** Quoting is
    /// not the app saying it. `isQuotedFromPlayer` carries that on the value rather than in a
    /// convention, so `guardedText` can be the only thing D12 reads and no future caller has to
    /// remember the distinction.
    struct Paragraph: Equatable, Sendable {
        let text: String
        let isQuotedFromPlayer: Bool

        init(_ text: String, isQuotedFromPlayer: Bool = false) {
            self.text = text
            self.isQuotedFromPlayer = isQuotedFromPlayer
        }
    }

    /// Where the prose came from. Surfaced because the screen says so plainly: a reading written on
    /// the device and a reading written by a model are different things, and letting the player
    /// assume the second when they have the first would be the kind of small lie that makes the
    /// rest of the app's promises harder to believe.
    enum Source: String, Equatable, Sendable, CaseIterable {
        /// `LocalOracle` — deterministic, on-device, no network (ADR 0092 §A2).
        case local
        /// A model, through the proxy.
        case model
    }

    /// Everything the Oracle itself wrote — **the only text `OracleToneGuard` reads**.
    var guardedText: String {
        paragraphs.filter { !$0.isQuotedFromPlayer }.map(\.text).joined(separator: "\n\n")
    }

    /// The whole reading, for the accessibility label and for the screen.
    var joined: String { paragraphs.map(\.text).joined(separator: "\n\n") }
}

/// A reading that was never asked for, and why.
///
/// D13's two branches are outcomes of this feature, not errors in it: a distress match is handled
/// by *not calling the model*, which is a success of the design and must not surface as a failure.
/// Anthropic's `stop_reason: "refusal"` (D10) joins them from S2 for the same reason — a normal
/// path with a plain message, never a crash and never a retry loop.
enum OracleUnavailable: Equatable, Sendable {
    /// No proxy address in this build (`OracleEndpoint.isConfigured` is `false`) — the Release
    /// state until S4, and the state every build is in during S1.
    case notConfigured
    /// The model declined. Shown plainly, with the local reading in its place.
    case refused
    /// The network failed, or the request did.
    case unreachable
}
