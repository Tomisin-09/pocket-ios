import Foundation

/// The order the safety mechanisms run in (ADR 0187 D12, D13), and the only path a reading reaches
/// the screen by.
///
/// Every guard in this feature is cheap on its own. What makes them work is that they run in one
/// place, in one order, with no way to reach the screen around them — a coordinator rather than a
/// checklist in a view. `OracleView` calls this and renders what comes back; it holds no rules.
///
/// ### The order, and why each step is where it is
///
/// 1. **Distress (D13)** — decided *before* anything is sent, and its effect is that nothing is.
///    There is no version of a generated paragraph that is the right answer here, so the model is
///    never asked for one.
/// 2. **Pain (D13)** — also before the request. The reading proceeds; the routine and exercise
///    capabilities do not. Someone who wrote about their wrist has not forfeited the reflection,
///    only being handed more drills.
/// 3. **The reading** — through the `OracleReading` seam, whichever conformance is installed.
/// 4. **The tone guard (D12)** — over the returned prose, and over the Oracle's half of it only
///    (`guardedText`). A trip discards the reading **in full** and shows the local one.
///
/// The guard runs after the call rather than as a prompt instruction because a prompt instruction
/// is a request. This is a check, and it is the last thing before the player.
///
/// ### The local reading is checked too
///
/// Step 4 runs over `LocalOracle`'s output as well, not only the model's. It should never trip —
/// the suite asserts exactly that — and running it anyway costs microseconds and means the screen
/// has one contract rather than two. A guard with an exemption is a guard with a hole in it.
struct OracleCoordinator: Sendable {

    /// The seam (D4). `LocalOracle` in S1; `ProxyOracle` from S2, with this same fallback beneath.
    let oracle: any OracleReading
    /// The deterministic fallback, used for D12 trips and for any failure of `oracle`.
    let local: LocalOracle

    init(oracle: any OracleReading, local: LocalOracle = LocalOracle()) {
        self.oracle = oracle
        self.local = local
    }

    /// What the screen shows.
    enum Outcome: Equatable, Sendable {
        /// A reading. `capabilities` says which doors it may open — D13's pain branch closes them.
        case reading(OracleReadingText, capabilities: Capabilities)
        /// D13's distress branch: no model call was made, and the screen shows the fixed,
        /// human-written card with real signposting. It carries no generated text by construction.
        case distress
    }

    /// Which of the Oracle's doors this reading may open.
    ///
    /// A struct rather than a `Bool` because D13 suppresses *both* proposal capabilities together
    /// and the reading never, and because the S3 exercise door will join it here rather than as a
    /// second flag somewhere else.
    struct Capabilities: Equatable, Sendable {
        var mayProposeRoutine: Bool
        var mayProposeExercise: Bool

        static let all = Capabilities(mayProposeRoutine: true, mayProposeExercise: true)
        /// What a pain match leaves standing: the reflection, and nothing that hands over work.
        static let readingOnly = Capabilities(mayProposeRoutine: false, mayProposeExercise: false)
    }

    /// Run the pipeline.
    ///
    /// It does not throw. Every failure this feature has — an unconfigured endpoint, a refusal, an
    /// unreachable proxy, prose that trips the guard — resolves to a reading the player can read,
    /// because ADR 0092 §A2's fallback is not an error path but the ordinary one with the network
    /// removed. `signalOverride` exists for the tests and for a caller that has already scanned the
    /// prompt (D9's exercise door), so the matchers are not run twice over the same text.
    func run(context: OracleContext,
             prompt: String? = nil,
             signalOverride: OracleSafetySignal? = nil) async -> Outcome {

        let signal = signalOverride ?? OracleSafetySignal.scan(context: context, prompt: prompt)
        if signal == .distress { return .distress }
        let capabilities: Capabilities = signal == .pain ? .readingOnly : .all

        let fallback = OracleReadingText(paragraphs: local.paragraphs(for: context), source: .local)
        guard let candidate = try? await oracle.reading(for: OracleReadingRequest(context: context)) else {
            return .reading(fallback, capabilities: capabilities)
        }
        // Both guards, and both wholesale (D12, D23). They catch different faults — one grades the
        // player, the other points their attention at their own hand — and a paragraph that trips
        // either is replaced entire rather than edited, because the half that survives a redaction
        // is not reliably the harmless half.
        let clean = OracleToneGuard.passes(candidate.guardedText)
            && OracleFocusGuard.passes(candidate.guardedText)
        return .reading(clean ? candidate : fallback, capabilities: capabilities)
    }
}
