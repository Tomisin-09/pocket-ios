import SwiftUI

/// Hosts the single shared paywall sheet. Applied **once** at the app root, above `HomeView`.
///
/// **Red Moon is free (ADR 0237).** This publishes `\.isPro` as `true` for everyone, so every gate in
/// the app opens, and the launch wall ADR 0144 D4 put here is gone. The gates themselves, and this
/// host with them, are deleted in the commits that follow (0237 D2); until then a gate that still
/// calls `presentPaywall(_:)` can never be reached, because none of them fires once `isPro` is true.
private struct PaywallHost: ViewModifier {
    @Environment(StoreManager.self) private var store
    /// Re-injected into the paywall alongside the store — the opt-in toggle reads it (ADR 0144 D6).
    @Environment(TrialReminder.self) private var trialReminder
    @State private var trigger: PaywallTrigger?

    func body(content: Content) -> some View {
        content
            .environment(\.isPro, true)
            .environment(\.presentPaywall, { newTrigger in trigger = newTrigger })
            .sheet(item: $trigger) { trigger in
                PaywallView(trigger: trigger)
                    .environment(store)
                    .environment(trialReminder)
            }
    }
}

extension View {
    /// Install the app-wide paywall host (once, at the root, inside the `StoreManager` environment).
    func paywallHost() -> some View {
        modifier(PaywallHost())
    }
}
