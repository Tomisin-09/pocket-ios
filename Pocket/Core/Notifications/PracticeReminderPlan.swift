import Foundation

/// **When a practice reminder fires** (ADR 0186 D1–D2). The pure half: Foundation-only per the
/// "pure logic stays pure" rule (AGENTS.md), and unit-tested, because — as `TrialReminderPlan`'s own
/// header puts it — every "don't send this" case is silent when it breaks.
///
/// ## The dependency this type does not have, and must never acquire
///
/// It takes **no `PracticeLog`, no `PracticeRun`, no `lastPracticed`, no recency map** — nothing that
/// could tell it whether the player has practised. Its entire input is *the days and time they
/// picked*, plus `now`.
///
/// That absence is the feature (ADR 0186 D1). The default mechanism in this category is to notice a
/// player has gone quiet and ping them about it; `docs/design-brief.md` §3.5 forbids it in as many
/// words — *"No second person past tense about failure. Never 'you haven't practised since
/// Tuesday'."* — and ADR 0070 forbids the same move one level down, at the playing. Softening the
/// copy would leave the mechanism intact, and the mechanism is the thing that is forbidden.
///
/// So the rule is enforced by a **signature**, not a review note: the type that decides whether to
/// send is handed no way to find out whether you practised. Writing an absence-triggered reminder
/// here means first widening this file's parameters — a visible, reviewable act — rather than adding
/// a condition nobody notices. Same trick `.swiftlint.yml`'s custom rules play (ADR 0120): make the
/// wrong thing structurally awkward rather than merely discouraged.
///
/// **D2 falls out of that rather than being a second rule.** A missed reminder is silent because
/// nothing here can learn a reminder was missed. No follow-up, no rescheduling, no badge.
enum PracticeReminderPlan {

    /// What the player asked for: some weekdays, and a time of day.
    ///
    /// `Codable` because it is persisted as JSON in `UserDefaults` — **not** as a SwiftData field.
    /// ADR 0186 adds no `@Model` and no migration, which matters while the schema is frozen for
    /// review (see the schema-freeze note in ADR 0186's header).
    struct Schedule: Equatable, Codable {
        /// Whether the player wants the reminder. **Intent only** — never "the app has permission",
        /// which is `NotificationPermission`'s job. ADR 0186 D5 is the bug that conflating them
        /// causes.
        var isOn: Bool
        /// `Calendar` weekdays: **1 = Sunday** through 7 = Saturday, matching `DateComponents.weekday`
        /// so nothing has to translate at the trigger.
        var weekdays: Set<Int>
        var hour: Int
        var minute: Int

        /// Off, on weekday evenings. The days and time are only a starting position for the pickers
        /// — nothing fires until the player switches it on, which is the only legal trigger (D1).
        static let unset = Schedule(isOn: false, weekdays: [2, 3, 4, 5, 6], hour: 18, minute: 0)
    }

    /// One notification request to hand the system — a single weekday's repeating appointment.
    struct Request: Equatable {
        let identifier: String
        let weekday: Int
        let hour: Int
        let minute: Int
    }

    /// Namespaced so `reconcile` can tell this app's practice reminders apart from the trial one and
    /// from anything a later feature schedules. Dot-terminated: the `uid` follows immediately.
    static let identifierPrefix = "click.decooperations.pocket.practice-reminder."

    static let weekdayRange = 1...7

    // MARK: - Identifiers

    /// **Fixed** per routine per weekday, so rescheduling *replaces* the pending request rather than
    /// stacking a second copy behind it — the rule `TrialReminder.requestIdentifier` already states,
    /// here multiplied by the days.
    ///
    /// Built from the routine's **`uid`**, never its `persistentModelID` (ADR 0090,
    /// `docs/swiftdata-gotchas.md`): a `PersistentIdentifier` is not stable across the store's
    /// lifetime, and this string outlives launches by design.
    static func identifier(routineUID: UUID, weekday: Int) -> String {
        "\(identifierPrefix)\(routineUID.uuidString).\(weekday)"
    }

