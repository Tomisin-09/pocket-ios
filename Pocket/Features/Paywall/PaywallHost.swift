import SwiftUI

/// Bridges the live `StoreManager` into the preview-safe paywall environment (ADR 0112) and hosts the
/// single shared paywall sheet. Applied **once** at the app root, above `HomeView`:
/// - publishes `\.isPro` from the store (so every gate re-evaluates when entitlement flips), and
/// - provides `\.presentPaywall`, which raises the one paywall sheet carrying the trigger.
///
/// One host means one paywall sheet for the whole app — a gate anywhere calls `presentPaywall(_:)`
/// and this is where it appears, over everything.
///
/// It also owns ADR 0144 D4's **launch wall**: a dismissible full-screen paywall shown **once per
/// launch** to a player without Pro. It lives here rather than on `HomeView` because this is the one
/// view that already knows the entitlement and owns the paywall's presentation.
private struct PaywallHost: ViewModifier {
    @Environment(StoreManager.self) private var store
    /// Re-injected into the paywall alongside the store — the opt-in toggle reads it (ADR 0144 D6).
    @Environment(TrialReminder.self) private var trialReminder
    @State private var trigger: PaywallTrigger?
    /// The once-per-launch wall (ADR 0144 D4). `@State` on an app-root modifier, so it is per
    /// *process*: dismiss it and it stays dismissed until the app is launched again. Deliberately not
    /// `@AppStorage` — a permanently-dismissible wall is invisible after day one, and deliberately not
    /// per-foreground either, which would make backgrounding mid-practice punitive.
    @State private var showingLaunchWall = false
    /// Guards the wall against re-presenting within one launch (e.g. after a purchase that is later
    /// refunded, or an entitlement refresh that re-runs).
    @State private var launchWallShown = false
    /// **The first-launch intake wins the screen** (ADR 0113). `HomeView` raises its own
    /// `fullScreenCover` from `onAppear`, and this host is its *parent* — two covers competing across
    /// that boundary is how one of them silently fails to present. The ladder in
    /// `maybeOfferProfileMoment` already says first-run moments come first, so the wall waits behind
    /// it and appears the moment the intake is dismissed. A fresh install therefore meets the app
    /// before it meets the offer, which is also the better order.
    @AppStorage(AppSettings.Key.artistIntakeSeen) private var artistIntakeSeen = false
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
                    .environment(trialReminder)
            }
            .fullScreenCover(isPresented: $showingLaunchWall, onDismiss: reportLaunchWallDismissal) {
                PaywallView(trigger: .launch)
                    .environment(store)
                    .environment(trialReminder)
            }
            // Wait for the **first** entitlement scan before deciding. `isPro` is `false` until the
            // async scan lands, so raising the wall on `!isPro` alone would flash it at every paying
            // subscriber on every launch. `-uiTesting` forces `debugProOverride = true`, so `isPro` is
            // already true at first paint and this never fires under UI test (verified: all four
            // `PocketUITests` files pass the flag).
            .onChange(of: store.hasResolvedEntitlements, initial: true) { _, _ in
                maybeShowLaunchWall()
            }
            .onChange(of: artistIntakeSeen) { _, _ in maybeShowLaunchWall() }
    }

    private func maybeShowLaunchWall() {
        guard artistIntakeSeen else { return }
        guard store.hasResolvedEntitlements, !store.isPro, !launchWallShown else { return }
        launchWallShown = true
        showingLaunchWall = true
        Analytics.send(.paywallShown(trigger: .launch))
    }

    private func reportLaunchWallDismissal() {
        Analytics.send(.paywallDismissed(trigger: .launch, purchased: store.isPro))
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
