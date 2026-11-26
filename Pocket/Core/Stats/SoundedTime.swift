import Foundation

/// **How long a loop sounded on one visit, and from when** — what Active listening and Improvise log
/// (ADR 0321), the counterpart of `MetronomeRunLog` for the two loop modes.
///
/// Those modes used to log how long their screen was open. Leaving Red Moon doesn't close a screen, so
/// a loop stopped at nine in the evening and the app left in the background logged twelve and a half
/// hours when the sheet was finally closed the next morning (found on the phone's store, 2026-11-26).
/// This counts the audio instead: the loop cycling, or a slice of it playing for Name the notes, and
/// nothing while it is stopped, interrupted, or never started.
///
/// **Pure** — Foundation only, with both clocks passed in — so the rules are unit-tested rather than
/// trusted: a stop banks what sounded, a second start carries on from it, a run is handed back once,
/// and a visit that never played anything logs nothing. The length is counted on the monotonic clock
/// (`PlayClock`), which a change to the phone's time can't stretch; the row's start is a `Date`,
/// because that is what puts it on a day.
struct SoundedTime: Equatable {

    private var clock = PlayClock()

    /// When audio first sounded on this visit: the row's `startedAt`. `nil` until something has.
    private(set) var firstSoundedAt: Date?

    /// Audio started coming out. Counting already is a no-op, so a second start can't count twice.
    mutating func began(at date: Date, uptime: TimeInterval) {
        if firstSoundedAt == nil { firstSoundedAt = date }
        clock.run(at: uptime)
    }

    /// Audio went quiet: stopped on screen or on the lock screen, a slice ended, an interruption. What
    /// sounded is kept. Quiet already is a no-op.
    mutating func ended(uptime: TimeInterval) {
        clock.hold(at: uptime)
    }

    /// The run to log — from the first sound, for as long as it sounded — and start over at nothing.
    /// `nil` when nothing sounded, which is what keeps a visit that never pressed ▶ out of the log and
    /// stops the visit's two seams (Done, then the screen going) from logging it twice.
    ///
    /// Taken while still sounding, it counts up to `uptime` and stops counting: every caller takes it
    /// as the loop is being stopped and the screen torn down.
    mutating func take(uptime: TimeInterval) -> DateInterval? {
        defer { self = SoundedTime() }
        guard let firstSoundedAt else { return nil }
        return DateInterval(start: firstSoundedAt, duration: clock.elapsed(at: uptime))
    }
}
