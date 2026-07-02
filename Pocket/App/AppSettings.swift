import Foundation

/// Persisted user preferences (Settings V1, ADR 0050). A thin `UserDefaults` wrapper so both
/// SwiftUI (`@AppStorage` on the same key) and plain engine code (the metronome, the haptic
/// helper) can read a setting without sharing an object. Keys default to **on** when never set —
/// `UserDefaults.bool` returns `false` for a missing key, so reads route through the pure
/// `resolvedBool` to honour the intended default instead of silently reading off.
///
/// UserDefaults is already declared in the privacy manifest (CA92.1), so this adds no new
/// required-reason API and needs no migration.
enum AppSettings {
    enum Key {
        static let hapticsEnabled = "hapticsEnabled"
        static let countInEnabled = "countInEnabled"
        static let countInBars = "countInBars"
        static let keepScreenAwake = "keepScreenAwake"
    }

    /// Count-in length is offered as whole bars in this range.
    static let countInBarsRange = 1...2

    /// Gesture-confirmation haptics on/off. Default on.
    static var hapticsEnabled: Bool { bool(Key.hapticsEnabled) }

    /// One-bar count-in before a tempo climb / exercise run. Default on.
    static var countInEnabled: Bool { bool(Key.countInEnabled) }

    /// How many bars the count-in lasts (clamped to `countInBarsRange`). Default 1.
    static var countInBars: Int {
        let resolved = resolvedInt(storedValue: UserDefaults.standard.object(forKey: Key.countInBars),
                                   default: countInBarsRange.lowerBound)
        return min(countInBarsRange.upperBound, max(countInBarsRange.lowerBound, resolved))
    }

    /// Keep the screen awake on the practice/metronome surfaces. Default on — you play
    /// along hands-free, so the screen auto-locking mid-session is the wrong default.
    static var keepScreenAwake: Bool { bool(Key.keepScreenAwake) }

    private static func bool(_ key: String, default fallback: Bool = true,
                             store: UserDefaults = .standard) -> Bool {
        resolvedBool(storedValue: store.object(forKey: key), default: fallback)
    }

    /// Pure default-resolution: a missing key (`nil`) takes the default; a set key reads as its
    /// stored `Bool`. Split out so the "unset ⇒ default, not `false`" rule is unit-testable.
    static func resolvedBool(storedValue: Any?, default fallback: Bool) -> Bool {
        guard let storedValue else { return fallback }
        return (storedValue as? Bool) ?? fallback
    }

    /// Pure default-resolution for an integer setting — a missing key takes the default rather
    /// than `UserDefaults.integer`'s `0`. Caller clamps to the valid range.
    static func resolvedInt(storedValue: Any?, default fallback: Int) -> Int {
        guard let storedValue else { return fallback }
        return (storedValue as? Int) ?? fallback
    }
}
