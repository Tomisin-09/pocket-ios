import Foundation

/// The **complete, closed vocabulary** of anonymous product-analytics events (ADR 0120).
///
/// The privacy promise is enforced by the *type system*, not by code review: every associated value
/// here is another enum, an `Int` or a `Bool`. There is deliberately **no `String` parameter
/// anywhere in this type**, so emitting a song title, a file name, an artist name, a journal note or
/// any other user-authored text is structurally impossible rather than merely discouraged. A
/// SwiftLint `custom_rule` (`analytics_event_no_free_strings`) pins that shape so it can't be
/// dissolved later by someone adding "just one" string.
///
/// Two further rules the vocabulary is built around:
///
/// - **Event names are a frozen wire format.** Renaming a Swift case costs nothing; changing the
///   emitted string in `name` silently breaks continuity in the dashboard forever, because there is
///   no way to stitch the old and new series together. `AnalyticsEventTests` pins every string for
///   exactly that reason.
/// - **Nothing that grades playing** (ADR 0070). No mastery values, no achieved tempo, no accuracy.
///   Pocket does not judge how well you played and the telemetry must not create a back door to it.
///
/// The set is kept deliberately small — a ~13-event vocabulary with nothing per-beat or per-tap —
/// both because a large one goes unread and because the hosted free tier is 20k events/month.
enum AnalyticsEvent: Equatable {

    // MARK: - Engagement

    /// A practice run began. `sinceInstall` is the closest this anonymous pipeline can get to a
    /// retention curve: there is no user identifier, so bucketing each run by the age of the
    /// install is the only way to see engagement decay over time.
    case practiceStarted(kind: PracticeKind, source: PracticeSource, sinceInstall: LatencyBucket)

    /// A practice run reached its natural end (the ramp ran its full course), never a manual stop.
    ///
    /// There is deliberately no `ending:` axis. A stop can arrive by three different paths — the
    /// stop button, `onDisappear`, and leaving the screen mid-ramp — so an explicit "manual" event
    /// would double-fire or miss depending on the route. Abandonment is instead read as the gap
    /// between `practice_started` and `practice_completed`, which is a ratio of two counts and so
    /// exactly the shape the dashboard can answer.
    case practiceCompleted(kind: PracticeKind)

    // MARK: - Acquisition hook

    /// A song-import batch completed. Counts only — **never** `failedNames`, which are the user's
    /// own file names.
    case songImported(count: Int, failed: Int)

    /// A Toolkit surface was opened. Fired once per entry, never on every re-appearance.
    case toolOpened(tool: Tool)

    /// A loop was created on the waveform — the slow-downer's core action, and the event that
    /// tests whether it really is the strongest acquisition hook.
    case loopCreated

    // MARK: - Authoring

    case exerciseCreated(template: ExerciseTemplate, instrument: Instrument)

    /// The create sheet was opened and dismissed without creating anything. `template` is `nil` when
    /// the player abandoned before even choosing one.
    case exerciseAuthoringAbandoned(template: ExerciseTemplate?)

    /// A routine was saved for the first time. `generated` separates a hand-built routine from one
    /// produced by the collection/session generator.
    case routineCreated(items: Int, generated: Bool)

    // MARK: - Monetization

    /// A Pro gate presented the paywall. The trigger names *which* surface was locked — the single
    /// highest-value question this pipeline answers, because it is the evidence behind every
    /// free-vs-Pro boundary decision.
    case paywallShown(trigger: PaywallTrigger)

    case paywallDismissed(trigger: PaywallTrigger, purchased: Bool)

    case purchaseCompleted(product: SubscriptionProduct, trial: Bool)

    /// A restore finished. `restored` is false when the restore found no entitlement — the
    /// difference between "restore works" and "restore is being tried and failing".
    case restoreCompleted(restored: Bool)

    // MARK: - Health

    /// The outcome of a microphone permission request. Both the tuner and recording are dead ends
    /// without it, so a denial rate is a real product problem rather than a curiosity.
    case micPermission(outcome: MicOutcome)
}

// MARK: - Wire format

extension AnalyticsEvent {

    /// The event name as sent. **Frozen** — see the type's doc comment.
    var name: String {
        switch self {
        case .practiceStarted: return "practice_started"
        case .practiceCompleted: return "practice_completed"
        case .songImported: return "song_imported"
        case .toolOpened: return "tool_opened"
        case .loopCreated: return "loop_created"
        case .exerciseCreated: return "exercise_created"
        case .exerciseAuthoringAbandoned: return "exercise_authoring_abandoned"
        case .routineCreated: return "routine_created"
        case .paywallShown: return "paywall_shown"
        case .paywallDismissed: return "paywall_dismissed"
        case .purchaseCompleted: return "purchase_completed"
        case .restoreCompleted: return "restore_completed"
        case .micPermission: return "mic_permission"
        }
    }

