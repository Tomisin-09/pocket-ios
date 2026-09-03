import SwiftUI

/// What the player was reaching for when a Pro gate presented the paywall (ADR 0112). Carried by the
/// shared `.presentPaywall` action so the paywall can show a **contextual** headline — the reason
/// this surface is locked — and so a future "resume the intent after purchase" hook has the intent.
/// Which routine surface a `.routine` gate fired from. Five distinct actions previously collapsed
/// into one trigger, which made "routines are hitting the wall" legible but not *why* — building one
/// and merely playing one are very different pieces of evidence about where the free line belongs.
enum RoutineGate: String, CaseIterable, Equatable {
    case new
    case play
    case edit
    case duplicate
    /// Accepting a session generated from a collection, a song, or the quick-session wand.
    case generate
    /// Opening a routine somebody else shared (ADR 0188 S2) — either door. Its own case rather than
    /// folded into `new`, because it is the one routine gate the player did not walk up to: a tapped
    /// file arrives, and a wall in front of a teacher's handover is very different evidence about
    /// where the free line belongs from a wall in front of an empty editor.
    case receive
}

/// Which locked **top-level Home destination** a `.home` gate fired from (ADR 0144 D4). The Toolkit
/// **and the Journal** are deliberately absent: they are the free surface (ADR 0144 D2) and are never
/// gated, so there is no trigger that could name them.
enum HomeGate: String, CaseIterable, Equatable {
    case practice
    case library
    /// The "Jump back in" card — resuming the last-practised song's waveform.
    case song
    /// A card in the "Recent routines" rail.
    case routine

    /// The contextual paywall line for this destination — names the *place* that's locked, since
    /// that's what the player just tapped.
    var headline: String {
        switch self {
        case .practice: return "Practice is part of Red Moon Pro"
        case .library: return "Your song library is part of Red Moon Pro"
        case .song: return "Practising along to your songs is part of Red Moon Pro"
        case .routine: return "Routines are part of Red Moon Pro"
        }
    }
}

enum PaywallTrigger: Identifiable, Equatable {
    /// The "draw your own" custom fretboard canvas — Pro even on a free-template family (ADR 0112).
    case drawYourOwn
    /// Creating a new exercise from a Pro template. Carries **which** template was reached for where
    /// the gate knows it (the template picker); `nil` from gates that don't, like forking a drill.
    case newExercise(ExerciseTemplate?)
    /// Opening a Pro-authored library exercise to edit it.
    case proExercise
    /// The deterministic "Today's session" planner.
    case planner
    /// Any routine surface — running a Pro routine, building one by hand, or accepting a session
    /// generated from a collection or a song. Routines are Pro apart from the curated free taste.
    case routine(RoutineGate)
    /// A locked **top-level Home destination** (ADR 0144 D4) — the coarse wall above the individual
    /// gates. Carries which card was reached for, because with the whole app Pro this is now the
    /// highest-volume gate in the app and "they hit the wall" alone would say nothing about intent.
    case home(HomeGate)
    /// The **once-per-launch** paywall shown to a player without Pro (ADR 0144 D4). Not reached for —
    /// it comes to them — which is why it is its own trigger rather than `.general`: a dismissal here
    /// is a very different signal from dismissing a wall you walked into.
    case launch
    /// A generic entry point (e.g. a "Go Pro" affordance) with no specific locked intent.
    case general

    /// Distinguishes sheets so a gate for a different intent re-presents rather than being treated
    /// as the same item. Detail is part of identity for that reason.
    var id: String {
        guard let detail = reportingDetail else { return reportingName }
        return "\(reportingName).\(detail)"
    }

    /// The contextual line at the top of the paywall — names *why* this surface is locked.
    ///
    /// Deliberately unchanged by the new detail: the copy speaks to the *capability* being sold, and
    /// "Build your own scales exercises" would be a narrower promise than Pro actually makes. The
    /// detail exists for reporting, not for the pitch.
    var headline: String {
        switch self {
        case .drawYourOwn: return "Draw your own is part of Red Moon Pro"
        case .newExercise: return "Build your own exercises with Red Moon Pro"
        case .proExercise: return "This exercise is part of Red Moon Pro"
        case .planner: return "Today's session is part of Red Moon Pro"
        case .routine: return "Routines are part of Red Moon Pro"
        case let .home(gate): return gate.headline
        case .launch: return "Your practice workbench, unlocked"
        case .general: return "Unlock the full practice workbench"
        }
    }

    // MARK: - Reporting (ADR 0120)
    //
    // Two axes rather than one composite string, so the dashboard can break down at either level:
    // `trigger` stays the coarse six-way answer to "which capability was locked", and `detail`
    // narrows it to the template or routine action. Both are closed vocabularies.

    /// The coarse trigger name. Frozen wire format — see `AnalyticsEvent`.
    var reportingName: String {
        switch self {
        case .drawYourOwn: return "draw_your_own"
        case .newExercise: return "new_exercise"
        case .proExercise: return "pro_exercise"
        case .planner: return "planner"
        case .routine: return "routine"
        case .home: return "home"
        case .launch: return "launch"
        case .general: return "general"
        }
    }

    /// What specifically was reached for, where the gate knows it.
    var reportingDetail: String? {
        switch self {
        case let .newExercise(template): return template?.rawValue
        case let .routine(gate): return gate.rawValue
        case let .home(gate): return gate.rawValue
        case .drawYourOwn, .proExercise, .planner, .launch, .general: return nil
        }
    }
}

/// Preview-safe environment plumbing for the paywall (ADR 0112). Gates read `\.isPro` and
/// `\.presentPaywall` rather than reaching for `StoreManager` directly, so:
/// - a view under test / in an Xcode preview renders as **free** with a **no-op** paywall (safe
///   defaults) instead of trapping on a missing `@Observable` in the environment, and
/// - only `PaywallView` and the Settings debug controls depend on `StoreManager` itself.
/// The app root (`PaywallHost`) bridges the live `StoreManager` into these two values.
private struct IsProKey: EnvironmentKey {
    static let defaultValue = false
}

private struct PresentPaywallKey: EnvironmentKey {
    // `@MainActor`-isolated so the function type is `Sendable` (concurrency-safe as a static default);
    // gates only ever call it from the main-actor view context anyway.
    static let defaultValue: @MainActor (PaywallTrigger) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Whether the player currently holds Red Moon Pro. Defaults to `false` (free) when no
    /// `StoreManager` is bridged in — the safe default for previews/tests.
    var isPro: Bool {
        get { self[IsProKey.self] }
        set { self[IsProKey.self] = newValue }
    }

    /// Present the paywall for a given trigger. Defaults to a no-op so a gate in a preview does
    /// nothing rather than crashing. `@MainActor` — mutating view state from a view action.
    var presentPaywall: @MainActor (PaywallTrigger) -> Void {
        get { self[PresentPaywallKey.self] }
        set { self[PresentPaywallKey.self] = newValue }
    }
}
