import AVFoundation

/// Reading an `AVAudioSession.interruptionNotification`: has an interruption **begun** — a call, Siri,
/// an alarm, another app's audio taking over? Red Moon's session is `.playback`, which doesn't mix, so
/// any of them stops what Red Moon is playing, and nothing in Red Moon restarts it afterwards.
///
/// Pure and testable without a microphone or a call. Two readers: a take ends when one begins
/// (`RecordingController.endsTake`), and a loop mode stops counting the loop as sounding (ADR 0321).
/// An `.ended`, or a notification without a readable type, is not a beginning.
enum AudioInterruption {
    nonisolated static func began(_ userInfo: [AnyHashable: Any]?) -> Bool {
        guard let raw = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return false }
        return type == .began
    }
}
