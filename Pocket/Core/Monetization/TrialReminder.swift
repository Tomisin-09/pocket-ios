import Foundation
import Observation
import UserNotifications

/// The **side-effecting half** of the trial reminder (ADR 0144 D6): it owns the local notification and
/// the app's own record of when the current trial ends. Every *decision* it makes is delegated to
/// `TrialReminderPlan`, which is pure and unit-tested; this type only does the things a test can't.
///
/// **Why the app keeps its own trial-end date.** StoreKit can say when the current subscription period
/// ends, but not — without a deprecated `offerType` read — whether that period is a trial. We know
/// exactly once, for certain, and locally: at the moment of a purchase the paywall made while the
/// player was intro-offer eligible. So that's when it's recorded. Losing it on reinstall is
/// acceptable; guessing it is not.
///
/// **Local notifications only.** No `aps-environment` entitlement and no push server — AGENTS.md
/// forbids entitlements the app doesn't exercise, and ADR 0113 keeps the app account-free, so there
/// is no address to mail either.
@MainActor
@Observable
final class TrialReminder {
    /// The one notification this app ever schedules. **Fixed**, so rescheduling *replaces* the pending
    /// request rather than stacking a second copy behind it.
    static let requestIdentifier = "click.decooperations.pocket.trial-ending"

    /// When the current free trial converts to a paid period — `nil` when there is no live trial.
    /// Persisted, so it survives relaunch; observable, so the countdown rows track it.
    private(set) var trialEndsAt: Date? {
        didSet { defaults.set(trialEndsAt?.timeIntervalSince1970 ?? 0, forKey: Key.trialEndsAt) }
    }

    /// Whether the player asked for the notification, from the paywall's opt-in toggle. Persisted so
    /// reconciliation on a later launch knows whether it is allowed to reschedule.
    var remindersEnabled: Bool {
        didSet { defaults.set(remindersEnabled, forKey: Key.trialReminderEnabled) }
    }

    private let defaults: UserDefaults
    private let notifications: UNUserNotificationCenter?

    private enum Key {
        static let trialEndsAt = "trialEndsAt"
        static let trialReminderEnabled = "trialReminderEnabled"
    }

    /// - Parameter notifications: `nil` in previews and unit tests, where scheduling is a no-op and
    ///   touching `UNUserNotificationCenter.current()` would reach for a real notification service.
    init(defaults: UserDefaults = .standard,
         notifications: UNUserNotificationCenter? = .current()) {
        self.defaults = defaults
        self.notifications = notifications
        self.remindersEnabled = defaults.bool(forKey: Key.trialReminderEnabled)
        let stored = defaults.double(forKey: Key.trialEndsAt)
        self.trialEndsAt = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    // MARK: - Countdown (the half that needs no permission)

    /// Whole days left in the trial, or `nil` when no trial is running. Drives the "Trial ends in N
    /// days · Manage" rows on Home and in Settings.
    func daysRemaining(now: Date = .now) -> Int? {
        TrialReminderPlan.daysRemaining(trialEnd: trialEndsAt, now: now)
    }

    // MARK: - Authorization

    /// Ask for notification permission. Called **from the paywall, before the purchase** (ADR 0144
    /// D6): asked there it is part of the offer the player is considering, and it is something they
    /// requested. Asked after the buy it reads as "now we'd like to send you things", and gets denied
    /// once, permanently.
    ///
    /// Returns whether permission is now granted. A denial is not an error — the in-app countdown is
    /// unaffected, so the promise is still kept, just more quietly.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard let notifications else { return false }
        let granted = (try? await notifications.requestAuthorization(options: [.alert, .sound])) ?? false
        remindersEnabled = granted
        return granted
    }

    // MARK: - Recording and reconciling

    /// Record a trial that has just started, and schedule its reminder. Called by the paywall after a
    /// purchase made while intro-offer eligible — the one moment the app can be sure a trial began.
    func noteTrialPurchase(expiration: Date?, willAutoRenew: Bool = true, now: Date = .now) {
        trialEndsAt = expiration
        apply(TrialReminderPlan.decide(trialEnd: expiration, willAutoRenew: willAutoRenew, now: now))
    }

    /// Bring the pending reminder back in line with the subscription's current state — on launch, and
    /// on every `Transaction.updates` event (renewal, cancellation, refund, plan change).
    ///
    /// Does nothing when no trial is on record. Clears the record once the trial's end has passed,
    /// which is what stops a converted subscriber's *renewal* date being mistaken for a trial end and
    /// warned about a year later.
    func reconcile(expiration: Date?, willAutoRenew: Bool, now: Date = .now) {
        guard let recorded = trialEndsAt else { return }
        guard recorded > now else {
            trialEndsAt = nil
            apply(.cancel)
            return
        }
        // The trial's end can legitimately move (a plan change during the trial re-issues it), so
        // trust StoreKit's expiration over the recorded one while the trial is still running.
        if let expiration, expiration > now { trialEndsAt = expiration }
        apply(TrialReminderPlan.decide(trialEnd: trialEndsAt, willAutoRenew: willAutoRenew, now: now))
    }

    // MARK: - The notification itself

    private func apply(_ outcome: TrialReminderPlan.Outcome) {
        guard let notifications else { return }
        notifications.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        guard remindersEnabled, case let .schedule(fireDate) = outcome else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends tomorrow"
        // Says what happens and where to act, and makes no attempt to talk anyone out of leaving.
        content.body = "Red Moon Pro starts billing in 24 hours. Manage or cancel in Settings → "
            + "Red Moon Pro."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        notifications.add(UNNotificationRequest(identifier: Self.requestIdentifier,
                                                content: content,
                                                trigger: trigger))
    }
}
