import AVFoundation

// MARK: - The practice log (ADR 0322)
//
// The song player logs the time its audio sounded: a saved loop being played as a run on that loop,
// and the rest as Exploring, on the song. `SongPlayerTime` holds the rules and is unit-tested; this
// file tells it what is sounding, and writes what it hands back when the screen closes.
//
// **The model counts, not the view** (ADR 0321 D2's reason). A pause from the lock screen while Red
// Moon is in the background reaches the engine at once, through `onPlayingChange`, where a view's
// `onChange` may not run until the app comes back, and the count would run on over the silence.
//
// **The model counts, not the engine** (ADR 0242 D3's reason). The same engine plays the loop trainer
// and the song play-along, which log their own runs. Only the song player sets the hook.

extension WaveformPracticeModel {

    /// What the practice log counts as sounding right now (the rule is `SongPlayerTime.sounding`).
    var soundingForLog: SongPlayerTime.Sounding? {
        SongPlayerTime.sounding(isPlaying: engine.isPlaying, silenced: silencedByInterruption,
                                armedLoop: activeLoopID, spanOpen: abSpan != .idle)
    }

    /// Bring the count up to date. Called after every change that could move `soundingForLog`: the
    /// transport, the armed loop, the A/B span, an interruption. A call that changes nothing is free.
    func syncPlayedTime() {
        playedTime.update(soundingForLog, at: .now, uptime: PlayClock.now)
    }

    /// Start counting, as the screen's playback session begins.
    func beginCountingPlayedTime() {
        engine.onPlayingChange = { [weak self] in
            // The transport moved, so whatever it says now is what is heard (ADR 0321 D3).
            self?.silencedByInterruption = false
            self?.syncPlayedTime()
        }
        // A call or another app's audio stops the engine without telling it, and `isPlaying` stays
        // true over the silence. On the main queue, as `KeyboardDismissAccessory` observes. A session
        // begun twice keeps one observer.
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard AudioInterruption.began(note.userInfo) else { return }
            MainActor.assumeIsolated { self?.audioWasInterrupted() }
        }
        syncPlayedTime()
    }

    /// An interruption has begun: stop counting until the transport next moves.
    func audioWasInterrupted() {
        silencedByInterruption = true
        syncPlayedTime()
    }

    /// Stop counting and write the visit's runs. Called as the screen closes, **before** the engine is
    /// torn down and the session knobs are wiped, so the armed loop is still known. A loop's run is
    /// named from `song.loops` rather than `loops`, so one deleted inside its undo window still has the
    /// name it was played under.
    func logPlayedTime() {
        engine.onPlayingChange = nil
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        interruptionObserver = nil
        let runs = playedTime.take(uptime: PlayClock.now)
        guard !isPreview else { return }
        for run in runs.loops {
            PracticeLogWriter.log(kind: .songPlayerLoop,
                                  startedAt: run.interval.start,
                                  endedAt: run.interval.end,
                                  unitUID: run.loopUID,
                                  songSourceID: song.sourceID,
                                  unitLabel: song.loops.first { $0.uid == run.loopUID }?.name,
                                  into: context)
        }
        if let explored = runs.exploring {
            PracticeLogWriter.log(kind: .exploring,
                                  startedAt: explored.start,
                                  endedAt: explored.end,
                                  unitUID: nil,
                                  songSourceID: song.sourceID,
                                  unitLabel: song.title,
                                  into: context)
        }
    }
}
