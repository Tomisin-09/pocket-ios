import SwiftUI

/// What the player was reaching for when a Pro gate presented the paywall (ADR 0112). Carried by the
/// shared `.presentPaywall` action so the paywall can show a **contextual** headline — the reason
/// this surface is locked — and so a future "resume the intent after purchase" hook has the intent.
enum PaywallTrigger: String, Identifiable, CaseIterable {
    /// The "draw your own" custom fretboard canvas — Pro even on a free-template family (ADR 0112).
    case drawYourOwn
    /// Creating a new exercise from a Pro template.
    case newExercise
    /// Opening a Pro-authored library exercise to edit it.
    case proExercise
    /// The deterministic "Today's session" planner.
    case planner
    /// A generic entry point (e.g. a "Go Pro" affordance) with no specific locked intent.
    case general

    var id: String { rawValue }

    /// The contextual line at the top of the paywall — names *why* this surface is locked.
    var headline: String {
        switch self {
        case .drawYourOwn: return "Draw your own is part of Red Moon Pro"
        case .newExercise: return "Build your own exercises with Red Moon Pro"
        case .proExercise: return "This exercise is part of Red Moon Pro"
        case .planner: return "Today's session is part of Red Moon Pro"
        case .general: return "Unlock the full practice workbench"
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
