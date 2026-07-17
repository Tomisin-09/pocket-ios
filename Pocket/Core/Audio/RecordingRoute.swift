import AVFoundation

/// How a practice take will turn out given the **current output route** (ADR 0069 §2).
///
/// With mic-only capture the app's loop/song couples into the recording *acoustically,
/// not digitally* — the only path is speaker → air → mic. So isolation is a function of
/// where the sound is coming out, not a DSP feature we build. This type is the pure
/// classification of that route; the live session read (`currentRoute.outputs`) stays at
/// the call site so this stays unit-testable (AGENTS.md: pure logic must be tested).
enum RecordingRoute: Equatable {

    /// A private listening device (headphones / Bluetooth / wired interface): the backing
    /// track never enters the room, so the mic hears only the guitar — a clean take of just
    /// the user's playing, for free, by construction.
    case cleanIsolated

    /// Output goes to a speaker in the room (built-in speaker, AirPlay, car audio, or an
    /// unknown route). The backing track travels through the air into the mic, so the take
    /// captures the guitar **plus** whatever is playing behind it. Also the copyright-sensitive
    /// case — that bleed bakes a copy of the source into the file (ADR 0001/0064), which is why
    /// this is only ever a private, un-shared, un-mixed artifact and the UI nudges toward
    /// headphones.
    case speakerBleed

    /// Output ports we can guarantee are private listening devices — the loop is *not* in the
    /// room. Anything not in this set (built-in speaker, AirPlay, car audio, HDMI, unknown) is
    /// treated as bleed: when unsure, warn rather than promise isolation we can't deliver.
    private static let privateListeningPorts: Set<AVAudioSession.Port> = [
        .headphones, .bluetoothA2DP, .bluetoothLE, .usbAudio, .lineOut
    ]

    /// Classify from the route's output port types. Clean only when the route is *entirely*
    /// private listening devices; an empty route (unknown) or any speaker output → bleed.
    static func classify(outputs: [AVAudioSession.Port]) -> RecordingRoute {
        guard !outputs.isEmpty else { return .speakerBleed }
        return outputs.allSatisfy(privateListeningPorts.contains) ? .cleanIsolated : .speakerBleed
    }

    /// Classify from the live shared session's current output route.
    static func current(_ session: AVAudioSession = .sharedInstance()) -> RecordingRoute {
        classify(outputs: session.currentRoute.outputs.map(\.portType))
    }

    /// Whether the take will capture only the user's playing.
    var isClean: Bool { self == .cleanIsolated }

    /// The honesty cue shown while a take is armed — nudges toward headphones on a bleed route,
    /// confirms a clean take otherwise. `nil` means nothing to say (clean by construction).
    var nudge: String? {
        switch self {
        case .cleanIsolated: return nil
        case .speakerBleed:
            return "Use headphones for a clean recording of just your playing — "
                 + "otherwise the backing track in the room is captured too."
        }
    }
}
