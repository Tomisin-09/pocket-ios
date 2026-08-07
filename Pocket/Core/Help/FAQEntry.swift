import Foundation

/// One entry in the Toolkit **Help & FAQs** screen (ADR 0145) — a question a player actually asks and a
/// paragraph answering it, grouped by area. A straight clone of `GlossaryTerm`'s shape (ADR 0096 Slice 1)
/// for the same reason: static in-house reference content, no audio, no state, no dependencies.
///
/// Pure value type with no SwiftUI/SwiftData import, so the catalog and the search filter are
/// unit-tested. Answers describe **what the app does** — they never coach, grade or score the player
/// (ADR 0070), and every word is ours (the content-strategy rule in `docs/backlog.md`).
///
/// **No price and no trial length may appear in an answer** (ADR 0145 D6, inheriting ADR 0144's rule
/// that the trial is read from StoreKit and never hardcoded). Pricing answers point at the paywall and
/// Settings ▸ Red Moon Pro instead. `FAQEntryTests` pins this.
struct FAQEntry: Identifiable, Equatable {
    /// The area an entry belongs to — drives the grouped sections in `FAQView`. Declaration order is
    /// the display order, and it is deliberately the order a new player meets the app in.
    enum Area: String, CaseIterable, Identifiable {
        case gettingStarted = "Getting started"
        case audio = "Audio & files"
        case concepts = "How practice works"
        case pro = "Red Moon Pro"
        case privacy = "Your data"

        var id: String { rawValue }
    }

    let question: String
    let answer: String
    let area: Area

    /// Stable identity for `ForEach` **and** for `FAQView`'s expansion set — questions are unique
    /// across the catalog.
    var id: String { question }

    /// Case- and diacritic-insensitive match of a search query against the question **or** its answer,
    /// so someone hunting "iCloud" finds the storage answer even though the word is only in its body.
    /// An empty/whitespace query matches everything (the unfiltered list). Reused verbatim from
    /// `GlossaryTerm.matches(_:)` — the two screens must filter identically.
    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return question.range(of: trimmed, options: options) != nil
            || answer.range(of: trimmed, options: options) != nil
    }
}

extension FAQEntry {
    /// The support address, as plain text.
    ///
    /// ⚠ **This is not decoration.** `SettingsView`'s Contact-support row is a `mailto:` link, and a
    /// `mailto:` **silently does nothing** on a device with no Mail account configured. The address
    /// therefore has to exist somewhere a player can read and copy it, which is the "How do I get help"
    /// answer below (ADR 0145). Removing it from that answer breaks the only fallback.
    static let supportAddress = "support@decooperations.co.uk"

