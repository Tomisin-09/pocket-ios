import Foundation

/// The **first-song walkthrough** (ADR 0149, as amended 2026-08-11 and by ADR 0220): three beats on
/// the waveform screen, run once, on the first song the player brings in.
///
/// 1. **Loop it** — tap Loop at the start of a passage and again at the end.
/// 2. **Slow it down** — take the speed to roughly half. Pitch holds.
/// 3. **Keep it** — Save as loop, so the player leaves owning something.
///
/// **A beat completes when the player does the thing, and never on a button** (0149 §1). There is no
/// Next here at all: every tick is recorded from an `Event` the practice model reports as it
/// happens, so a tick is always true. Beats complete **in any order** — a player who saves the span
/// before slowing it has kept a loop, and pretending otherwise would ask them to do it twice. The
/// card simply shows whichever beat is first still outstanding.
///
/// **Ceremony exactly once, at the first loop kept** (0149 §5). Loop it and Slow it down complete
/// with a tick and nothing more. The ceremony latch outlives the run (`ceremonyAlreadyShown`), so a
/// player who re-enters from Help and does it all again is not congratulated twice.
///
/// Pure value type, Foundation-only, so every rule here is unit-tested (AGENTS.md). Persistence —
/// when it arms, when it is spent — lives in `AppSettings+Walkthrough.swift`; the pause-at-marker
/// script the starter track adds to beat 1 is `StarterTrackScript`.
struct SongWalkthrough: Equatable {

    enum Beat: String, CaseIterable, Identifiable {
        case loopIt
        case slowIt
        case keepIt

        var id: String { rawValue }

        var title: String {
            switch self {
            case .loopIt: return "Loop it"
            case .slowIt: return "Slow it down"
            case .keepIt: return "Keep it"
            }
        }
    }

    /// What the practice model reports. Each one is a real action the player took.
    enum Event: Equatable {
        /// A fresh A/B span closed and began repeating — a play-along second tap or a released
        /// hold-drag (ADR 0041). Never a saved loop lifted in for a range edit.
        case spanClosed
        /// The player moved the speed (never the app arming a loop at its own tempo).
        case speedChanged(to: Double)
        /// A new loop was saved.
        case loopSaved
    }

    /// How the walkthrough arrives (0149 §4). A player who reports substantial experience gets a
    /// single dismissible offer; everyone else — including anyone who skipped the question — gets it
    /// started.
    enum Entry: Equatable {
        case started
        case offered
    }

    /// Where the card is, as a whole.
    enum Phase: Equatable {
        /// Waiting on the experienced player's yes (0149 §4). Events are ignored until then: the
        /// beats are what the player does *inside* the walkthrough.
        case offered
        /// A beat is outstanding.
        case running(Beat)
        /// The first loop was kept (0149 §5). Stays up until the player closes it.
        case ceremony
        /// Nothing left to show.
        case finished
    }

    /// The speed below which a slow-down counts. The copy suggests *about half* with the musician's
    /// discretion attached (0149 §1), so any real step down from full speed is the beat done — a
    /// player who stops at 0.7× has slowed it down, and a tick that demanded 0.5× would be a grade.
    static let slowedBelow = 1.0

    private(set) var completed: Set<Beat> = []
    private(set) var isAccepted: Bool
    private(set) var isShowingCeremony = false
    /// Carried in from `AppSettings` so the one ceremony stays one across re-entries (0149 §5).
    private(set) var ceremonyAlreadyShown: Bool

    init(entry: Entry, ceremonyAlreadyShown: Bool) {
        isAccepted = entry == .started
        self.ceremonyAlreadyShown = ceremonyAlreadyShown
    }

    /// The beat the card is asking for: the first one still outstanding.
    var current: Beat? { Beat.allCases.first { !completed.contains($0) } }

    var phase: Phase {
        if !isAccepted { return .offered }
        if isShowingCeremony { return .ceremony }
        return current.map(Phase.running) ?? .finished
    }

    /// The experienced player said yes to the offer.
    mutating func accept() { isAccepted = true }

    /// Record something the player did. Returns `true` exactly when this event is the one that
    /// should mark the moment — the first loop kept, on an install that has never been shown it —
    /// so the caller can persist the latch.
    @discardableResult
    mutating func record(_ event: Event) -> Bool {
        guard isAccepted else { return false }
        switch event {
        case .spanClosed:
            completed.insert(.loopIt)
        case .speedChanged(let speed):
            if speed < Self.slowedBelow { completed.insert(.slowIt) }
        case .loopSaved:
            // A saved loop is a loop: however it was made, beat 1 is true of it.
            completed.formUnion([.loopIt, .keepIt])
            guard !ceremonyAlreadyShown else { return false }
            ceremonyAlreadyShown = true
            isShowingCeremony = true
            return true
        }
        return false
    }

    /// The player closed the ceremony. If a beat is still outstanding (the span was saved before it
    /// was slowed), the card goes back to asking for it.
    mutating func dismissCeremony() { isShowingCeremony = false }

    /// 0149 §4's branch, on the intake's first answer. **The top two answers are "substantial"**:
    /// *Comfortable, want to level up* and *Been playing a while* describe a player who knows what a
    /// loop and a slow-down are for, and whom a started walkthrough would talk down to. What they
    /// are offered is the same three beats, one tap away.
    static func entry(for experience: ArtistExperience?) -> Entry {
        switch experience {
        case .comfortable, .aWhile: return .offered
        case .justStarting, .fewChords, nil: return .started
        }
    }
}
