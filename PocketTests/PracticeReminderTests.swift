import Observation
import XCTest
@testable import Pocket

/// `PracticeReminder`'s **record-keeping** half (ADR 0186 D3–D4, D12) — what the app believes about
/// each routine's appointment.
///
/// Constructed with `usesSystemNotifications: false`, so no request is ever scheduled and the test
/// never touches the notification service. The scheduling itself is device behaviour; the decision
/// behind it is `PracticeReminderPlanTests`. Same split, and same reason, as `TrialReminderTests`.
@MainActor
final class PracticeReminderTests: XCTestCase {

    private func makeReminder() throws -> PracticeReminder {
        let name = "PracticeReminderTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return PracticeReminder(defaults: defaults, usesSystemNotifications: false)
    }

    private func schedule(days: Set<Int>, hour: Int = 18) -> PracticeReminderPlan.Schedule {
        PracticeReminderPlan.Schedule(isOn: true, weekdays: days, hour: hour, minute: 0)
    }

    // MARK: - The default position (D12)

    /// A routine with no schedule of its own starts from the player's default days and time — but
    /// **off**. Nothing fires until they switch it on, which is the only legal trigger (D1).
    func testANewRoutineStartsFromTheDefaultButSwitchedOff() throws {
        let reminder = try makeReminder()
        reminder.setDefaultSchedule(schedule(days: [3, 5], hour: 7))

        let fresh = reminder.schedule(for: UUID())
        XCTAssertFalse(fresh.isOn)
        XCTAssertEqual(fresh.weekdays, [3, 5])
        XCTAssertEqual(fresh.hour, 7)
    }

    /// There is no global on switch. Storing one would arm every routine at once, which is the app
    /// deciding you should be reminded rather than you asking to be.
    func testTheDefaultCannotBeSwitchedOn() throws {
        let reminder = try makeReminder()
        reminder.setDefaultSchedule(schedule(days: [2]))
        XCTAssertFalse(reminder.defaultSchedule.isOn)
    }

    /// Changing the default never reaches a reminder already set — that would be the app
    /// rescheduling an appointment somebody else made.
    func testChangingTheDefaultLeavesExistingRemindersAlone() throws {
        let reminder = try makeReminder()
        let routine = UUID()
        reminder.setSchedule(schedule(days: [2], hour: 8), for: routine, name: "Warm-up",
                             blockCount: 4)

        reminder.setDefaultSchedule(schedule(days: [7], hour: 20))

        XCTAssertEqual(reminder.schedule(for: routine).weekdays, [2])
        XCTAssertEqual(reminder.schedule(for: routine).hour, 8)
    }

    // MARK: - Per-routine schedules

    func testAScheduleSurvivesRelaunch() throws {
        let name = "PracticeReminderTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let routine = UUID()

        let first = PracticeReminder(defaults: defaults, usesSystemNotifications: false)
        first.setSchedule(schedule(days: [2, 4]), for: routine, name: "Warm-up", blockCount: 4)

        let relaunched = PracticeReminder(defaults: defaults, usesSystemNotifications: false)
        XCTAssertTrue(relaunched.schedule(for: routine).isOn)
        XCTAssertEqual(relaunched.schedule(for: routine).weekdays, [2, 4])
    }

    func testTwoRoutinesKeepSeparateSchedules() throws {
        let reminder = try makeReminder()
        let morning = UUID()
        let evening = UUID()
        reminder.setSchedule(schedule(days: [2], hour: 8), for: morning, name: "Morning",
                             blockCount: 3)
        reminder.setSchedule(schedule(days: [6], hour: 21), for: evening, name: "Evening",
                             blockCount: 5)

        XCTAssertEqual(reminder.schedule(for: morning).weekdays, [2])
        XCTAssertEqual(reminder.schedule(for: evening).weekdays, [6])
    }

    func testHasAnyReminderTracksWhetherAnythingIsOn() throws {
        let reminder = try makeReminder()
        let routine = UUID()
        XCTAssertFalse(reminder.hasAnyReminder())

        reminder.setSchedule(schedule(days: [2]), for: routine, name: "Warm-up", blockCount: 4)
        XCTAssertTrue(reminder.hasAnyReminder())

        var off = reminder.schedule(for: routine)
        off.isOn = false
        reminder.setSchedule(off, for: routine, name: "Warm-up", blockCount: 4)
        XCTAssertFalse(reminder.hasAnyReminder())
    }

