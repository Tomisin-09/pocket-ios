import Foundation

/// **When — and whether — to warn a player that their free trial is about to charge them**
/// (ADR 0144 D6). The pure half of the trial reminder: no `UNUserNotificationCenter`, no StoreKit,
/// no clock of its own. Foundation-only per the "pure logic stays pure" rule (AGENTS.md), and
/// unit-tested, because every one of the "don't send this" cases below is silent when it breaks —
/// a reminder that shouldn't have fired looks like nothing at all until it lands on a device.
enum TrialReminderPlan {
    /// How far ahead of conversion the reminder fires. A day is long enough to actually act on
    /// (cancelling is a trip into the Settings app) and short enough to still be about *this*
    /// decision rather than a note-to-self.
    static let leadTime: TimeInterval = 24 * 60 * 60

    /// What the reminder service should do with the one pending notification.
    enum Outcome: Equatable {
        /// Schedule (or reschedule) the reminder to fire at this instant.
        case schedule(Date)
        /// Remove any pending reminder and don't replace it.
        case cancel
    }

    /// Decide from the trial's end instant, whether the subscription is still set to auto-renew, and
    /// the current time.
    ///
    /// Four reasons to say nothing, and each is a decision rather than an edge case:
    /// - **No trial end** — there is no trial (or we never recorded one), so there is nothing to warn
    ///   about.
    /// - **Auto-renew is already off.** The player has cancelled; they will not be charged. Nagging
    ///   someone who already did the thing you were going to ask them to do is the opposite of the
    ///   honesty this feature exists for — and it reads as a retention ploy.
    /// - **The trial has already ended.** The charge has happened; a warning now is only a reminder
    ///   that it's too late.
    /// - **The fire date is behind us** (the trial ends in less than `leadTime`). Firing immediately
    ///   would deliver a "24 hours to decide" promise with three hours left in it.
    static func decide(trialEnd: Date?,
                       willAutoRenew: Bool,
                       leadTime: TimeInterval = leadTime,
                       now: Date) -> Outcome {
        guard let trialEnd, willAutoRenew, trialEnd > now else { return .cancel }
        let fireDate = trialEnd.addingTimeInterval(-leadTime)
        guard fireDate > now else { return .cancel }
        return .schedule(fireDate)
    }

    /// Whole days left in the trial, for the in-app countdown — `nil` once there is no live trial.
    ///
    /// **Rounded up**, so a trial with any time left in it never reads "0 days": the last few hours
    /// are the ones that matter most, and "Trial ends in 1 day" is true right up to the moment it
    /// ends. The countdown needs no permission and cannot be denied, which is why it is the half of
    /// D6 that is always present.
    static func daysRemaining(trialEnd: Date?, now: Date) -> Int? {
        guard let trialEnd, trialEnd > now else { return nil }
        let days = trialEnd.timeIntervalSince(now) / 86_400
        return max(1, Int(days.rounded(.up)))
    }
}
