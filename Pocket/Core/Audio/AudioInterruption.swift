import AVFoundation

/// Reading an `AVAudioSession.interruptionNotification`: has an interruption **begun** — a call, Siri,
/// an alarm, another app's audio taking over? Red Moon's session is `.playback`, which doesn't mix, so
/// any of them stops what Red Moon is playing, and nothing in Red Moon restarts it afterwards.
///
/// Pure and testable without a microphone or a call. Two readers: a take ends when one begins
/// (`RecordingController.endsTake`), and every transport pauses (ADR 0323, `AudioInterruptionObserver`).
/// An `.ended`, or a notification without a readable type, is not a beginning.
enum AudioInterruption {
    nonisolated static func began(_ userInfo: [AnyHashable: Any]?) -> Bool {
        guard let raw = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return false }
        return type == .began
    }

    /// Reading an `AVAudioSession.routeChangeNotification`: has the output Red Moon was playing through
    /// **gone away** — headphones pulled out, AirPods put back in their case, a car disconnected? Apple's
    /// rule for a player is to pause then rather than carry on out of the speaker, and the manual already
    /// said the song player's ramp sheet does (ADR 0323 D4). Any other reason, a new device arriving or
    /// the category changing for a take, is not one.
    nonisolated static func outputWentAway(_ userInfo: [AnyHashable: Any]?) -> Bool {
        guard let raw = userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return false }
        return reason == .oldDeviceUnavailable
    }
}

/// **Calls `onCut` on the main actor each time Red Moon's audio is cut from outside**: an interruption
/// beginning, or the output going away (ADR 0323), for as long as it is kept. What lets an engine pause
/// itself when the system has stopped it: the two audio engines and the take player each hold one, so
/// no screen has to remember to listen, and a screen that plays one of them for something that isn't
/// practice (*Watch it on the neck*) is covered too.
///
/// A class, so letting go of it stops the observing: the engine that holds it can't remove an observer
/// from its own `deinit`, which Swift 6 keeps off the main actor. Nothing resumes when an interruption
/// ends (ADR 0323 D2), so there is no second callback.
final class AudioInterruptionObserver {
    private let tokens: [NSObjectProtocol]

    init(onCut: @escaping @MainActor @Sendable () -> Void) {
        // On the main queue, as `KeyboardDismissAccessory` observes: nothing promises the session posts
        // there, and a route change arrives on a queue of its own.
        let center = NotificationCenter.default
        tokens = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
                guard AudioInterruption.began(note.userInfo) else { return }
                MainActor.assumeIsolated { onCut() }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { note in
                guard AudioInterruption.outputWentAway(note.userInfo) else { return }
                MainActor.assumeIsolated { onCut() }
            }
        ]
    }

    deinit {
        for token in tokens { NotificationCenter.default.removeObserver(token) }
    }
}