    /// The full help catalog. Grouped by `Area`; within an area, ordered by how early a player is
    /// likely to hit the question rather than alphabetically — unlike the glossary, these are not
    /// looked up by name.
    static let all: [FAQEntry] = [
        // MARK: Getting started
        .init(question: "What is Red Moon Practice?",
              answer: "A practice room for your own material. Bring in a song you own, mark the bars "
                + "you can't play yet, slow them down, and run them against a click until they're "
                + "yours. Alongside that: drills you build yourself, a tuner and metronome, chord and "
                + "theory tools, and a journal of what you actually did.",
              area: .gettingStarted),
        .init(question: "Where do I start?",
              answer: "Import a song and play it. When the passage that keeps falling apart comes "
                + "up, tap Loop where it starts and Loop again where it ends — that span now "
                + "repeats. Slow it right down, slower than feels necessary, and let it go round. "
                + "When it's clean, nudge the speed up. That loop is the whole app in miniature; "
                + "everything else is a way of doing more of it.",
              area: .gettingStarted),
        .init(question: "Do I need to read music?",
              answer: "No. Exercises are drawn on a fretboard, a strum lane or a chord grid, and songs "
                + "are shown as a waveform you can see the shape of. Nothing in Red Moon requires "
                + "standard notation, and the Glossary in the Toolkit explains any term you meet.",
              area: .gettingStarted),
        .init(question: "How do I get help or report a bug?",
              answer: "Email \(supportAddress) — you can select and copy that address from right here, "
                + "and Settings ▸ About has a Contact Support row that opens it in Mail. It helps to "
                + "say what you were doing when it went wrong, what you expected instead, and the "
                + "version number from Settings ▸ About.",
              area: .gettingStarted),

        // MARK: Audio & files
        .init(question: "What audio can I practise with?",
              answer: "Audio files on your device or in iCloud Drive — your own purchases, your own "
                + "recordings, backing tracks, anything you can put in the Files app. Red Moon is a "
                + "practice tool, not a streaming player.",
              area: .audio),
        .init(question: "Why can't I use Apple Music or Spotify?",
              answer: "Streaming audio is encrypted on the way to your speakers, and no app — not this "
                + "one, not any other — can reach the raw sound underneath it. Slowing a passage down, "
                + "looping it and drawing it as a waveform all need that raw sound, so Red Moon is "
                + "built on files you hold rather than streams you rent.",
              area: .audio),
        .init(question: "My song stopped playing — what happened?",
              answer: "Red Moon links to your audio file where it already lives rather than copying it, "
                + "so your library stays your library and the app stays small. The trade is that the "
                + "link can break: the file may have moved or been deleted, or iCloud Drive may have "
                + "cleared it off this device to save space. Re-import it to practise again — your "
                + "loops, markers and notes are waiting.",
              area: .audio),
        .init(question: "Does slowing a song down change its pitch?",
              answer: "No. The pitch is held where it is however far you slow the tempo, so a passage "
                + "at a crawl is still in the key you'll play it in. Speeding up works the same way, up "
                + "to one and a half times the original.",
              area: .audio),

        // MARK: How practice works
        .init(question: "What's the difference between mastery and command tempo?",
              // ADR 0145 D5: **quote** the in-app explanations rather than restating them, so the two
              // surfaces cannot drift apart. `PracticeFieldInfo` lives in `FieldInfoLabel.swift`; both
              // are plain `String`s in this module, so interpolating them keeps this file pure.
              // Cross-referenced there. `FAQEntryTests` asserts both substrings survive.
              answer: "They're two separate axes, and that's deliberate — for a lot of material the "
                + "bottleneck isn't speed. Command tempo: \(PracticeFieldInfo.commandTempo) Mastery: "
                + "\(PracticeFieldInfo.mastery)",
              area: .concepts),
        .init(question: "Does Red Moon score my playing?",
              answer: "No, and it never will. Nothing here listens to you play and tells you how good "
                + "it was. Mastery is your own call, recorded because it's useful to you later — not a "
                + "grade the app hands down. Recordings are yours to listen back to and nobody else's.",
              area: .concepts),
        .init(question: "What is a ramp?",
              answer: "A ramp is a run that changes speed for you so you don't have to think about it. "
                + "It starts below the tempo you already own the material at, holds each step long "
                + "enough for it to settle, then climbs. Some ramps ease back down at the end, so you "
                + "finish somewhere clean rather than at the edge.",
              area: .concepts),
        .init(question: "How long is a practice session?",
              answer: "Sessions are sized in blocks, not minutes. Quick, Focused and Full build one, "
                + "two and four focused blocks, and a handful of items rotate inside each block — so "
                + "the same material gets several short exposures rather than one long grind. The "
                + "minutes shown are an estimate derived from the blocks; edit a session and the "
                + "estimate follows.",
              area: .concepts),

        // MARK: Red Moon Pro
        .init(question: "What's free and what's Pro?",
              answer: "Free forever: the Toolkit — tuner, your saved chords, the glossary and this "
                + "help — the standalone metronome, and the Journal, because what you wrote and what "
                + "you recorded stays yours whatever happens to a subscription. Red Moon Pro: "
                + "practising songs and loops, your library, and building your own exercises and "
                + "routines. Pro starts with a free trial, and the paywall states the current price "
                + "and how long that trial runs.",
              area: .pro),
        .init(question: "How do I start, restore or cancel a subscription?",
              answer: "Settings ▸ Red Moon Pro does all three. Restore Purchases brings back a "
                + "subscription you already own — after reinstalling, or on another device signed in "
                + "to the same Apple Account. Manage Subscription opens Apple's own screen, which is "
                + "where cancelling happens; Red Moon never handles the billing itself. If you asked "
                + "to be reminded before a trial converts, that reminder is a notification from this "
                + "app, so it needs notifications allowed.",
              area: .pro),

        // MARK: Your data
        .init(question: "Where is my practice data stored?",
              answer: "On this device. Your loops, markers, exercises, routines, notes and recordings "
                + "live in the app itself — there's no account to make and nothing to sign into. "
                + "There is no cross-device sync today: install Red Moon on a second device and it "
                + "starts empty. A device backup includes the app's data, and any audio you keep in "
                + "iCloud Drive is stored by iCloud Drive as it always was.",
              area: .privacy),
        .init(question: "Does Red Moon listen to or send my playing?",
              answer: "The microphone is used in exactly two places: the tuner, which listens to a "
                + "string while you're on that screen, and a recording you start yourself. Neither "
                + "sends anything anywhere — your audio never leaves this device, and neither do your "
                + "notes, song names or artist name. Separately, the app counts which features get "
                + "used so we know what to improve. Those counts are anonymous and carry no account "
                + "and no advertising ID. Whether counting starts on or off depends on where you "
                + "are — Settings ▸ Privacy always shows which it is, and turns it off in one tap.",
              area: .privacy)
    ]

    /// The catalog filtered by a search query, preserving catalog order. Empty query ⇒ the full list.
    static func matching(_ query: String) -> [FAQEntry] {
        all.filter { $0.matches(query) }
    }
}
