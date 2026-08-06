import XCTest
@testable import Pocket

/// `TrialReminder`'s **record-keeping** half (ADR 0144 D6) — the part that decides what the app
/// believes about the current trial. Constructed with `notifications: nil`, so no request is ever
/// scheduled and the test never touches the notification service; the scheduling itself is device
/// behaviour, and the *decision* behind it is `TrialReminderPlanTests`.
@MainActor
final class TrialReminderTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var day: TimeInterval { 24 * 60 * 60 }

    private func makeReminder() throws -> TrialReminder {
        let name = "TrialReminderTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return TrialReminder(defaults: defaults, usesSystemNotifications: false)
    }

    func testStartsWithNoTrialOnRecord() throws {
        let reminder = try makeReminder()
        XCTAssertNil(reminder.trialEndsAt)
        XCTAssertNil(reminder.daysRemaining(now: now))
        XCTAssertFalse(reminder.remindersEnabled, "Notifications are opt-in, so this starts off")
    }

    func testRecordingATrialPurchaseDrivesTheCountdown() throws {
        let reminder = try makeReminder()
        reminder.noteTrialPurchase(expiration: now.addingTimeInterval(30 * day), now: now)
        XCTAssertEqual(reminder.daysRemaining(now: now), 30)
    }

    /// The record survives relaunch — a countdown that reset every launch would be worse than none.
    func testTheTrialEndDatePersists() throws {
        let name = "TrialReminderTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)

        let first = TrialReminder(defaults: defaults, usesSystemNotifications: false)
        let end = now.addingTimeInterval(30 * day)
        first.noteTrialPurchase(expiration: end, now: now)

        let relaunched = TrialReminder(defaults: defaults, usesSystemNotifications: false)
        XCTAssertEqual(relaunched.trialEndsAt?.timeIntervalSince1970 ?? 0,
                       end.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(relaunched.daysRemaining(now: now), 30)
    }

    // MARK: - Reconciliation

    /// **The one that stops a converted subscriber being warned about their renewal.** Once the
    /// recorded trial end has passed, the record is cleared — so the next expiration StoreKit reports
    /// (a year out, for an annual plan) is never mistaken for a trial.
    func testReconcileClearsTheRecordOnceTheTrialHasPassed() throws {
        let reminder = try makeReminder()
        let end = now.addingTimeInterval(30 * day)
        reminder.noteTrialPurchase(expiration: end, now: now)

        let afterConversion = end.addingTimeInterval(3600)
        reminder.reconcile(expiration: afterConversion.addingTimeInterval(365 * day),
                           willAutoRenew: true, now: afterConversion)

        XCTAssertNil(reminder.trialEndsAt)
        XCTAssertNil(reminder.daysRemaining(now: afterConversion))
    }

    /// A trial end can legitimately move — switching plan mid-trial re-issues it — so StoreKit's
    /// expiration wins over the recorded one while the trial is still running.
    func testReconcileFollowsAMovedTrialEnd() throws {
        let reminder = try makeReminder()
        reminder.noteTrialPurchase(expiration: now.addingTimeInterval(30 * day), now: now)

        reminder.reconcile(expiration: now.addingTimeInterval(20 * day), willAutoRenew: true, now: now)
        XCTAssertEqual(reminder.daysRemaining(now: now), 20)
    }

    /// Reconciliation is a no-op when the app has no trial on record — an ordinary paid subscriber's
    /// renewal date must never conjure a countdown out of nothing.
    func testReconcileDoesNothingWithoutATrialOnRecord() throws {
        let reminder = try makeReminder()
        reminder.reconcile(expiration: now.addingTimeInterval(365 * day), willAutoRenew: true, now: now)
        XCTAssertNil(reminder.trialEndsAt)
        XCTAssertNil(reminder.daysRemaining(now: now))
    }

    /// Cancelling stops the notification but **not** the countdown: the trial is still running and the
    /// player is still entitled until it ends, so saying how long is left stays true and useful.
    func testCancellingKeepsTheCountdownAndOnlyStopsTheNotification() throws {
        let reminder = try makeReminder()
        reminder.noteTrialPurchase(expiration: now.addingTimeInterval(30 * day), now: now)
        reminder.reconcile(expiration: now.addingTimeInterval(30 * day), willAutoRenew: false, now: now)
        XCTAssertEqual(reminder.daysRemaining(now: now), 30)
    }
}
