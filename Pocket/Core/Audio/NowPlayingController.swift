import MediaPlayer
import UIKit

/// One producer's handle on the system lock screen / Control Center / Dynamic Island: it claims them,
/// pushes `NowPlayingState` while it plays, and lets go when it stops. See ADR 0025, and ADR 0303 for
/// why every producer goes through the shared `NowPlayingHub` rather than writing the global centers
/// itself.
///
/// Scope is deliberately play/pause only (no scrub, no skip): a single-song practice screen has
/// nothing to skip to, and the waveform is the place to seek.
@MainActor
final class NowPlayingController {

    /// This producer's identity among the claims. A token rather than the object's address, because the
    /// `deinit` release lands after that address can already belong to a new controller.
    private let token = UUID()

    /// Claim the lock screen and route its play / pause / toggle to this producer until `teardown`.
    /// Claiming again (the metronome does, on each start) moves it back to the top.
    func activate(onPlay: @escaping @MainActor () -> Void,
                  onPause: @escaping @MainActor () -> Void,
                  onToggle: @escaping @MainActor () -> Void) {
        NowPlayingHub.shared.claim(token, NowPlayingHub.Commands(play: onPlay, pause: onPause, toggle: onToggle))
    }

    /// Push the current Now Playing metadata. Cheap to call often; the system extrapolates the clock
    /// between pushes from `elapsedTime` + `reportedRate`. Shown only while this producer is on top, and
    /// ignored once it has let go.
    func update(_ state: NowPlayingState) {
        NowPlayingHub.shared.update(token, state)
    }

    /// Let go of the lock screen. Must run when the producer stops (see the class note): whoever claimed
    /// before takes it back, or it is cleared.
    func teardown() {
        NowPlayingHub.shared.release(token)
    }

    /// A producer that goes away without `teardown` must not keep a claim whose commands reach nothing.
    deinit {
        let token = token
        Task { @MainActor in NowPlayingHub.shared.release(token) }
    }
}

/// The process's **one** writer of `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` (ADR 0303). Both
/// are process-global singletons, and Red Moon has many producers whose sessions overlap, so the
/// producers hold claims here instead (`NowPlayingClaims`, pure) and this applies the result: the info of
/// whoever is on top, and its commands.
///
/// The remote-command targets are registered once, when the first claim arrives, and removed when the
/// last one goes, so nothing answers the lock screen while nothing plays. They capture no producer:
/// each command is looked up at the moment it arrives, so a closure can't keep an engine alive (the sharp
/// edge ADR 0025 was written about).
@MainActor
final class NowPlayingHub {

    static let shared = NowPlayingHub()

    /// What a producer does when the lock screen asks.
    struct Commands {
        let play: @MainActor () -> Void
        let pause: @MainActor () -> Void
        let toggle: @MainActor () -> Void
    }

    enum Command { case play, pause, toggle }

    private let infoCenter = MPNowPlayingInfoCenter.default()
    private var claims = NowPlayingClaims<UUID>()
    private var commands: [UUID: Commands] = [:]
    private var registrations: [(command: MPRemoteCommand, token: Any)] = []

    /// The Red Moon mark, shown beside every producer: the app's songs are local files with no embedded
    /// cover art, and a tool has none at all (user-testing note 3, 2026-07-20). `DefaultArtwork` is the
    /// App Icon's own render, cut by `scripts/derive-brand-svgs.py --app-icon`, so it follows the icon.
    /// Built once and reused.
    private static let defaultArtwork: MPMediaItemArtwork? = {
        guard let image = UIImage(named: "DefaultArtwork") else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }()

    func claim(_ owner: UUID, _ handlers: Commands) {
        claims.claim(owner)
        commands[owner] = handlers
        registerTargetsIfNeeded()
    }

    func update(_ owner: UUID, _ state: NowPlayingState) {
        apply(claims.update(owner, to: state))
    }

    func release(_ owner: UUID) {
        commands[owner] = nil
        apply(claims.release(owner))
        if claims.isEmpty { removeTargets() }
    }

    /// Hand a lock-screen command to whoever is on top. Returns whether anyone took it. Internal so a
    /// test can drive the routing the system would.
    @discardableResult
    func perform(_ command: Command) -> Bool {
        guard let owner = claims.owner, let handlers = commands[owner] else { return false }
        switch command {
        case .play: handlers.play()
        case .pause: handlers.pause()
        case .toggle: handlers.toggle()
        }
        return true
    }

    /// The title on the lock screen right now, for tests. `nil` when it is clear.
    var shownTitle: String? { infoCenter.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String }

    private func apply(_ display: NowPlayingClaims<UUID>.Display) {
        switch display {
        case .unchanged: break
        case .show(let state): infoCenter.nowPlayingInfo = Self.info(for: state)
        case .clear: infoCenter.nowPlayingInfo = nil
        }
    }

    private static func info(for state: NowPlayingState) -> [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: state.title,
            MPMediaItemPropertyPlaybackDuration: state.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: state.elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: state.reportedRate
        ]
        if !state.artist.isEmpty { info[MPMediaItemPropertyArtist] = state.artist }
        if let artwork = defaultArtwork { info[MPMediaItemPropertyArtwork] = artwork }
        return info
    }

    /// Wire play / pause / toggle and disable the commands we don't support, so the system surfaces no
    /// buttons that do nothing.
    private func registerTargetsIfNeeded() {
        guard registrations.isEmpty else { return }
        let center = MPRemoteCommandCenter.shared()
        register(center.playCommand, .play)
        register(center.pauseCommand, .pause)
        register(center.togglePlayPauseCommand, .toggle)
        for unused in [center.nextTrackCommand, center.previousTrackCommand,
                       center.seekForwardCommand, center.seekBackwardCommand,
                       center.skipForwardCommand, center.skipBackwardCommand] {
            unused.isEnabled = false
        }
        center.changePlaybackPositionCommand.isEnabled = false
    }

    private func removeTargets() {
        for entry in registrations { entry.command.removeTarget(entry.token) }
        registrations.removeAll()
    }

    /// Register one command. Remote command handlers are delivered on the main thread, so hopping to the
    /// main actor with `assumeIsolated` is safe and keeps the handler synchronous; it would trap loudly
    /// if Apple ever changed that, rather than corrupting state quietly.
    private func register(_ command: MPRemoteCommand, _ which: Command) {
        command.isEnabled = true
        let token = command.addTarget { _ in
            let handled = MainActor.assumeIsolated { NowPlayingHub.shared.perform(which) }
            return handled ? .success : .noActionableNowPlayingItem
        }
        registrations.append((command, token))
    }
}
