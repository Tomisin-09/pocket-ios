import Foundation

/// **What the journal hands back unprompted** (ADR 0207 D8) — one entry from a year ago, found by
/// date and by nothing else.
///
/// ### Why this is allowed to exist at all
///
/// ADR 0190 D1 refused auto-pinning on the grounds that *"an app that decided which of your practice
/// mattered would be grading your practice"*, and that refusal binds anything that picks an entry on
/// the player's behalf. This picks by **date proximity**, which is the one axis that carries no
/// opinion — the same axis ADR 0190 D9 already blessed for the jump. Nothing here reads `kind`,
/// `isPinned`, mastery, tempo, or length. Two entries an equal distance from the anniversary are
/// separated by which is newer, never by which is *better*, because there is no such comparison
/// available to make.
///
/// ADR 0176 refused a summary strip above the timeline because it *"puts a permanent number above a
/// timeline whose entire content is words"*. This carries **words**, and it scrolls with the feed
/// rather than sitting above it, so the objection is affirmed rather than dodged.
///
/// ### The ladder, and why it is not just "a year ago today"
///
/// An exact anniversary is empty on most days — the card would almost never appear and the feature
/// would quietly die. So the search widens: the day, then the week around it, then the month. **The
/// heading names the rung it found**, so the card never claims a precision it does not have.
///
/// Pure and `Calendar`-injected, like every other date type in this feature.
enum JournalLookback {

    /// How far back to look. Stored as a raw `String` so it can cross `@AppStorage` (the same
    /// requirement `JournalTimeline.Scope` and `SortOrder` took on in ADR 0190).
    enum Period: String, CaseIterable, Identifiable {
        case off
        case sixMonths
        case oneYear
        case twoYears

        var id: String { rawValue }

        /// The player's words, not the model's.
        var label: String {
            switch self {
            case .off: return "Off"
            case .sixMonths: return "6 months ago"
            case .oneYear: return "A year ago"
            case .twoYears: return "2 years ago"
            }
        }

        /// The offset applied to today. `nil` for `.off`, which is what makes "no card" a value
        /// rather than a branch every caller has to remember.
        var components: DateComponents? {
            switch self {
            case .off: return nil
            case .sixMonths: return DateComponents(month: -6)
            case .oneYear: return DateComponents(year: -1)
            case .twoYears: return DateComponents(year: -2)
            }
        }

        /// Written **once**, so the `@AppStorage` initialiser and this enum cannot drift — the
        /// duplicated-default trap this project has already paid for.
        static let `default`: Period = .oneYear

        /// Unrecognised or absent raw values fall back to the default, matching `EntryKind(raw:)`.
        init(raw: String) { self = Period(rawValue: raw) ?? .default }
    }

    /// Which rung of the ladder produced the hit — the card's heading comes from this, so a widened
    /// search always admits it widened.
    enum Reach {
        case day
        case week
        case month

        /// "A year ago today" / "…this week" / "…this month", built from the period's own label so
        /// the two halves can never disagree about how far back this is.
        func heading(for period: Period) -> String {
            switch self {
            case .day: return "\(period.label) today"
            case .week: return "\(period.label) this week"
            case .month: return "\(period.label) this month"
            }
        }
    }

    /// One found entry, and how hard we had to look for it.
    struct Hit<Element> {
        let element: Element
        let reach: Reach
        /// The day the entry was written — what tapping the card scrolls to.
        let day: Date
    }

    /// Find something to hand back, or `nil`.
    ///
    /// - Parameters:
    ///   - items: candidates with their dates. Passed as pairs rather than as models so this stays
    ///     free of SwiftData and testable without a container.
    ///   - now: today.
    ///   - period: how far back to look; `.off` always returns `nil`.
    ///
    /// **Deterministic.** The same store on the same day yields the same card — a look-back that
    /// reshuffled on every redraw would be a slot machine, and would make the feed's top row change
    /// under the reader's eyes as they scrolled.
    static func find<Element>(in items: [(element: Element, date: Date)],
                              now: Date = Date(),
                              period: Period = .default,
                              calendar: Calendar = .current) -> Hit<Element>? {
        guard let offset = period.components,
              let anchor = calendar.date(byAdding: offset, to: now) else { return nil }

        let anchorDay = calendar.startOfDay(for: anchor)
        let dated = items.map { (element: $0.element, day: calendar.startOfDay(for: $0.date)) }
        guard !dated.isEmpty else { return nil }

        // The rungs, narrowest first. Each is a plain predicate over the day — no scoring, no
        // ranking, nothing that could become a judgement about the entry itself.
        let rungs: [(Reach, (Date) -> Bool)] = [
            (.day, { $0 == anchorDay }),
            (.week, { calendar.isDate($0, equalTo: anchorDay, toGranularity: .weekOfYear) }),
            (.month, { calendar.isDate($0, equalTo: anchorDay, toGranularity: .month) })
        ]

        for (reach, matches) in rungs {
            let found = dated.filter { matches($0.day) }
            // Nearest the anniversary; ties to the more recent. Both are date comparisons — the
            // tiebreak deliberately reaches for another date rather than for any property of the
            // entry, because the moment it reads `kind` or `isPinned` this becomes the app choosing
            // which of your practice mattered (ADR 0190 D1).
            let best = found.min {
                let left = abs($0.day.timeIntervalSince(anchorDay))
                let right = abs($1.day.timeIntervalSince(anchorDay))
                return left == right ? $0.day > $1.day : left < right
            }
            if let best { return Hit(element: best.element, reach: reach, day: best.day) }
        }
        return nil
    }
}
