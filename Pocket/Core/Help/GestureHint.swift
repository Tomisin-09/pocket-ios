import Foundation

/// A hold the song player hides, and the one-line tag that points at it (ADR 0244).
///
/// **Only the holds that pass all three of 0244 D1's questions are here**: nothing on screen draws
/// it and iOS hasn't taught it; it is the only way to do what it does; and what it acts on is in
/// front of the player. That is why the list is six and not the eleven holds the app wires up:
///
/// - **Loop controls** opens Settings ▸ Song player, which has its own row in Settings: a shortcut.
/// - A **Snags** row already says *Hold a snag to leave a line on it* under the panel, until a line
///   exists — the screen says it in its own words (D1's last clause), so a tag would say it twice.
/// - The **skip** buttons' hold is an iOS menu, and only picks a preference.
/// - Outside the song player, every hold either has a caption of its own (the strum editor's
///   *Long-press to accent*, Name the notes' *Hold a note to snag it*) or is a list row's menu (D2).
///
/// **The order of the cases is the rank**: when more than one is on screen, the first wins. The loop
/// row leads because a loop is what the first session makes, and holding it is the only way to name
/// it or change how it plays.
///
/// **The raw values are persisted** (`AppSettings.Key.gestureHintsRetired`) — never rename one. A tag
/// retired under an old name would come back under the new.
enum GestureHint: String, CaseIterable, Identifiable, Sendable {
    case loopRow = "waveform.loopRow"
    case metronome = "waveform.metronome"
    case bpm = "waveform.bpm"
    case markerRow = "waveform.markerRow"
    case panelHeader = "waveform.panelHeader"
    case songTitle = "waveform.songTitle"

    var id: String { rawValue }

    /// What the tag says. One sentence, starting with what to do, then what it gets you — the
    /// contents of the place it opens rather than its name (a player gains nothing from *Edit loop*).
    var text: String {
        switch self {
        case .loopRow:
            "Hold a loop to edit it: its name, its range and how you practise it."
        case .metronome:
            "Hold the metronome to tap the tempo in, or type it."
        case .bpm:
            "Hold the BPM to take this tempo to the metronome, or into a new exercise."
        case .markerRow:
            "Hold a marker to rename it, move it, or make it start a section."
        case .panelHeader:
            "Hold a panel's name to select several at once."
        case .songTitle:
            "Hold the song's name for its details."
        }
    }

    /// How a tag's ring is drawn round its control: a circle round the round metronome, a rounded
    /// rectangle round everything else (the walkthrough's `HintRing` makes the same choice).
    var ringIsCircle: Bool { self == .metronome }
}

/// Which tag, if any, to show (ADR 0244 D3–D5). Pure, so every rule is unit-tested; the views report
/// what is on screen and draw the answer.
enum GestureHintPolicy {

    /// The tags still in play — the ones a control should report its position for. Empty is the
    /// common case once a player has used the app a while, and costs the screen nothing.
    ///
    /// - `enabled`: Settings ▸ Song player ▸ *Show hold tips* (default on — D6).
    /// - `retired`: used, or closed with ✕. Both are for good (D4).
    /// - `walkthroughOutstanding`: the first-song walkthrough is armed and the next song opened runs
    ///   it. Its session comes first (D3), so nothing shows until it has been spent.
    /// - `walkthroughSeenThisOpening`: the walkthrough ran in this opening of the app. A new player's
    ///   first visit is the walkthrough and nothing beside it (ADR 0149 §5); tags start on the next.
    /// - `shownThisOpening`: the tag this opening has already shown, if any. One per opening (D5), and
    ///   that one stays in play until it is used or closed, so leaving the screen and coming back
    ///   finds the same tag rather than the next.
    static func candidates(enabled: Bool,
                           retired: Set<GestureHint>,
                           walkthroughOutstanding: Bool,
                           walkthroughSeenThisOpening: Bool,
                           shownThisOpening: GestureHint?) -> Set<GestureHint> {
        guard enabled, !walkthroughOutstanding, !walkthroughSeenThisOpening else { return [] }
        if let shownThisOpening {
            return retired.contains(shownThisOpening) ? [] : [shownThisOpening]
        }
        return Set(GestureHint.allCases).subtracting(retired)
    }

    /// The tag to draw: the highest-ranked candidate whose control is on screen now.
    static func next(onScreen: Set<GestureHint>, candidates: Set<GestureHint>) -> GestureHint? {
        GestureHint.allCases.first { onScreen.contains($0) && candidates.contains($0) }
    }

    // MARK: Openings

    /// How long the app must spend in the background before coming back to it counts as **opening it
    /// again** (D5). The practice log's gap between sittings: half an hour away starts a new sitting
    /// there, and a new opening here. A launch is always an opening.
    ///
    /// Not launches alone: iOS keeps a suspended app for days, so "one a launch" would space the tags
    /// by however long iOS happened to keep the process, not by the times the player opened the app.
    static let openingGap: TimeInterval = PracticeLog.sittingGap

    /// Whether coming back now begins a new opening. `awaySince` is when the app went to the
    /// background, or nil if it hasn't since the last opening began.
    static func isNewOpening(awaySince: Date?, now: Date) -> Bool {
        guard let awaySince else { return false }
        return now.timeIntervalSince(awaySince) >= openingGap
    }

    // MARK: Storage

    /// The retired set as it is stored: raw values joined by commas, sorted so the same set is
    /// always the same string.
    ///
    /// Kept as **strings**, not cases, so a value written by a later build that knows a seventh tag
    /// survives a round trip through this one — dropping it would bring that tag back after a
    /// downgrade and an upgrade.
    static func storedNames(_ stored: String) -> Set<String> {
        Set(stored.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    static func retired(_ stored: String) -> Set<GestureHint> {
        Set(storedNames(stored).compactMap(GestureHint.init(rawValue:)))
    }

    /// `stored` with `hint` added. Unchanged — the same string — when it was already there, so a
    /// caller can skip the write.
    static func retiring(_ hint: GestureHint, in stored: String) -> String {
        let names = storedNames(stored)
        guard !names.contains(hint.rawValue) else { return stored }
        return names.union([hint.rawValue]).sorted().joined(separator: ",")
    }
}
