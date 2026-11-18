import Foundation

// **Another key** (ADR 0305): the engine's one pitch control, split out for file length.
extension PracticeAudioEngine {
    /// Move the audio by whole semitones, live if sounding, held within six of the recording by the
    /// stretcher. Time doesn't move, so unlike a rate change nothing queued needs flushing: the click
    /// bypasses the stretcher and keeps its pitch.
    func setPitch(semitones: Int) {
        stretcher.setPitch(semitones: semitones)
    }
}
