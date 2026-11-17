import Foundation

/// **Who owns the lock screen** when more than one producer has claimed it (ADR 0303). Pure and
/// Foundation-only, so the hand-over rules are unit-tested: they are the kind of bookkeeping that breaks
/// silently, and the failure is a blank lock screen over audio you can't stop.
///
/// `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` are process-global, but Red Moon has many
/// producers, and they overlap. A routine builds and **starts** the incoming block before it tears down
/// the outgoing one (ADR 0129, bug 1), and a take or a loop can start over the song screen, which holds
/// the lock screen for as long as it is open. When each producer cleared the global info on its way out,
/// the outgoing block blanked the incoming one.
///
/// The rules:
/// - **The most recent claim owns it.** Claiming again moves a producer back to the top.
/// - **Only the owner draws.** An update from a producer underneath is kept, not shown.
/// - **Letting go hands back.** When the owner releases, the claim beneath takes over, showing what that
///   producer last pushed. When nobody is left, the lock screen is cleared.
/// - **A release from underneath changes nothing on screen**, and nor does anything from a producer that
///   holds no claim: an update arriving after its producer let go can't bring a dead session back.
struct NowPlayingClaims<Owner: Hashable> {

    /// What the lock screen should do after a change.
    enum Display: Equatable {
        /// Leave it as it is.
        case unchanged
        /// Show this state.
        case show(NowPlayingState)
        /// Nothing is playing: clear it.
        case clear
    }

    private var claims: [(owner: Owner, state: NowPlayingState?)] = []

    /// The producer the lock screen's commands reach, or `nil` when none holds a claim.
    var owner: Owner? { claims.last?.owner }

    var isEmpty: Bool { claims.isEmpty }

    /// Take the lock screen. A producer claiming again moves to the top and starts with no state, since
    /// a new claim is a new session; it pushes its first state straight after.
    mutating func claim(_ owner: Owner) {
        claims.removeAll { $0.owner == owner }
        claims.append((owner, nil))
    }

    /// Record `owner`'s latest state, and show it if `owner` is the one on top.
    mutating func update(_ owner: Owner, to state: NowPlayingState) -> Display {
        guard let index = claims.firstIndex(where: { $0.owner == owner }) else { return .unchanged }
        claims[index].state = state
        return index == claims.count - 1 ? .show(state) : .unchanged
    }

    /// Let go of the lock screen. If `owner` was on top, the claim beneath takes over with what it last
    /// pushed; with nothing beneath, or nothing pushed yet, the lock screen is cleared rather than left
    /// showing the producer that just went.
    mutating func release(_ owner: Owner) -> Display {
        guard let index = claims.firstIndex(where: { $0.owner == owner }) else { return .unchanged }
        let wasOnTop = index == claims.count - 1
        claims.remove(at: index)
        guard wasOnTop else { return .unchanged }
        guard let state = claims.last?.state else { return .clear }
        return .show(state)
    }
}

/// **Seconds of sounding time, across pauses**, for a producer with no timeline of its own (ADR 0303). A
/// loop cycling its region has no "1:42 of 3:32" to show, so the lock screen's clock reads how long it has
/// sounded, as it does for the metronome. Pure: `now` is any monotonic seconds, passed in, so it is
/// tested without waiting.
struct PlayClock: Equatable {
    private var banked: TimeInterval = 0
    private var since: TimeInterval?

    /// Start (or carry on) counting from `now`. Counting already is a no-op, so it never double-counts.
    mutating func run(at now: TimeInterval) {
        if since == nil { since = now }
    }

    /// Stop counting at `now` and keep what was counted.
    mutating func hold(at now: TimeInterval) {
        guard let since else { return }
        banked += max(0, now - since)
        self.since = nil
    }

    /// Back to zero, not counting.
    mutating func reset() { self = PlayClock() }

    /// The sounding time at `now`.
    func elapsed(at now: TimeInterval) -> TimeInterval {
        banked + (since.map { max(0, now - $0) } ?? 0)
    }

    /// The monotonic clock the producers pass in.
    static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}

/// The two lines a producer is named by on the lock screen: the title, and the line beneath it (the
/// `artist` slot of `NowPlayingState`).
struct NowPlayingLabel: Equatable {
    var title: String
    var subtitle: String

    /// A loop's lines: its name, over the song it is cut from and that song's artist. A loop with no name
    /// is called *Loop*, as the Journal calls it.
    static func loop(named name: String, songTitle: String?, artist: String?) -> NowPlayingLabel {
        let subtitle = [songTitle, artist].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return NowPlayingLabel(title: name.isEmpty ? "Loop" : name, subtitle: subtitle)
    }
}
