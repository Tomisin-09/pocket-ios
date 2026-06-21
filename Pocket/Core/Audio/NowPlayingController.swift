import MediaPlayer

/// Bridges the practice transport to the system lock screen / Control Center:
/// owns the `MPRemoteCommandCenter` play/pause targets and pushes
/// `MPNowPlayingInfoCenter` updates. The command center is a process-global
/// singleton, so its targets must be torn down on screen exit — otherwise the
/// closures keep the engine alive and respond to lock-screen taps after the
/// practice view is gone. See ADR 0025.
///
/// Scope is deliberately play/pause only (no scrub, no skip): a single-song
/// practice screen has nothing to skip to, and the waveform is the place to seek.
@MainActor
final class NowPlayingController {

    private let infoCenter = MPNowPlayingInfoCenter.default()
    /// Registered command targets, kept so `teardown` can remove exactly what it
    /// added (rather than clobbering targets another part of the app might own).
    private var registrations: [(command: MPRemoteCommand, token: Any)] = []

    /// Wire the play / pause / toggle commands to the transport and disable the
    /// commands we don't support so the system doesn't surface dead buttons.
    /// Idempotent — re-activating first tears down any prior registration.
    func activate(onPlay: @escaping @MainActor () -> Void,
                  onPause: @escaping @MainActor () -> Void,
                  onToggle: @escaping @MainActor () -> Void) {
        teardown()
        let center = MPRemoteCommandCenter.shared()
        register(center.playCommand, onPlay)
        register(center.pauseCommand, onPause)
        register(center.togglePlayPauseCommand, onToggle)
        for unused in [center.nextTrackCommand, center.previousTrackCommand,
                       center.seekForwardCommand, center.seekBackwardCommand,
                       center.skipForwardCommand, center.skipBackwardCommand] {
            unused.isEnabled = false
        }
        center.changePlaybackPositionCommand.isEnabled = false
    }

    /// Push the current Now Playing metadata. Cheap to call often; the system
    /// extrapolates the clock between pushes from `elapsedTime` + `reportedRate`.
    func update(_ state: NowPlayingState) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: state.title,
            MPMediaItemPropertyPlaybackDuration: state.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: state.elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: state.reportedRate
        ]
        if !state.artist.isEmpty { info[MPMediaItemPropertyArtist] = state.artist }
        infoCenter.nowPlayingInfo = info
    }

    /// Remove our command targets and clear the Now Playing info. Must run when
    /// the practice screen is dismissed (see the class note).
    func teardown() {
        for entry in registrations { entry.command.removeTarget(entry.token) }
        registrations.removeAll()
        infoCenter.nowPlayingInfo = nil
    }

    /// Register one command, returning `.success` synchronously. Remote command
    /// handlers are delivered on the main thread, so hopping to the main actor
    /// with `assumeIsolated` is safe and keeps the handler synchronous.
    private func register(_ command: MPRemoteCommand, _ handler: @escaping @MainActor () -> Void) {
        command.isEnabled = true
        let token = command.addTarget { _ in
            MainActor.assumeIsolated { handler() }
            return .success
        }
        registrations.append((command, token))
    }
}
