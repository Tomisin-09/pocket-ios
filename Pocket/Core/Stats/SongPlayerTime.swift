import Foundation

/// **What the song player logs** (ADR 0322): how long its audio sounded on one visit, split by what
/// was sounding.
///
/// - **A loop being played:** a saved loop armed and cycling, with no A/B span open. Each loop heard
///   for at least `floorSeconds` on the visit is a run of its own, on that loop.
/// - **Exploring:** everything else that sounded. The song playing through, an A/B span being set or
///   adjusted (making a loop, or changing one), and a loop heard for less than the floor, which was a
///   listen to check it rather than practice. One run for the visit, on the song.
///
/// **Sounded, not on screen** (the rule ADR 0321 set for the loop modes). Nothing is counted while
/// the song player is quiet: paused, interrupted, or never started. So the minutes are time with the
/// song playing, not time with the screen open, which keeps this a run of practice rather than the
/// screen time ADR 0239 removed from the app.
///
/// **Pure**, with both clocks passed in, as `SoundedTime` is: the model says what is sounding after
/// every change, and the rules are unit-tested here rather than trusted there.
struct SongPlayerTime: Equatable {

    /// What the song player is sounding at a moment.
    enum Sounding: Equatable, Hashable {
        /// A saved loop, armed and cycling, with no A/B span open.
        case loop(UUID)
        /// Anything else that plays.
        case exploring
    }

    /// A loop played for its own run of at least this long. Under it, the loop's time goes to
    /// Exploring: saving a loop plays it straight away (`createLoop`), and a few passes to hear where
    /// it starts and ends are part of making it. It is also the floor `PracticeLogWriter` keeps for an
    /// Exploring run, so a quick listen to check a song doesn't mark the day as practised. The
    /// Metronome's thirty seconds, for the same reason (ADR 0242 D4).
    static let floorSeconds: TimeInterval = 30

    /// One loop's run.
    struct LoopRun: Equatable {
        let loopUID: UUID
        let interval: DateInterval
    }

    /// What a visit logs.
    struct Runs: Equatable {
        /// Earliest first.
        var loops: [LoopRun] = []
        /// `nil` when nothing sounded outside a loop's own run. Not yet held to the floor: the writer
        /// does that, by kind, as it does the Metronome's.
        var exploring: DateInterval?
    }

    /// What the song player is sounding, from its state. A saved loop armed with no A/B span open is
    /// that loop being played. An open span is a loop being made or changed, and with no loop armed the
    /// song is playing through: both Exploring. Nothing while the engine is quiet, which includes an
    /// interruption: the engine pauses itself under one (ADR 0323).
    static func sounding(isPlaying: Bool, armedLoop: UUID?, spanOpen: Bool) -> Sounding? {
        guard isPlaying else { return nil }
        if let armedLoop, !spanOpen { return .loop(armedLoop) }
        return .exploring
    }

    private var now: Sounding?
    private var loops: [UUID: SoundedTime] = [:]
    private var exploring = SoundedTime()

    /// What is sounding from `uptime` on, or `nil` for nothing. Called after every change that could
    /// move it; telling it what it already knows changes nothing.
    mutating func update(_ sounding: Sounding?, at date: Date, uptime: TimeInterval) {
        guard sounding != now else { return }
        switch now {
        case .loop(let uid): loops[uid]?.ended(uptime: uptime)
        case .exploring: exploring.ended(uptime: uptime)
        case nil: break
        }
        switch sounding {
        case .loop(let uid): loops[uid, default: SoundedTime()].began(at: date, uptime: uptime)
        case .exploring: exploring.began(at: date, uptime: uptime)
        case nil: break
        }
        now = sounding
    }

    /// The visit's runs, counted up to `uptime`, and start over at nothing. Taken as the screen is
    /// torn down, so a second take (the screen's two seams) finds nothing to log twice.
    mutating func take(uptime: TimeInterval) -> Runs {
        defer { self = SongPlayerTime() }
        var runs = Runs(exploring: exploring.take(uptime: uptime))
        for uid in loops.keys {
            guard let interval = loops[uid]?.take(uptime: uptime) else { continue }
            if interval.duration >= Self.floorSeconds {
                runs.loops.append(LoopRun(loopUID: uid, interval: interval))
            } else {
                runs.exploring = Self.adding(interval, to: runs.exploring)
            }
        }
        runs.loops.sort { lhs, rhs in
            lhs.interval.start != rhs.interval.start ? lhs.interval.start < rhs.interval.start
                : lhs.loopUID.uuidString < rhs.loopUID.uuidString
        }
        return runs
    }

    /// Two stretches as one run: from the earlier start, for both lengths added up. Not their union in
    /// time, which would count the gap between them.
    private static func adding(_ interval: DateInterval, to run: DateInterval?) -> DateInterval {
        guard let run else { return interval }
        return DateInterval(start: min(run.start, interval.start), duration: run.duration + interval.duration)
    }
}
