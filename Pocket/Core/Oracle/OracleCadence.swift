import Foundation

/// When a reading is available, and what period it covers (ADR 0187 D15).
///
/// **Weekly**, decided at build time from D15's "weekly or monthly". A week of journal entries,
/// runs and tempo points is enough material for a reflection that is not repeating itself, and it
/// matches the rhythm practice actually has. A month is long enough that the reading is about a
/// person the player has stopped being.
///
/// ### The gate is justified by the material, never by metering
///
/// > The reading is periodic because it **reads a period**. A week's reflection needs a week of
/// > material; running it twice on Tuesday reads the same journal twice.
///
/// That sentence is the whole justification, and it is what makes the Oracle's voice honest rather
/// than a rate limit wearing a robe. It also has a consequence this type takes seriously: the next
/// date must be **stated plainly and always** — a date, not a tease — because a gate that hides
/// when it opens is metering regardless of what it is called.
///
/// ### It never notifies (D2)
///
/// Nothing here schedules, fires on absence, or reads `lastPracticed`. The Oracle is pull: it
/// speaks only when spoken to, and a reading that has become available waits silently until the
/// player opens the screen. This type answers "is one available?" — it never asks anyone in.
///
/// Pure and `Calendar`-injected so the week boundaries are unit-tested rather than trusted
/// (AGENTS.md), which matters more than usual here: the calendar's own `firstWeekday` is Monday in
/// most of the world and Sunday in the US, and hard-coding either would put the reading's window
/// out of step with every other week in the app.
enum OracleCadence {

    /// One reading per calendar week — not one per rolling seven days.
    ///
    /// The calendar week is the right unit because it is the one the player already has: it is what
    /// `PracticeLog.weekInterval` windows on and what the practice log charts. A rolling seven days
    /// would drift a little every time, so the "next reading" date would creep forward through the
    /// week and the period each reading covered would overlap the last one by however long the
    /// player took to open it.
    static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        PracticeLog.weekInterval(containing: date, calendar: calendar)
    }

    /// The period a reading taken now would cover: **the last complete week**, not the one in
    /// progress.
    ///
    /// A reflection on a week still being lived is a reflection on a fragment — open it on Monday
    /// evening and it reads one day and calls it a week. Reading the week just finished means every
    /// reading covers the same amount of time, which is the only way the sentence at the top of
    /// this file stays true.
    static func window(endingBefore now: Date, calendar: Calendar = .current) -> DateInterval {
        let current = week(containing: now, calendar: calendar)
        let priorDay = current.start.addingTimeInterval(-1)
        return week(containing: priorDay, calendar: calendar)
    }

    /// Whether a reading is available, given when the last one was taken.
    ///
    /// `nil` — no reading ever taken — is available, always. The first reading is not made to wait
    /// for a boundary the player was not told about when they installed the app.
    static func isAvailable(now: Date, lastReading: Date?, calendar: Calendar = .current) -> Bool {
        guard let lastReading else { return true }
        return !week(containing: now, calendar: calendar).contains(lastReading)
    }

    /// When the next reading opens — the start of the week after the one the last reading was taken
    /// in.
    ///
    /// `nil` when one is available right now, so a caller cannot render "available now" and a
    /// future date at the same time. The screen states this date whenever it is non-`nil`; that is
    /// D15's requirement and this signature is shaped to make satisfying it the easy path.
    static func nextReading(after lastReading: Date?, now: Date, calendar: Calendar = .current) -> Date? {
        guard let lastReading else { return nil }
        guard !isAvailable(now: now, lastReading: lastReading, calendar: calendar) else { return nil }
        return week(containing: lastReading, calendar: calendar).end
    }
}
