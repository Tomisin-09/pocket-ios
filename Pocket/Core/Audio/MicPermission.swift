import AVFoundation

/// Microphone permission for practice-take recording (ADR 0069 §4), on the iOS 17+
/// `AVAudioApplication` flow (the `AVAudioSession.requestRecordPermission` variant is
/// deprecated). Thin wrapper so call sites don't repeat the enum mapping; the system
/// prompt text comes from `NSMicrophoneUsageDescription` in Info.plist.
enum MicPermission {

    /// Simplified view over `AVAudioApplication.recordPermission`.
    enum Status: Equatable {
        /// Not asked yet — arming a take should trigger the system prompt via `request()`.
        case undetermined
        /// Granted; recording can proceed.
        case granted
        /// Denied — the take can't record; the UI should point to Settings.
        case denied
    }

    /// Current permission without prompting.
    static var status: Status {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined: return .undetermined
        case .granted: return .granted
        case .denied: return .denied
        @unknown default: return .denied
        }
    }

    /// Ask for permission, showing the system prompt only on first use. Returns whether
    /// recording is allowed.
    static func request() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}
