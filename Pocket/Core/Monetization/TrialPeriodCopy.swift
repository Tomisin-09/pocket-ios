import Foundation

/// Turns a subscription **introductory-offer period** into the words the paywall says (ADR 0144 D5).
///
/// The paywall used to hardcode "14-day" in two places. The live trial length is not in the app at
/// all — it lives in App Store Connect, and `Configuration/RedMoonPro.storekit` only mirrors it for
/// local and simulator testing — so hardcoded copy is a promise the app has no way to keep. This type
/// exists so the number is **read from the product** and rendered in exactly one place.
///
/// Foundation-only and pure, per the "pure logic stays pure" rule (AGENTS.md): `PaywallView` maps
/// StoreKit's `Product.SubscriptionPeriod.Unit` onto `Unit` at the boundary, so the phrasing itself is
/// unit-testable without StoreKit.
enum TrialPeriodCopy {
    /// The period units App Store Connect can express an introductory offer in.
    enum Unit: Equatable {
        case day, week, month, year
    }

    /// The **adjectival** form used before a noun — "Start a 1-month free trial", "Your 3-day free
    /// trial converts…". Hyphenated and always singular, which is what English wants in that position
    /// ("a 2-week trial", never "a 2-weeks trial").
    ///
    /// Returns `nil` for a non-positive `value`, so a malformed product yields *no* trial claim rather
    /// than a nonsense one — callers fall back to trial-free copy.
    static func hyphenated(unit: Unit, value: Int) -> String? {
        guard value > 0 else { return nil }
        return "\(value)-\(noun(unit))"
    }

    private static func noun(_ unit: Unit) -> String {
        switch unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        }
    }
}
