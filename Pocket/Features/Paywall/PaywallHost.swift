import SwiftUI

/// Bridges the live `StoreManager` into the preview-safe paywall environment (ADR 0112) and hosts the
/// single shared paywall sheet. Applied **once** at the app root, above `HomeView`:
/// - publishes `\.isPro` from the store (so every gate re-evaluates when entitlement flips), and
/// - provides `\.presentPaywall`, which raises the one paywall sheet carrying the trigger.
///
/// One host means one paywall sheet for the whole app — a gate anywhere calls `presentPaywall(_:)`
/// and this is where it appears, over everything.
private struct PaywallHost: ViewModifier {
    @Environment(StoreManager.self) private var store
    @State private var trigger: PaywallTrigger?

    func body(content: Content) -> some View {
        content
            .environment(\.isPro, store.isPro)
            .environment(\.presentPaywall, { trigger = $0 })
            .sheet(item: $trigger) { trigger in
                // Re-inject the store so the sheet's own environment carries it regardless of how
                // SwiftUI propagates observables into sheets.
                PaywallView(trigger: trigger)
                    .environment(store)
            }
    }
}

extension View {
    /// Install the app-wide paywall host (once, at the root, inside the `StoreManager` environment).
    func paywallHost() -> some View {
        modifier(PaywallHost())
    }
}