    /// The default is stored outside the `practiceReminder.` prefix a sweep scans, so it can never
    /// be mistaken for a routine's own schedule and swept away with one.
    func testTheDefaultIsNotMistakenForARoutine() async throws {
        let reminder = try makeReminder()
        reminder.setDefaultSchedule(schedule(days: [2, 3]))
        XCTAssertFalse(reminder.hasAnyReminder())

        await reminder.reconcile(liveRoutineUIDs: [])
        XCTAssertEqual(reminder.defaultSchedule.weekdays, [2, 3])
    }

    // MARK: - Observation

    /// **The one that catches a silent UI bug.** `@Observable` tracks *stored properties*, and the
    /// first version of this type had none — every read and write went straight to `UserDefaults`,
    /// which SwiftUI cannot observe. It compiled, and every other test here passed, while on device
    /// the weekday strip simply did not follow its own toggle: it changed only when something
    /// unrelated happened to repaint the screen.
    ///
    /// So this asserts the thing the feature actually needs, which is not "the value was stored"
    /// but "a view reading it would be told". Nothing else in this file can tell the difference.
    func testChangingAScheduleNotifiesObservers() throws {
        let reminder = try makeReminder()
        let routine = UUID()
        // An `XCTestExpectation` rather than a captured `Bool`: `onChange` is `@Sendable`, so a
        // captured var is a concurrency error rather than a style choice.
        let notified = expectation(description: "a view reading this schedule is invalidated")
        withObservationTracking {
            _ = reminder.schedule(for: routine)
        } onChange: {
            notified.fulfill()
        }

        reminder.setSchedule(schedule(days: [2]), for: routine, name: "Warm-up", blockCount: 4)
        wait(for: [notified], timeout: 1)
    }

    func testCancellingNotifiesObservers() throws {
        let reminder = try makeReminder()
        let routine = UUID()
        reminder.setSchedule(schedule(days: [2]), for: routine, name: "Warm-up", blockCount: 4)

        let notified = expectation(description: "a view reading this schedule is invalidated")
        withObservationTracking {
            _ = reminder.schedule(for: routine)
        } onChange: {
            notified.fulfill()
        }
        reminder.cancel(routineUID: routine)
        wait(for: [notified], timeout: 1)
    }

    func testChangingTheDefaultNotifiesObservers() throws {
        let reminder = try makeReminder()
        let notified = expectation(description: "a view reading the default is invalidated")
        withObservationTracking {
            _ = reminder.defaultSchedule
        } onChange: {
            notified.fulfill()
        }
        reminder.setDefaultSchedule(schedule(days: [5], hour: 9))
        wait(for: [notified], timeout: 1)
    }

    // MARK: - Cancelling and the orphan sweep (D3)

    func testCancellingForgetsTheSchedule() throws {
        let reminder = try makeReminder()
        let routine = UUID()
        reminder.setSchedule(schedule(days: [2]), for: routine, name: "Warm-up", blockCount: 4)

        reminder.cancel(routineUID: routine)
        XCTAssertFalse(reminder.schedule(for: routine).isOn)
        XCTAssertFalse(reminder.hasAnyReminder())
    }

    /// **The sweep.** A routine removed by any path — a cascade delete, a bulk action, anything that
    /// never touched the row-delete handler — leaves nothing behind. ADR 0151's lesson, in a place
    /// where the orphan reaches the player on a lock screen instead of sitting quietly in a list.
    func testReconcileDropsSchedulesForRoutinesThatAreGone() async throws {
        let reminder = try makeReminder()
        let kept = UUID()
        let deleted = UUID()
        reminder.setSchedule(schedule(days: [2]), for: kept, name: "Kept", blockCount: 3)
        reminder.setSchedule(schedule(days: [4]), for: deleted, name: "Gone", blockCount: 2)

        await reminder.reconcile(liveRoutineUIDs: [kept])

        XCTAssertTrue(reminder.schedule(for: kept).isOn)
        XCTAssertFalse(reminder.schedule(for: deleted).isOn)
    }

    func testReconcileKeepsEverythingWhenNothingIsGone() async throws {
        let reminder = try makeReminder()
        let first = UUID()
        let second = UUID()
        reminder.setSchedule(schedule(days: [2]), for: first, name: "One", blockCount: 3)
        reminder.setSchedule(schedule(days: [4]), for: second, name: "Two", blockCount: 2)

        await reminder.reconcile(liveRoutineUIDs: [first, second])

        XCTAssertTrue(reminder.schedule(for: first).isOn)
        XCTAssertTrue(reminder.schedule(for: second).isOn)
    }
}
