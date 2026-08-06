import Foundation

/// The analytics-related slice of `AppSettings` (ADR 0120, region-split by ADR 0147), split out to
/// keep `AppSettings.swift` inside SwiftLint's 400-line file cap.
///
/// These read through `resolvedBool` rather than the parent file's `bool` helper, which is `private`
/// and so invisible across a file boundary. `resolvedBool` is the same rule — and it is the pure,
/// unit-tested one — so nothing is lost and no access level had to be widened to make room.
extension AppSettings {

    /// Anonymous product analytics on/off.
    ///
    /// **The default here is a backstop, not the policy.** `seedAnalyticsDefaultIfNeeded` writes the
    /// key explicitly on first launch, so by the time anything reads this the key is present and the
    /// fallback is unreachable. That is the point: the correct value is `false` in the EEA (ePrivacy
    /// Art 5(3) — consent) and `true` in the UK and rest of world (DUAA 2025 Sch A1 para 5 — inform
    /// and object), and one hardcoded default cannot express both. It stays `false` so that an
    /// unreachable default still fails in the safe direction.
    static var analyticsEnabled: Bool {
        resolvedBool(storedValue: UserDefaults.standard.object(forKey: Key.analyticsEnabled),
                     default: false)
    }

    /// Whether the player has been told about analytics — by the intake footnote under `.notify`, or
    /// by the consent sheet under `.ask` (ADR 0147; this was `analyticsPromptSeen` under ADR 0120,
    /// when being *told* and being *asked* were the same event).
    ///
    /// **The stored key string is still `"analyticsPromptSeen"`.** Renaming the accessor is free;
    /// renaming the key would strand every existing install and owe a migration for nothing.
    static var analyticsDisclosureSeen: Bool {
        resolvedBool(storedValue: UserDefaults.standard.object(forKey: Key.analyticsPromptSeen),
                     default: false)
    }

    /// Write the regional analytics default once, on first launch (ADR 0147 §3).
    ///
    /// The alternative — flipping a single `default:` and updating the two views that each declare
    /// their own `@AppStorage(...) = false` — needs **three** defaults to agree, with no compiler
    /// help. Get it wrong and Settings ▸ Privacy shows an **off** toggle to somebody who is actually
    /// **on**: the privacy control lying about the privacy state, which is worse than either value on
    /// its own. Seeding the key removes the disagreement instead of managing it, and afterwards no
    /// `default:` anywhere is load-bearing.
    ///
    /// **The `guard` is what protects an explicit decline.** Anyone who tapped "No thanks" under
    /// ADR 0120 has the key present and `false`, so this no-ops and they stay off permanently. Both
    /// directions of that no-op are pinned by tests; the `false` one is the case that must never
    /// regress.
    static func seedAnalyticsDefaultIfNeeded(model: AnalyticsPolicy.ConsentModel,
                                             store: UserDefaults = .standard) {
        guard store.object(forKey: Key.analyticsEnabled) == nil else { return }
        store.set(model == .notify, forKey: Key.analyticsEnabled)
    }
}
