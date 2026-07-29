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
    /// The trigger of the presentation now on screen, kept because `onDismiss` runs after
    /// `$trigger` has already been cleared by `.sheet(item:)`.
    @State private var presentedTrigger: PaywallTrigger?
    /// Entitlement as it stood when the sheet went up, so "purchased" means *became* Pro during
    /// this presentation rather than "is Pro", which an existing subscriber would always satisfy.
    @State private var wasProAtPresent = false

    func body(content: Content) -> some View {
        content
            .environment(\.isPro, store.isPro)
            // Because every paywall in the app comes up here, this is the one place that has to
            // report a gate firing (ADR 0120) — no gate call site knows or cares about analytics.
            .environment(\.presentPaywall, { newTrigger in
                presentedTrigger = newTrigger
                wasProAtPresent = store.isPro
                trigger = newTrigger
                Analytics.send(.paywallShown(trigger: newTrigger))
            })
            .sheet(item: $trigger, onDismiss: reportDismissal) { trigger in
                // Re-inject the store so the sheet's own environment carries it regardless of how
                // SwiftUI propagates observables into sheets.
                PaywallView(trigger: trigger)
                    .environment(store)
            }
    }

    private func reportDismissal() {
        guard let presentedTrigger else { return }
        Analytics.send(.paywallDismissed(trigger: presentedTrigger,
                                         purchased: !wasProAtPresent && store.isPro))
        self.presentedTrigger = nil
    }
}

extension View {
    /// Install the app-wide paywall host (once, at the root, inside the `StoreManager` environment).
    func paywallHost() -> some View {
        modifier(PaywallHost())
    }
}
