import Foundation

// The first-song walkthrough's words (ADR 0149 §7: every string is ours). Kept beside the logic, and
// out of the view, so the rules they answer to are tested rather than remembered: a beat's help link
// must name a question that is really in `FAQEntry.all` (§6), and nothing here may grade (ADR 0070)
// or call the app anything but Red Moon.

extension SongWalkthrough.Beat {

    /// What the card asks for while this beat is current. Beat 1's scripted form is
    /// `StarterTrackScript.Stage.instruction(isPlaying:)`, which takes over on the starter track.
    var instruction: String {
        switch self {
        case .loopIt:
            return "Play the song. Tap Loop where a part you want to learn begins, and tap it again "
                + "where it ends."
        case .slowIt:
            // "About half", with the musician's discretion attached (0149 §1) — never a target.
            return "Bring the speed down to about half. The pitch holds, so it plays slower, not lower."
        case .keepIt:
            return "Tap Save as loop, so it's here when you come back."
        }
    }

    /// The catalog answer this beat points at, instead of explaining itself (0149 §6).
    var helpQuestion: String {
        switch self {
        case .loopIt: return "Why loop one part of a song?"
        case .slowIt: return "Does slowing a song down change its pitch?"
        case .keepIt: return "What happens to a loop I save?"
        }
    }

    /// The link's own label: short, and a question the player might actually have at that moment.
    var helpLinkTitle: String {
        switch self {
        case .loopIt: return "Why loop one part?"
        case .slowIt: return "Won't it sound wrong?"
        case .keepIt: return "What's a saved loop for?"
        }
    }

    /// The answer itself, looked up rather than copied — the catalog is the one place it lives.
    var helpEntry: FAQEntry? { FAQEntry.all.first { $0.question == helpQuestion } }
}

extension StarterTrackScript.Stage {

    /// Beat 1's instruction on the starter track (ADR 0220 D3), or `nil` once the span has closed and
    /// the ordinary beats take over. `isPlaying` only changes the first words: "press play" is wrong
    /// advice to someone already listening.
    func instruction(isPlaying: Bool) -> String? {
        switch self {
        case .leadIn:
            return (isPlaying ? "" : "Press play. ") + "It stops where the chords come in."
        case .heldAtStart:
            return "Tap Loop. Your loop starts here, right on the beat."
        case .awaitingEnd:
            return (isPlaying ? "Keep listening. " : "Press play. ")
                + "It stops again where the solo comes in."
        case .heldAtEnd:
            return "Tap Loop again to close it."
        case .finished:
            return nil
        }
    }
}

extension StarterTrackHints.Hint {

    /// A hint's name on the card, set apart from the beats' so it never reads as a fourth step (D4).
    var title: String {
        switch self {
        case .click: return "Hear the beat"
        case .backingTrack: return "Something to play over"
        }
    }

    /// What it says. The ring does the pointing, so the words name the control rather than place it.
    /// `loopName` is the kept loop's current name, which the player may already have changed.
    func body(loopName: String) -> String {
        switch self {
        case .click:
            // True of the engine, not a promise: the click is scheduled against the stretched
            // playback (`MetronomeSchedule`), so it follows the speed down.
            return "Tap the metronome for a click on every beat. It slows down with the song."
        case .backingTrack:
            // "Keep this where you'll find it", never "unlock this": Improvise is already on every
            // loop (ADR 0135 B2), and the flag only decides where the loop turns up again.
            return "Four bars of chords make a good bed to solo over. Hold \(loopName) and turn on "
                + "Backing track to keep it with your backing tracks."
        }
    }

    /// The ✕'s VoiceOver label: which pointer it closes, since the card's own ✕ closes the guide.
    var dismissLabel: String {
        switch self {
        case .click: return "Hide the metronome hint"
        case .backingTrack: return "Hide the backing track hint"
        }
    }
}

extension SongWalkthrough {

    /// The experienced player's offer (0149 §4): one entry point, and a way to say no.
    static let offerTitle = "Your first loop, in three steps"
    static let offerBody = "Loop a part of this song, slow it down, and keep it."

    /// The one ceremony (0149 §5), in the app's own voice and the musician's register (the backlog's
    /// *musician voice* principle): it names what the player just did as the thing musicians do,
    /// and says where it went. It praises nothing about how they played — there is nothing to praise
    /// yet, and Red Moon never grades (ADR 0070).
    static let ceremonyTitle = "That's your first loop."
    static func ceremonyBody(songTitle: String) -> String {
        "It's how musicians learn a part: take it out, slow it down, go round again. "
            + "Saved to \(songTitle), under Loops."
    }
}
