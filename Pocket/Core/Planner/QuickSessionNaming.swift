import Foundation

/// Default naming for a **generated Quick session** (V2 planner Slice 1): a dated, human-friendly
/// name that stays unique among the existing routines — `"8 Jul Quick Session"`, then
/// `"8 Jul Quick Session 2"`, `"… 3"` for repeat generations on the same day. Pure and
/// SwiftData-free so the numbering is unit-tested; the view supplies the existing names and `now`.
enum QuickSessionNaming {

    /// The dated stem a Quick session's name is built on — `"8 Jul"` for 8 July. Locale-aware so it
    /// reads naturally; the calendar/locale are injectable for deterministic tests.
    static func dateLabel(for date: Date, locale: Locale = .current, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    /// The default name for a new Quick session: the dated stem + "Quick Session", disambiguated
    /// against `existing` names so two sessions the same day never collide.
    static func defaultName(existing: [String], date: Date,
                            locale: Locale = .current, calendar: Calendar = .current) -> String {
        let base = "\(dateLabel(for: date, locale: locale, calendar: calendar)) Quick Session"
        return uniqued(base, existing: existing)
    }

    /// `base` if free, else `"base 2"`, `"base 3"`, … — the first suffix not already taken. Trailing
    /// whitespace on the base is trimmed so an empty/blank rename still yields a clean numbered name.
    static func uniqued(_ base: String, existing: [String]) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        let taken = Set(existing)
        guard taken.contains(trimmed) else { return trimmed }
        var index = 2
        while taken.contains("\(trimmed) \(index)") { index += 1 }
        return "\(trimmed) \(index)"
    }
}