    /// Recover the routine a pending request belongs to. `nil` for anything this app did not
    /// schedule as a practice reminder — including the trial reminder, which shares the centre.
    ///
    /// This is what makes the D3 sweep possible: the system's pending requests are the only source
    /// of truth about what it still holds, and they are strings.
    static func routineUID(fromIdentifier identifier: String) -> UUID? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        let rest = identifier.dropFirst(identifierPrefix.count)
        guard let dot = rest.lastIndex(of: ".") else { return nil }
        return UUID(uuidString: String(rest[rest.startIndex..<dot]))
    }

    // MARK: - Deciding

    /// The requests a schedule should currently have pending — **empty whenever nothing should
    /// fire**, so the caller's cancel-then-add is uniform and there is no separate "off" path to get
    /// wrong.
    ///
    /// Empty for three reasons, each a decision rather than an edge case:
    /// - **Switched off.** Nothing to say.
    /// - **No days chosen.** A reminder with no days is not a daily reminder; it is a control the
    ///   player half-set, and inventing a day for them is the app deciding to reach out.
    /// - **A time that isn't a time.** Defensive against a decoded value from a future build; an
    ///   out-of-range `DateComponents` matches nothing and would fail silently at the system.
    static func requests(for schedule: Schedule, routineUID: UUID) -> [Request] {
        guard schedule.isOn,
              (0...23).contains(schedule.hour),
              (0...59).contains(schedule.minute) else { return [] }
        return schedule.weekdays
            .filter { weekdayRange.contains($0) }
            .sorted()
            .map { Request(identifier: identifier(routineUID: routineUID, weekday: $0),
                           weekday: $0, hour: schedule.hour, minute: schedule.minute) }
    }

    /// The next instant this schedule fires, or `nil` when it never will.
    ///
    /// Drives the routine screen's footer, which is why it is **future tense and nothing else**
    /// (D7). It is also the honest demonstration of D1: every argument here is either something the
    /// player chose or the current time, and there is nowhere to put a practice history even if
    /// someone wanted to.
    ///
    /// Strictly after `now` — a reminder set for exactly this minute reads as "next week", which is
    /// true, since the one for today has either already fired or is firing.
    static func nextFireDate(for schedule: Schedule,
                             after now: Date,
                             calendar: Calendar = .current) -> Date? {
        let requests = requests(for: schedule, routineUID: UUID())
        guard !requests.isEmpty else { return nil }
        return requests.compactMap { request -> Date? in
            var components = DateComponents()
            components.weekday = request.weekday
            components.hour = request.hour
            components.minute = request.minute
            return calendar.nextDate(after: now, matching: components,
                                     matchingPolicy: .nextTime, direction: .forward)
        }.min()
    }

    /// What the screen may say about a schedule right now.
    ///
    /// In the pure half because *"never promise a delivery that cannot happen"* is precisely the
    /// kind of rule that is silent when it breaks: it looks correct in every simulator run, on any
    /// device where the prompt has not been denied. It shipped broken once — the footer printed
    /// "Next: Thursday 12:00" with the "notifications are off" note directly beneath it (found on
    /// device, 2026-09-02).
    enum Status: Equatable {
        /// Switched off. Nothing to say and nothing to promise.
        case off
        /// On, but no days ticked, so it will never fire.
        case noDays
        /// On and dated, but notifications are off for the app — so there is a schedule and there
        /// is **no promise**.
        case notDelivered
        /// On, dated, and deliverable. The one case that may name a time.
        case next(Date)
    }

    /// **The one input beyond the player's own choices**, and it is deliberately not the sort D1
    /// forbids: permission is a fact about the app's access, not about whether anybody practised.
    /// Nothing here can still learn that a reminder was missed.
    static func status(for schedule: Schedule,
                       permission: NotificationPermission?,
                       now: Date,
                       calendar: Calendar = .current) -> Status {
        guard schedule.isOn else { return .off }
        // `nil` — not looked yet — reads as deliverable, so a screen does not flash a warning on
        // every appear and then withdraw it.
        guard permission != .denied else { return .notDelivered }
        guard let next = nextFireDate(for: schedule, after: now, calendar: calendar) else {
            return .noDays
        }
        return .next(next)
    }

    // MARK: - Saying it

    /// "Mon, Wed & Fri at 18:00" — what the routine's row reads when the reminder is on, and `nil`
    /// when nothing is scheduled.
    ///
    /// States the appointment and nothing about whether it has been kept. There is deliberately no
    /// variant of this string that counts anything.
    static func summary(for schedule: Schedule, calendar: Calendar = .current) -> String? {
        let days = schedule.weekdays.filter(weekdayRange.contains).sorted()
        guard schedule.isOn, !days.isEmpty else { return nil }
        return "\(dayList(days, calendar: calendar)) at \(timeText(schedule, calendar: calendar))"
    }

    /// Every day named, in week order — never "5 days a week", which is a count of appointments and
    /// one short step from a count of kept ones.
    private static func dayList(_ days: [Int], calendar: Calendar) -> String {
        let symbols = calendar.shortWeekdaySymbols
        let names = days.compactMap { day -> String? in
            let index = day - 1
            return symbols.indices.contains(index) ? symbols[index] : nil
        }
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " & " + (names.last ?? "")
    }

    /// Rendered through `Date.FormatStyle`, so a 12-hour locale reads "6:00 PM" without this type
    /// knowing which locale it is in.
    private static func timeText(_ schedule: Schedule, calendar: Calendar) -> String {
        var components = DateComponents()
        components.year = 2_000
        components.month = 1
        components.day = 3
        components.hour = schedule.hour
        components.minute = schedule.minute
        guard let date = calendar.date(from: components) else {
            return String(format: "%02d:%02d", schedule.hour, schedule.minute)
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
