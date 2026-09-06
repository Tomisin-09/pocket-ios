import Foundation

/// Pure seek-by-seconds maths for the transport's −/+ skip buttons (ADR 0124, ADR 0192).
///
/// The transport's outer glyphs are **timed skips** in both states — moving freely through what is
/// playing matters more than the one-tap restart and the loop-to-loop steps they replace (ADR 0192).
/// What changes with an armed loop is not the meaning but the **bounds**: a skip is clamped to the
/// armed region, never to the whole song. UI-free so the clamping and the increment cycle are
/// unit-testable without an engine.
enum TransportSkip {

    /// The increments offered on the buttons' hold menu, in seconds. `60` reads as "1 minute".
    static let increments: [TimeInterval] = [5, 10, 15, 30, 60]

    /// The increment a player gets before touching the menu.
    static let defaultIncrement: TimeInterval = 10

    /// Where a skip of `delta` seconds from `current` lands — **clamped to `bounds`**, so a skip
    /// near either end lands on the boundary rather than running off it. `bounds` is whatever is
    /// playing: the song, or the armed loop's region (`bounds(loopRegion:duration:)`). A skip from
    /// outside the bounds lands *on* the near edge, which is the only sane reading of "move me
    /// through this region" when the playhead isn't in it yet.
    static func target(from current: TimeInterval, by delta: TimeInterval,
                       within bounds: ClosedRange<TimeInterval>) -> TimeInterval {
        (current + delta).clamped(to: bounds)
    }

    /// What a skip is clamped to — **the armed loop region if there is one, else the whole song**
    /// (ADR 0192). An armed loop plays as a pre-rendered crossfaded buffer (ADR 0008), so a skip
    /// past its end is not a seek but a disarm; clamping is what keeps one gesture meaning one
    /// thing. A zero-length song (audio not yet loaded) has nowhere to go, and a degenerate or
    /// out-of-song region is no place to confine the playhead — both fall back rather than trap it.
    static func bounds(loopRegion: (start: TimeInterval, end: TimeInterval)?,
                       duration: TimeInterval) -> ClosedRange<TimeInterval> {
        guard duration > 0 else { return 0...0 }
        guard let region = loopRegion else { return 0...duration }
        let start = region.start.clamped(to: 0...duration)
        let end = region.end.clamped(to: 0...duration)
        return end > start ? start...end : 0...duration
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
