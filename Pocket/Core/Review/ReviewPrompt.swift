import Foundation

/// **The App Store review ask** (ADR 0214) — the impure half, holding only what a test cannot: the
/// stored record of whether we have already asked, and the call out to the system.
///
/// An `enum` with one static seam rather than an `@Observable` class, following `PracticeLogWriter`
/// rather than `PracticeReminder`. `PracticeReminder` earns its class because a `body` reads
/// `schedule(for:)` and must be invalidated when it changes; nothing observes this, no view reads its
/// state, and it has no lifetime — so a class in the environment would be four lines of ceremony
/// around a `UserDefaults` read.
///
/// ## The action is passed in, never reached for
///
/// `RequestReviewAction` only exists inside a live SwiftUI environment, and a unit test has none.
/// Holding one here would also be ADR 0186 D4's `usesSystemNotifications` trap in a new costume: the
/// SDK *does* declare `RequestReviewAction: Sendable`, so the compiler would let you store it, and
/// the value you kept would be a handle to an environment that has since been rebuilt. So the caller
/// reads `@Environment(\.requestReview)` in its own `body` scope and hands the call down as `ask:`.
///
/// ## One key, and no `@AppStorage` anywhere
///
/// The record lives under a single key owned by this type, the way `PracticeReminder.Key` does — `AppSettings` sits 16 lines under SwiftLint's file cap and does not
/// need three more. Because no view declares an `@AppStorage` for this feature, the default-literal
/// duplication trap (`AppSettings`, "the literal does not mirror the accessor") cannot arise here at
/// all: there is no second site for a default to drift into.
@MainActor
enum ReviewPrompt {

    /// One key holding a JSON `Ask`, for the reason `PracticeReminder` stores a `Schedule` that way:
    /// the date and the version are one fact, and one key means they cannot be half-written into
    /// disagreement.
    private static let storageKey = "reviewPromptLastAsk"

    /// Ask for a review if every gate in `ReviewPromptPlan` passes.
    ///
    /// - Parameters:
    ///   - screenIsSettled: see `HomeView+ProfileMoment`. Only the caller can know this.
    ///   - sittingCount: an `@autoclosure`, evaluated only if the cheap gates pass. It costs a
    ///     SwiftData fetch.
    ///   - ask: what actually raises the system prompt — `{ requestReview() }` at the call site, a
    ///     counter in a test. See the type doc for why it is not stored.
    /// - Returns: the decision, so a caller — and a test — can assert *what was decided* rather than
    ///   merely that something was written. ADR 0186's lesson: "the value was stored" is green
    ///   against a build that asks every time.
    @discardableResult
    static func askIfDue(screenIsSettled: Bool,
                         sittingCount: @autoclosure () -> Int,
                         version: String = currentVersion,
                         now: Date = .now,
                         defaults: UserDefaults = .standard,
                         ask: () -> Void) -> ReviewPromptPlan.Outcome {
        let outcome = ReviewPromptPlan.decide(screenIsSettled: screenIsSettled,
                                              sittingCount: sittingCount(),
                                              lastAsk: lastAsk(in: defaults),
                                              currentVersion: version,
                                              now: now)
        guard case .ask = outcome else { return outcome }

        // Recorded **before** the call, not after, and the ordering is load-bearing twice over. We
        // can never learn whether a sheet appeared, so the only honest record is "the app asked" —
        // a fact about our own action, produced by the code that takes it. And writing first means a
        // crash inside the system call cannot leave us able to ask a second time.
        record(ReviewPromptPlan.Ask(askedAt: now, version: version), in: defaults)
        Analytics.send(.reviewRequested(trigger: .sittings))
        ask()
        return outcome
    }

    /// The marketing version, or `""` when the key cannot be read — which makes the plan hold for
    /// good rather than ask on every appearance. Deliberately conservative: nobody is waiting on this
    /// prompt, and a silent absence is cheaper than a repeat.
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private static func lastAsk(in defaults: UserDefaults) -> ReviewPromptPlan.Ask? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(ReviewPromptPlan.Ask.self, from: data)
    }

    private static func record(_ ask: ReviewPromptPlan.Ask, in defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(ask) else { return }
        defaults.set(data, forKey: storageKey)
    }

    #if DEBUG
    /// Clear the record, so a Simulator pass can see the prompt more than once. Debug-only: there is
    /// no player-facing way to reset this, and there should not be — a "let me be asked again"
    /// control is a re-ask mechanism with better manners.
    static func resetForTesting(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
    #endif
}
