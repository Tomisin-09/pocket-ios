import Foundation

/// Pure seek-by-seconds maths for the transport's −/+ skip buttons (ADR 0124).
///
/// With no loop armed the transport's rewind/forward glyphs become **timed skips** — moving
/// freely inside the waveform matters more than the one-tap restart they replace. UI-free so the
/// clamping and the increment cycle are unit-testable without an engine.
enum TransportSkip {

    /// The increments offered on the buttons' hold menu, in seconds. `60` reads as "1 minute".
    static let increments: [TimeInterval] = [5, 10, 15, 30, 60]

    /// The increment a player gets before touching the menu.
    static let defaultIncrement: TimeInterval = 10

    /// Where a skip of `delta` seconds from `current` lands — **clamped to the song**, so a skip
    /// near either end lands on the boundary rather than running off it. A zero-length song (audio
    /// not yet loaded) has nowhere to go.
    static func target(from current: TimeInterval, by delta: TimeInterval,
                       duration: TimeInterval) -> TimeInterval {
        guard duration > 0 else { return 0 }
        return (current + delta).clamped(to: 0...duration)
    }

    /// Resolve a stored increment (whole seconds) onto the offered set — an unrecognised value
    /// (hand-edited defaults, a future build's extra step) falls back rather than skipping by it.
    static func resolved(seconds: Int) -> TimeInterval {
        let value = TimeInterval(seconds)
        return increments.contains(value) ? value : defaultIncrement
    }

    /// The circular-arrow glyph for an increment: SF Symbols ships `gobackward.N` / `goforward.N`
    /// for exactly the steps offered here, so the button *shows* its amount instead of captioning it.
    static func symbol(increment: TimeInterval, forward: Bool) -> String {
        let base = forward ? "goforward" : "gobackward"
        guard increments.contains(increment) else { return base }
        return "\(base).\(Int(increment.rounded()))"
    }

    /// Menu / VoiceOver wording for an increment — "1 minute" rather than "60 seconds".
    static func label(increment: TimeInterval) -> String {
        let whole = Int(increment.rounded())
        return whole >= 60 ? "1 minute" : "\(whole) seconds"
    }
}
