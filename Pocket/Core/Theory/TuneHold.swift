import Foundation

/// Tracks how long a note has been held continuously **in tune** and reports the instant it has held
/// long enough to *confirm* (ADR 0115 — the "you've nailed it" chime + haptic + celebratory state,
/// the way a hardware/Fender-style tuner locks on). Pure and UI-free: fed each reading with a
/// monotonic timestamp, it decides *when* to fire; the view owns the actual haptic / chime / colour.
///
/// Confirmation is objective (the note held within the in-tune tolerance) — a reference lock, not a
/// grade of playing (ADR 0070).
struct TuneHold {
    /// How long the same note must stay in tune before it's confirmed.
    var requiredHold: TimeInterval

    /// The note currently confirmed in tune, or `nil`. The view shows the celebratory state while set;
    /// it clears the moment the pitch drifts out of tune or moves to a different note.
    private(set) var confirmedMidi: Int?
    private var streakMidi: Int?
    private var streakStart: TimeInterval?

    init(requiredHold: TimeInterval = 0.8) {
        self.requiredHold = requiredHold
    }

    /// Fold in the latest `reading` at monotonic time `now`. Returns `true` **exactly once**, at the
    /// instant the note crosses `requiredHold` seconds in tune — the caller fires the chime/haptic then.
    @discardableResult
    mutating func update(reading: TunerReading?, now: TimeInterval) -> Bool {
        guard let reading, reading.isInTune else {
            reset()                                   // out of tune / silence → drop the streak
            return false
        }
        if streakMidi != reading.midiNote {           // a new (or first) in-tune note → start timing
            streakMidi = reading.midiNote
            streakStart = now
            confirmedMidi = nil
            return false
        }
        guard confirmedMidi != reading.midiNote else { return false }   // already confirmed this note
        if let start = streakStart, now - start >= requiredHold {
            confirmedMidi = reading.midiNote
            return true
        }
        return false
    }

    /// Currently confirmed in tune (drives the celebratory UI).
    var isConfirmed: Bool { confirmedMidi != nil }

    mutating func reset() {
        confirmedMidi = nil
        streakMidi = nil
        streakStart = nil
    }
}
