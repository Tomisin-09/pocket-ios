import SwiftData
import SwiftUI

@main
struct PocketApp: App {
    // Drives per-screen orientation (ADR 0042) — see OrientationGate.swift.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Appearance override (ADR 0062 follow-up) — read at the root so the whole app
    // repaints when it changes, rather than each screen consulting it separately.
    @AppStorage(AppSettings.Key.appearance) private var appearance = AppearancePreference.system

    // Drives the re-entitlement check below. Read at the root because the store is owned here.
    @Environment(\.scenePhase) private var scenePhase

    // The app's single Red Moon Pro entitlement source (ADR 0112) — resolves `isPro` from StoreKit
    // and is read by every paywall gate through the environment. Owned here for the app's lifetime.
    @State private var store = StoreManager()

    // The trial-end reminder (ADR 0144 D6) — owns the one local notification and the app's record of
    // when the current trial converts. Lives here for the app's lifetime alongside the store, and is
    // read from the environment by the paywall's opt-in toggle and the Home/Settings countdown rows.
    @State private var trialReminder = TrialReminder()

    init() {
        // The composition root, and the only place that knows a vendor exists (ADR 0120). Installing
        // the sink does **not** start the SDK — `AptabaseSink` initialises on its first *delivered*
        // event, and the consent gate means that can only happen after an explicit opt-in.
        Analytics.install(AptabaseSink())
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                // `.environment(store)` must sit **outside** `.paywallHost()`, so the host (which
                // reads `@Environment(StoreManager.self)` to publish `isPro`) resolves the store from
                // above it; applied the other way round the host is a parent of the injection and traps.
                .paywallHost()
                .environment(store)
                .environment(trialReminder)
                .preferredColorScheme(appearance.colorScheme)
                // The composition seam between StoreKit and notifications (ADR 0144 D6): the store
                // publishes renewal state, the reminder decides what to do with it. Set once, and it
                // then fires on launch and on every `Transaction.updates` event — renewal,
                // cancellation, refund — which is what reschedules or cancels a pending reminder.
                .task {
                    store.onSubscriptionStateChange = { [trialReminder] expiration, renews in
                        trialReminder.reconcile(expiration: expiration, willAutoRenew: renews)
                    }
                    // The store's first refresh is already in flight from its own `init`, and may
                    // land before this runs. Replay it once so the launch reconcile never depends on
                    // winning that race — and guard on `hasResolvedEntitlements`, or an unresolved
                    // store would look like "no subscription" and cancel a valid reminder.
                    if store.hasResolvedEntitlements {
                        trialReminder.reconcile(expiration: store.currentExpiration,
                                                willAutoRenew: store.willAutoRenew)
                    }
                }
                // Re-check the entitlement every time the app comes forward, so a subscription that
                // **lapsed while the app was backgrounded** re-locks on return (ADR 0112 "gate at
                // read time") instead of at the next cold launch.
                //
                // Without this the gates go stale, and not theoretically: a plain expiry creates no
                // new transaction, so `Transaction.updates` emits **nothing** — and `init`,
                // `purchase` and `restore` are the only other callers of `refreshEntitlements()`.
                // Sandbox-verified on device 2026-08-07: after the trial expired, a foregrounded app
                // kept every Pro surface open (and the trial countdown vanished on its own, since it
                // reads a stored date rather than StoreKit — so the screen announced the trial had
                // ended while still granting it). iOS suspends apps for days, so the stale window is
                // not a moment. Cheap to run: StoreKit serves cached entitlements offline, so this
                // needs no network and shows no spinner, and it re-reconciles the trial reminder
                // through `onSubscriptionStateChange` as a side effect.
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await store.refreshEntitlements() }
                }
        }
        .modelContainer(for: [Song.self, Loop.self, Marker.self, JournalEntry.self,
                              Exercise.self, Routine.self, RoutineItem.self, Goal.self,
                              Recording.self, SavedChord.self, Profile.self, PracticeRun.self,
                              ReferenceLink.self])
    }
}
