import Foundation

/// Appearance override for the app's colour scheme (ADR 0062 follow-up). `.system`
/// (the default) follows the device setting, as ADR 0062 originally shipped; `.light`/
/// `.dark` pin the app regardless of the device, both to aid testing across appearances
/// on one device and as a standing user preference. `RawRepresentable` with a `String`
/// raw value so it works directly with `@AppStorage`.
enum AppearancePreference: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

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
        static let appearance = "appearance"
        static let exerciseAnimates = "exerciseAnimates"
        static let strumClickFollowsPattern = "strumClickFollowsPattern"
        static let routineAutoStart = "routineAutoStart"
        static let routineAutoAdvance = "routineAutoAdvance"
        static let routineRestSeconds = "routineRestSeconds"
        static let routineSongLoop = "routineSongLoop"
        static let transportLoopOnLeft = "transportLoopOnLeft"
        static let waveformMinimapVisible = "waveformMinimapVisible"
    }

    /// Count-in length is offered as whole bars in this range.
    static let countInBarsRange = 1...2

    /// The between-blocks rest countdown is offered in this range of seconds.
    static let routineRestSecondsRange = 5...60

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

    /// Whether an exercise's walking highlight animates — the fretboard board and the strum lane
    /// both read this. Default **off** as a photosensitivity precaution; the views also force it off
    /// under the system Reduce Motion setting.
    static var exerciseAnimates: Bool { bool(Key.exerciseAnimates, default: false) }

    /// For a strumming / Strum & Chords drill, whether the run's metronome **follows the strum
    /// pattern** (down/up/accent/mute, rests silent — ADR 0071 R5) rather than a plain steady click.
    /// Default on; off ⇒ a standard metronome, so you produce the rhythm against a neutral pulse. The
    /// preview's "Hear the strum" button always plays the pattern regardless.
    static var strumClickFollowsPattern: Bool { bool(Key.strumClickFollowsPattern, default: true) }

    /// In a routine, auto-start each block on arrival (ADR 0071) — the **first** block always waits
    /// for a deliberate Start; this only governs the *subsequent* ones. Default on; off ⇒ every block
    /// is started by hand.
    static var routineAutoStart: Bool { bool(Key.routineAutoStart) }

    /// In a routine, whether a finished block **auto-advances** to the next one (ADR 0071 R4).
    /// Default **off** ⇒ a naturally-finished unit lands on a Done screen (optional mastery tap +
    /// inline note) that you dismiss with Continue/Finish — manual advance. On ⇒ it advances on its
    /// own, no Done gate (a deliberate Skip always bypasses the gate regardless).
    static var routineAutoAdvance: Bool { bool(Key.routineAutoAdvance, default: false) }

    /// In a routine, whether a **song block loops** and advances only when you Skip (ADR 0071) — a
    /// song is an open jam, so this is on by default. Off ⇒ a song plays through once and then
    /// auto-advances (a song carries no journal, so it never shows the Done gate).
    static var routineSongLoop: Bool { bool(Key.routineSongLoop) }

    /// How long the between-blocks rest countdown lasts, seconds (clamped to
    /// `routineRestSecondsRange`). Default 20.
    static var routineRestSeconds: Int {
        let resolved = resolvedInt(
            storedValue: UserDefaults.standard.object(forKey: Key.routineRestSeconds), default: 20)
        return min(routineRestSecondsRange.upperBound,
                   max(routineRestSecondsRange.lowerBound, resolved))
    }

    /// Which side the big idle **Loop** button sits on in the practice transport bar; the Marker
    /// takes the other side. Default **off** ⇒ Marker-left / Loop-right (the shipped arrangement);
    /// on ⇒ swapped. Applies to the idle flanking controls only.
    static var transportLoopOnLeft: Bool { bool(Key.transportLoopOnLeft, default: false) }

    /// Whether the full-song **minimap** strip shows under the detail waveform on the practice
    /// screen (P1c). Default **on** — it's the whole-song overview + scrub; off ⇒ hidden to give
    /// the waveform + loops a little more vertical room.
    static var waveformMinimapVisible: Bool { bool(Key.waveformMinimapVisible, default: true) }

    /// Appearance override. Default `.system` — the app follows the device setting until
    /// the user opts into a pinned light/dark appearance.
    static var appearance: AppearancePreference {
        resolvedAppearance(storedValue: UserDefaults.standard.string(forKey: Key.appearance))
    }

    /// Pure default-resolution: a missing or unrecognised stored value falls back to
    /// `.system` rather than crashing on a bad raw value.
    static func resolvedAppearance(storedValue: String?) -> AppearancePreference {
        guard let storedValue else { return .system }
        return AppearancePreference(rawValue: storedValue) ?? .system
    }

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