    /// The event's properties. Pure, and the **only** place in the app where an analytics string is
    /// constructed — every text value is an enum's `rawValue`, never caller-supplied.
    var payload: [String: AnalyticsValue] {
        switch self {
        case let .practiceStarted(kind, source, sinceInstall):
            return ["kind": .text(kind.rawValue),
                    "source": .text(source.rawValue),
                    "since_install": .text(sinceInstall.rawValue)]

        case let .practiceCompleted(kind):
            return ["kind": .text(kind.rawValue)]

        case let .songImported(count, failed):
            return ["count": .number(count),
                    "failed": .number(failed)]

        case let .toolOpened(tool):
            return ["tool": .text(tool.rawValue)]

        case .loopCreated:
            return [:]

        case let .exerciseCreated(template, instrument):
            return ["template": .text(template.rawValue),
                    "instrument": .text(instrument.rawValue)]

        case let .exerciseAuthoringAbandoned(template):
            // `nil` is its own signal — abandoned before choosing a template at all.
            return ["template": .text(template?.rawValue ?? "none")]

        case let .routineCreated(items, generated):
            return ["items": .number(items),
                    "generated": .flag(generated)]

        // Two axes, not one composite string: `trigger` stays the coarse six-way "which capability
        // was locked" and `detail` narrows it to the template or routine action, so the dashboard
        // can break down at either level.
        case let .paywallShown(trigger):
            return ["trigger": .text(trigger.reportingName),
                    "detail": .text(trigger.reportingDetail ?? "none")]

        case let .paywallDismissed(trigger, purchased):
            return ["trigger": .text(trigger.reportingName),
                    "detail": .text(trigger.reportingDetail ?? "none"),
                    "purchased": .flag(purchased)]

        case let .purchaseCompleted(product, trial):
            return ["product": .text(product.rawValue),
                    "trial": .flag(trial)]

        case let .restoreCompleted(restored):
            return ["restored": .flag(restored)]

        case let .micPermission(outcome):
            return ["outcome": .text(outcome.rawValue)]
        }
    }
}

/// A property value. Numbers stay numeric so the dashboard can aggregate them; `.text` carries
/// **enum raw values only**, which is what keeps the vocabulary closed.
enum AnalyticsValue: Equatable {
    case text(String)
    case number(Int)
    case flag(Bool)
}

// MARK: - Property vocabularies
//
// Small, closed, `String`-raw enums. Their raw values are part of the frozen wire format too.

/// What kind of thing was practised.
enum PracticeKind: String, CaseIterable {
    case exercise
    case loop
    case earLoop = "ear_loop"
    case routine
    case song
}

/// Where the run was started from — a standalone tap, or as a block inside a routine.
///
/// There is no `planner` case: a planner session materialises an ordinary `Routine` and plays
/// through `RoutinePlayerView` like any other, so nothing at the run site could distinguish it and
/// the case could never be emitted. Planner interest is already legible from
/// `routine_created(generated: true)` and `paywall_shown(trigger: planner)`.
enum PracticeSource: String, CaseIterable {
    case standalone
    case routine
}

/// The age of the install when something happened, bucketed. Never a raw date or duration.
enum LatencyBucket: String, CaseIterable {
    case day1 = "day_1"
    case week1 = "week_1"
    case month1 = "month_1"
    case later

    /// Bucket an install age. Negative intervals (a clock moved backwards) resolve to `.day1`
    /// rather than trapping — a wrong bucket is better than a crash in telemetry.
    init(installAge: TimeInterval) {
        let days = installAge / 86_400
        switch days {
        case ..<1: self = .day1
        case ..<7: self = .week1
        case ..<30: self = .month1
        default: self = .later
        }
    }
}

/// A Toolkit surface.
enum Tool: String, CaseIterable {
    case tuner
    case metronome
    case earTraining = "ear_training"
    case recording
}

/// Which Red Moon Pro product was bought.
enum SubscriptionProduct: String, CaseIterable {
    case monthly
    case annual
}

/// The outcome of a microphone permission request.
enum MicOutcome: String, CaseIterable {
    case granted
    case denied
}
