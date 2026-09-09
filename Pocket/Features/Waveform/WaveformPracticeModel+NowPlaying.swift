import Foundation

// MARK: - Playback lifecycle & Now Playing (ADR 0025)
//
// Split out of `WaveformPracticeModel.swift` for the 400-line budget, which ADR 0201 had already
// spent down to the last line. This is the cleanest seam in the model: five members that only talk
// to the lock screen and the screen's own entry/exit, and nothing on the playhead's path.
//
// `nowPlayingState` and `wipeTransientState` lose their `private` in the move — Swift has no
// cross-file-private for a single type, the same reason `gridCache` is `internal`. Neither is
// called from anywhere but this file.

extension WaveformPracticeModel {

    /// A snapshot for the lock screen / Control Center, built from the song's
    /// metadata and the engine's live transport.
    var nowPlayingState: NowPlayingState {
        NowPlayingState(title: song.title, artist: song.artist,
                        duration: duration, elapsedTime: engine.currentTime,
                        isPlaying: engine.isPlaying, speed: speed)
    }

    /// Begin the lock-screen session: wire the remote play/pause commands to the
    /// transport and push the initial metadata. Called once the view appears.
    /// Skipped in previews (no audio session, no command center worth touching).
    func beginPlaybackSession() {
        guard !isPreview else { return }
        // Stamp the practice session (ADR 0044): opening the song to practise marks it as the
        // most-recently-practised — the home "Jump back in" card and the library's "recently
        // practised" ordering both read this. SwiftData autosaves the tracked song.
        song.lastPracticed = .now
        nowPlaying.activate(onPlay: { [weak self] in self?.engine.play() },
                            onPause: { [weak self] in self?.engine.pause() },
                            onToggle: { [weak self] in self?.engine.togglePlay() })
        refreshNowPlaying(force: true)
    }

    /// Push current metadata to the lock screen. `force` for transport/rate/seek
    /// events; the un-forced playhead tick is throttled so the 30 Hz timer doesn't
    /// rebuild the info dictionary on every frame (the system extrapolates between
    /// pushes from the elapsed time + reported rate).
    func refreshNowPlaying(force: Bool = false) {
        guard !isPreview else { return }
        let now = Date()
        if !force, now.timeIntervalSince(lastNowPlayingPush) < 0.5 { return }
        lastNowPlayingPush = now
        nowPlaying.update(nowPlayingState)
    }

    /// Stop-on-exit (ADR 0025): remove the remote-command targets, clear the Now
    /// Playing info, and tear the engine down so audio halts immediately as the
    /// screen is dismissed — rather than lingering until the model deallocs (and
    /// the global command center would otherwise keep the engine alive).
    func endPlaybackSession() {
        nowPlaying.teardown()
        engine.onReachedEnd = nil       // the repeat hook must not outlive the screen (ADR 0124)
        engine.stop()
        // Finalise a delete still sitting in its undo window (ADR 0125) — leaving the
        // screen closes the window, rather than carrying a hidden-but-alive row into the
        // next visit. Nothing is lost if this is missed; the delete simply doesn't happen.
        commitDeferredDeletes()
        wipeTransientState()
    }

    /// Wipe-on-exit (ADR 0029): reset the transient practice state so a later entry
    /// can't inherit a stale loop/speed/click. The model is normally recreated per
    /// entry, so this is belt-and-suspenders — but it makes the lifecycle contract
    /// explicit and survives any future model reuse. Persisted song data (BPM,
    /// downbeat, saved loops/markers) is **never** touched — only the session knobs.
    func wipeTransientState() {
        // Bank the full-song resume tempo before clearing (ADR 0044). With no loop armed,
        // `speed` is the song's own tempo, so persist it; with a loop armed, the song's speed
        // was banked when that loop armed, and `activeLoopID = nil` below restores it via the
        // didSet (no re-bank needed). Persisted song data is otherwise untouched (ADR 0029).
        if activeLoopID == nil { song.lastPracticedSpeed = speed }
        activeLoopID = nil
        speed = 1.0
        if metronomeOn { metronomeOn = false }
        repeatsSong = false
        abSpan = .idle
        abEditingLoop = nil
        loopSelection.end()             // selection is a session mode too (ADR 0125)
        markerSelection.end()
    }
}
