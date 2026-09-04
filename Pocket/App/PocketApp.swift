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

    // MetricKit's crash and hang reports (ADR 0183) — read by the Diagnostics screen and, only when
    // the player has opted in, by the support sheet. Owned **here** and nowhere else, because
    // `MXMetricManager` holds its subscribers weakly: a recorder created further down the tree is
    // dropped by the OS the moment that view goes away, silently and with nothing to notice.
    @State private var diagnostics = DiagnosticsRecorder()

    // Per-routine practice reminders (ADR 0186 D4) — owns the pending requests and the stored
    // schedules. Lives here for the app's lifetime beside the trial reminder, and is read from the
    // environment by the routine screen's reminder row and by Settings ▸ Practice. Its launch sweep
    // (D3) runs from `HomeView`, which is where a `ModelContext` to resolve routines against is.
    @State private var practiceReminder = PracticeReminder()

    init() {
        // The composition root, and the only place that knows a vendor exists (ADR 0120). Installing
        // the sink does **not** start the SDK — `AptabaseSink` initialises on its first *delivered*
        // event, and the consent gate means that can only happen after an explicit opt-in.
        Analytics.install(AptabaseSink())

        // The Journal's list filters persist (ADR 0190 D8), and a simulator keeps its `UserDefaults`
        // between runs — so a driven test starts from whatever the last one left behind unless the
        // state is cleared here. See `AppSettings.resetJournalFilters` for the figure it silently
        // corrupted.
        if UITestRuntime.isActive { AppSettings.resetJournalFilters() }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                // The inbound door for shared routines (ADR 0188 S2) — `.onOpenURL` plus the one
                // preview sheet both doors present. **Inside** `.paywallHost()`, i.e. applied first:
                // it reads `\.isPro` and `\.presentPaywall` to gate a receive, and those are
                // published by the host below it. Tap-to-open can arrive on a cold launch with no
                // screen of the app's own on top, which is why it lives at the root at all.
                .routineReceiveHost()
                // `.environment(store)` must sit **outside** `.paywallHost()`, so the host (which
                // reads `@Environment(StoreManager.self)` to publish `isPro`) resolves the store from
                // above it; applied the other way round the host is a parent of the injection and traps.
                .paywallHost()
                .environment(store)
                .environment(trialReminder)
                .environment(diagnostics)
                .environment(practiceReminder)
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
                              LongTermGoal.self, Recording.self, TakeNote.self, SavedChord.self, Profile.self,
                              PracticeRun.self, ReferenceLink.self])
    }
}
