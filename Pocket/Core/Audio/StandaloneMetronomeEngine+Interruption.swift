import AVFoundation

// MARK: - An interruption pauses the click (ADR 0323)
//
// A call, Siri, an alarm or another app's audio stops Red Moon's audio: the session is `.playback`,
// which doesn't mix. The system stops this engine without telling it, so until ADR 0323 the transport
// stayed `.playing` over silence: the Metronome's ■ stayed lit, an exercise run's ramp went on climbing
// with nothing heard, and the Metronome's practice-log count (ADR 0242, the time the click sounded) ran
// on for as long as the player was away. The output going away (headphones pulled out) pauses it too
// (D4). Split out of the core file for the 400-line budget; the
// observer and the flag it sets are stored there.

extension StandaloneMetronomeEngine {

    /// The engine has been stopped under the click: pause, exactly as the on-screen Pause does, so the
    /// session clock banks what sounded, a ramp holds its plateau, and Resume carries on from there.
    /// Nothing resumes by itself (ADR 0323 D2).
    func wasInterrupted() {
        sessionNeedsReassert = true
        pause()
    }

    /// Before a resume: bring back what the interruption took. The system deactivated the session and
    /// stopped the engine, and `pause` never stops it, so without this a resume would light the transport
    /// over silence again. A `start` reasserts the session already (`configureSession`).
    func restartAudioIfInterrupted() {
        guard sessionNeedsReassert else { return }
        sessionNeedsReassert = false
        AudioPlumbing.ensurePlaybackSession(label: "metronome")
        startEngineIfNeeded()
    }

    // Two tempo conveniences, here for the core file's line budget.

    /// Nudge the tempo by `delta` BPM (the −/+ steppers).
    func adjustBPM(by delta: Int) { setBPM(bpm + delta) }

    /// The Italian tempo marking for the current tempo (ADR 0043, slice 1).
    var tempoMarking: TempoMarking { TempoMarking.marking(forBPM: Double(bpm)) }
}
