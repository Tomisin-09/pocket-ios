import Foundation

/// The **slice** a tap plays back in Name the notes (ADR 0225): a moment of the real recording from just
/// before the tap, so the player hears what is actually there. If the tap was late, the slice starts on
/// the note; if it was early, the slice says that too. Nothing is detected or snapped.
///
/// Pure and SwiftUI-free, so the window and the envelope are unit-tested. The envelope is what keeps a
/// slice from clicking: it starts and ends at silence by construction, sample by sample, rather than
/// relying on a volume ramp that only moves once per render cycle.
enum AudioSlice {

    /// How far before the tap the slice starts, in song seconds. Enough to hear the note arrive.
    static let preroll: TimeInterval = 0.08
    /// How much of the song a slice plays, in song seconds. At a slowed tempo it lasts longer in the
    /// room, which is the point of slowing down.
    static let length: TimeInterval = 0.35
    /// A fade-in short enough to keep the attack, long enough that the first sample isn't a step.
    static let fadeIn: TimeInterval = 0.005
    /// The fade at the end, inside `length`.
    static let fadeOut: TimeInterval = 0.06

    /// The stretch of the song to play for a tap at `tap` seconds, clamped to the song. `nil` when the
    /// song has no length.
    static func window(tap: TimeInterval, duration: TimeInterval) -> (start: TimeInterval, length: TimeInterval)? {
        window(from: tap, to: tap, duration: duration)
    }

    /// The stretch for a **phrase** (ADR 0227 D2): from just before its `first` tap to where the `last`
    /// tap's own slice ends, so a phrase ends on its note exactly as that note's slice does. One tap is
    /// the plain slice.
    static func window(from first: TimeInterval, to last: TimeInterval,
                       duration: TimeInterval) -> (start: TimeInterval, length: TimeInterval)? {
        guard duration > 0 else { return nil }
        let start = min(max(0, first - preroll), duration)
        let end = min(max(start, last - preroll) + length, duration)
        return end > start ? (start, end - start) : nil
    }

    /// The song second the ear is hearing while a slice plays, or `nil` before its first sound has
    /// reached the ear. Held at the slice's end through the silence padded after it.
    static func heardSecond(_ reading: SliceClockReading) -> TimeInterval? {
        // Wall-clock latency hides less of the song when it's slowed, as on the loop (`TapTally`).
        let heard = reading.elapsed - reading.outputLatency * reading.rate
        guard heard >= 0 else { return nil }
        return reading.start + min(heard, reading.length)
    }

    /// The gain for one frame of a slice `frameCount` frames long: a linear rise over the first
    /// `fadeInFrames`, unity through the middle, a linear fall over the last `fadeOutFrames`. The first
    /// frame and the last are both **0**, which is what makes it click-free at either end. When the
    /// slice is shorter than both fades, the two ramps meet and the smaller gain wins.
    static func gain(frame: Int, frameCount: Int, fadeInFrames: Int, fadeOutFrames: Int) -> Float {
        guard frameCount > 0, frame >= 0, frame < frameCount else { return 0 }
        let rise = fadeInFrames > 0 ? Float(frame) / Float(fadeInFrames) : 1
        let fall = fadeOutFrames > 0 ? Float(frameCount - 1 - frame) / Float(fadeOutFrames) : 1
        return min(1, rise, fall)
    }
}

/// A slice's clock (ADR 0227 D2), read so the naming strip can ring each note of a phrase as it sounds.
/// The slice's counterpart of `LoopClockReading`: one pass, played once, so nothing wraps.
struct SliceClockReading: Equatable, Sendable {
    /// Source seconds of the slice played so far, already pulled back through the time-stretcher's
    /// latency (ADR 0140 §3), as the loop's clock is.
    var elapsed: TimeInterval
    /// Where the slice starts in the song, in seconds.
    var start: TimeInterval
    /// How much of the song it plays, in source seconds.
    var length: TimeInterval
    /// Playback rate, × of original.
    var rate: Double
    /// Wall-clock seconds from a rendered buffer to the ear.
    var outputLatency: TimeInterval
}
