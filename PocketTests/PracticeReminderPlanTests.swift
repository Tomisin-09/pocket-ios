import XCTest
@testable import Pocket

/// The practice reminder's decisions (ADR 0186 D1–D2, D7).
///
/// Every assertion lives here rather than in a UI test, and that is not a preference: a repeating
/// `UNCalendarNotificationTrigger` cannot be usefully driven from a test — the same wall
/// `TrialReminderPlan` hit, and the reason `docs/plans/storekit-sandbox-validation.md` records the
/// trial reminder as not testable in sandbox. Delivery is verified on a device. What is *decided*
/// is verified here.
///
/// A `Calendar` is pinned in every date test. `.current` carries the machine's timezone and
/// `firstWeekday`, both of which differ between a developer's Mac and CI, and a weekday assertion
/// against a floating calendar is a flake waiting for a Sunday.
final class PracticeReminderPlanTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    private let routine = UUID()

    /// 2026-09-02 is a Wednesday (`weekday` 4), 09:00 UTC.
    private var wednesdayMorning: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 9)) ?? .distantPast
    }

    private func schedule(isOn: Bool = true,
                          days: Set<Int>,
                          hour: Int = 18,
                          minute: Int = 0) -> PracticeReminderPlan.Schedule {
        PracticeReminderPlan.Schedule(isOn: isOn, weekdays: days, hour: hour, minute: minute)
    }

    // MARK: - What gets scheduled

    func testOneRequestPerChosenWeekday() {
        let requests = PracticeReminderPlan.requests(for: schedule(days: [2, 4, 6]),
                                                     routineUID: routine)
        XCTAssertEqual(requests.map(\.weekday), [2, 4, 6])
        XCTAssertEqual(Set(requests.map(\.identifier)).count, 3, "Identifiers must not collide")
    }

    /// Fixed per routine per weekday, so rescheduling **replaces** rather than stacking a second
    /// copy behind the first — `TrialReminder.requestIdentifier`'s rule, multiplied by the days.
    func testIdentifiersAreStableAcrossCalls() {
        let first = PracticeReminderPlan.requests(for: schedule(days: [3]), routineUID: routine)
        let again = PracticeReminderPlan.requests(for: schedule(days: [3], hour: 7),
                                                  routineUID: routine)
        XCTAssertEqual(first.map(\.identifier), again.map(\.identifier))
    }

    func testSwitchedOffSchedulesNothing() {
        XCTAssertTrue(PracticeReminderPlan.requests(for: schedule(isOn: false, days: [2, 3]),
                                                    routineUID: routine).isEmpty)
    }

    /// A reminder with no days is a control the player half-set. Inventing a day for them is the app
    /// deciding to reach out, which is the one thing ADR 0186 exists to prevent.
    func testNoDaysSchedulesNothing() {
        XCTAssertTrue(PracticeReminderPlan.requests(for: schedule(days: []),
                                                    routineUID: routine).isEmpty)
    }

    /// Defensive against a schedule decoded from a future build. An out-of-range `DateComponents`
    /// matches no date, so the system would accept the request and simply never fire it — a silent
    /// failure, which is the class of bug this whole type is unit-tested to avoid.
    func testAnImpossibleTimeSchedulesNothing() {
        XCTAssertTrue(PracticeReminderPlan.requests(for: schedule(days: [2], hour: 24),
                                                    routineUID: routine).isEmpty)
        XCTAssertTrue(PracticeReminderPlan.requests(for: schedule(days: [2], minute: 60),
                                                    routineUID: routine).isEmpty)
    }

    func testAnOutOfRangeWeekdayIsDropped() {
        let requests = PracticeReminderPlan.requests(for: schedule(days: [0, 3, 9]),
                                                     routineUID: routine)
        XCTAssertEqual(requests.map(\.weekday), [3])
    }

    // MARK: - Identifiers round-trip (what the D3 sweep depends on)

    func testAnIdentifierNamesItsRoutine() {
        let identifier = PracticeReminderPlan.identifier(routineUID: routine, weekday: 5)
        XCTAssertEqual(PracticeReminderPlan.routineUID(fromIdentifier: identifier), routine)
    }

    /// The sweep reads **every** pending request in the app, including the trial reminder's. Failing
    /// to recognise a foreign identifier as foreign would either cancel it or crash on it; returning
    /// `nil` is what lets `reconcile` leave it alone.
    @MainActor
    func testAForeignIdentifierIsNotClaimed() {
        XCTAssertNil(PracticeReminderPlan.routineUID(
            fromIdentifier: TrialReminder.requestIdentifier),
                     "The trial reminder shares this notification centre")
        XCTAssertNil(PracticeReminderPlan.routineUID(fromIdentifier: "nonsense"))
        XCTAssertNil(PracticeReminderPlan.routineUID(
            fromIdentifier: PracticeReminderPlan.identifierPrefix + "not-a-uuid.3"))
    }

    // MARK: - Next fire date (the footer, and D1 made visible)

    /// From Wednesday morning, a Wednesday-evening reminder is later the same day.
    func testTheNextFireDateIsLaterToday() throws {
        let next = PracticeReminderPlan.nextFireDate(for: schedule(days: [4]),
                                                     after: wednesdayMorning, calendar: calendar)
        let parts = calendar.dateComponents([.weekday, .hour, .day], from: try XCTUnwrap(next))
        XCTAssertEqual(parts.weekday, 4)
        XCTAssertEqual(parts.hour, 18)
        XCTAssertEqual(parts.day, 2, "Same Wednesday — 18:00 has not happened yet")
    }

    /// Once today's time has passed, the same schedule reads as next week rather than as something
    /// missed. There is no "missed" in this type at all — see the header.
    func testAPassedTimeRollsToNextWeek() throws {
        let evening = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 19)))
        let next = try XCTUnwrap(PracticeReminderPlan.nextFireDate(for: schedule(days: [4]),
                                                                   after: evening,
                                                                   calendar: calendar))
        XCTAssertEqual(calendar.dateComponents([.day], from: next).day, 9)
    }

    /// With several days chosen it is the **soonest**, not the first in week order — a Monday
    /// reminder read on a Thursday is next Monday, and a Friday one is tomorrow.
    func testTheNextFireDateIsTheSoonestOfTheChosenDays() throws {
        let next = try XCTUnwrap(PracticeReminderPlan.nextFireDate(for: schedule(days: [2, 6]),
                                                                   after: wednesdayMorning,
                                                                   calendar: calendar))
        XCTAssertEqual(calendar.dateComponents([.weekday], from: next).weekday, 6, "Friday")
    }

    func testNothingScheduledHasNoNextFireDate() {
        XCTAssertNil(PracticeReminderPlan.nextFireDate(for: schedule(isOn: false, days: [2]),
                                                       after: wednesdayMorning, calendar: calendar))
        XCTAssertNil(PracticeReminderPlan.nextFireDate(for: schedule(days: []),
                                                       after: wednesdayMorning, calendar: calendar))
    }

    // MARK: - What it says (D7)

    func testTheSummaryNamesEveryDay() {
        let summary = PracticeReminderPlan.summary(for: schedule(days: [2, 4, 6]),
                                                   calendar: calendar)
        let text = summary ?? ""
        XCTAssertTrue(text.contains("&"), "Several days are listed, not counted: \(text)")
        XCTAssertFalse(text.contains("3 days"), "A count of appointments is one step from a count "
                       + "of kept ones (design-brief §3.5)")
    }

    func testNothingScheduledSaysNothing() {
        XCTAssertNil(PracticeReminderPlan.summary(for: schedule(isOn: false, days: [2]),
                                                  calendar: calendar))
        XCTAssertNil(PracticeReminderPlan.summary(for: schedule(days: []), calendar: calendar))
    }

    // MARK: - Persistence

    /// A schedule is stored as JSON in `UserDefaults`, not as a SwiftData field — ADR 0186 adds no
    /// `@Model` and no migration, which is what lets it ship against a frozen schema.
    func testAScheduleSurvivesACodableRoundTrip() throws {
        let original = schedule(days: [1, 7], hour: 6, minute: 45)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PracticeReminderPlan.Schedule.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
