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
        guard duration > 0 else { return nil }
        let start = min(max(0, tap - preroll), duration)
        let length = min(Self.length, duration - start)
        return length > 0 ? (start, length) : nil
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
