import Foundation

/// **Whether the app may ask for an App Store review right now** (ADR 0214). The pure half:
/// Foundation-only per the "pure logic stays pure" rule (AGENTS.md), and unit-tested, for the reason
/// `PracticeReminderPlan` is — every "don't ask this time" case is silent
/// when it breaks. A prompt that fires when it shouldn't looks, on screen, exactly like a prompt that
/// fired when it should.
///
/// ## The thing that cannot be modelled here, and the shape that follows from it
///
/// `requestReview()` returns `Void`, synchronously, with no completion and no signal. iOS may draw
/// the dialog or draw nothing at all — because its own three-per-year budget is spent, because the
/// player switched in-app ratings off in Settings, because they already rated this version, or for
/// reasons Apple does not publish. **The app can never learn which happened**, at any point, ever.
///
/// So this type decides one question and only one: *did we ask?* There is no `wasShown`, no
/// `wasDismissed`, no rating, and no rule that could ever branch on one — not because we chose not
/// to, but because there is no input from which such a rule could be written.
///
/// ## Why it does not model Apple's throttle
///
/// Counting how many prompts have been *shown* this year would mean counting something unknowable,
/// and the count would drift from the truth in a direction we could never detect. Instead every gate
/// below is **strictly stricter** than Apple's: at most one ask per version, and at most one per
/// `minimumGapBetweenAsks`. Ours always binds first, so theirs stays a net we never reach. There is
/// deliberately no `asksThisYear` counter.
enum ReviewPromptPlan {

    /// Completed **sittings** — not runs — before the app may ask.
    ///
    /// A sitting, because a six-block routine writes six `PracticeRun` rows in one sit and
    /// `PracticeLog.sittings(_:gap:)` already merges them on a 30-minute gap. Counting rows would
    /// fire the ask on somebody's first evening. And a sitting only exists if a run *completed* —
    /// `PracticeLogWriter` writes nothing for a run stopped by hand — so five of them is five
    /// genuine finished pieces of work, on five occasions, usually across a week or more.
    ///
    /// Three is reachable in one determined evening either side of a coffee break. Ten is reached by
    /// a minority of installs, which trades away most of the players the ask exists to reach.
    static let sittingsBeforeAsking = 5

    /// The shortest gap between two asks. Half a year, which with a normal release cadence means the
    /// version gate below is the one that actually fires and this is the backstop.
    static let minimumGapBetweenAsks: TimeInterval = 180 * 86_400

    /// What the app did, the last time it asked.
    ///
    /// **Never "a sheet appeared".** The only honest fact available is that *we asked*, and this is
    /// the type that says so — see the note at the top of the file. Anyone extending this struct
    /// with an outcome is about to persist a number the app invented.
    ///
    /// `Codable` because it is stored as JSON under a single `UserDefaults` key, the same reason
    /// `PracticeReminderPlan.Schedule` is: the date and the version are one fact, and one key means
    /// they cannot be half-written into disagreement.
    struct Ask: Equatable, Codable {
        let askedAt: Date
        let version: String
    }

    enum Outcome: Equatable {
        case ask
        case hold(Hold)
    }

    /// Why we said nothing.
    ///
    /// A **reason**, not a `Bool`, so a test can assert *which rule fired*. ADR 0186's hardest-won
    /// lesson applies directly here: every assertion of the form "the value was stored" is green
    /// against a build that asks on every single appearance.
    enum Hold: Equatable {
        /// Something else has the screen, or is about to take it. See `HomeView+ProfileMoment`.
        case screenNotSettled
        case askedUnderThisVersion
        case askedTooRecently
        case tooFewSittings
    }

    /// Decide whether to ask.
    ///
    /// - Parameters:
    ///   - screenIsSettled: computed by the caller, because only the caller can know what is on
    ///     screen. It is a parameter rather than a lookup so the rule is visible here with the rest
    ///     of the decisions, and testable without a view.
    ///   - sittingCount: an `@autoclosure`, and **evaluated last on purpose**. It costs a SwiftData
    ///     fetch; the three cheap gates reject the overwhelming majority of appearances, so on a
    ///     normal launch nothing touches the store, and once we have asked under this build the
    ///     count is never computed again for the life of it.
    ///   - currentVersion: `CFBundleShortVersionString`. The caller passes `""` when the key cannot
    ///     be read, which holds forever — see below.
    static func decide(screenIsSettled: Bool,
                       sittingCount: @autoclosure () -> Int,
                       lastAsk: Ask?,
                       currentVersion: String,
                       threshold: Int = sittingsBeforeAsking,
                       minimumGap: TimeInterval = minimumGapBetweenAsks,
                       now: Date) -> Outcome {
        guard screenIsSettled else { return .hold(.screenNotSettled) }

        if let lastAsk {
            // The version gate is **additional**, not the trigger. Apple's own sample re-opens the
            // ask whenever the version changes; here a bump alone reopens nothing, because the gap
            // below must also have elapsed. Its job is the opposite one: to stop a *second* ask
            // under a build we already asked under.
            guard lastAsk.version != currentVersion else { return .hold(.askedUnderThisVersion) }
            // A clock moved backwards makes this negative and holds, which is the right direction to
            // fail: an ask that never happens is invisible, a double-ask is not. An unreadable
            // version stores `""` and matches `""` on the next launch, so it holds forever — also
            // conservative, also silent, and correct for a feature nobody is waiting on.
            guard now.timeIntervalSince(lastAsk.askedAt) >= minimumGap else { return .hold(.askedTooRecently) }
        }

        guard sittingCount() >= threshold else { return .hold(.tooFewSittings) }
        return .ask
    }
}
