import Foundation

/// What one Toolkit row says: its glyph, its name, its line, and what VoiceOver hears when it has no count
/// of its own to say.
struct ToolkitRowInfo: Equatable, Sendable {
    let icon: String
    let title: String
    let subtitle: String
    /// The row's spoken label, and the Home tile's when the tile opens it (ADR 0197 D2: a destination's
    /// label is the UI tests' contract).
    let spoken: String
}

/// **The Toolkit's rows**, in one place (ADR 0235 D2, D6): the hub draws its rows from this list, and the
/// Home tile beside Toolkit offers exactly these, so the two can't disagree about what the Toolkit holds.
/// `check-manual.py` C2 reads the titles here and holds `toolkit.md` to them.
///
/// The raw values are what the tile's choice is stored as, so they never change.
enum ToolkitSection: String, CaseIterable, Identifiable, Sendable {
    case myChords, myProgressions, myTabs, tuner, glossary, help

    var id: String { rawValue }

    /// The hub's order: the three things you make together, then the tools. `allCases` is this order.
    var info: ToolkitRowInfo {
        switch self {
        case .myChords:
            ToolkitRowInfo(icon: "square.grid.2x2", title: "My chords", subtitle: "Your saved voicings",
                           spoken: "My chords, your saved voicings")
        case .myProgressions:
            ToolkitRowInfo(icon: "list.bullet", title: "My progressions", subtitle: "Progressions you've written",
                           spoken: "My progressions, progressions you've written")
        case .myTabs:
            ToolkitRowInfo(icon: "pencil.and.list.clipboard", title: "My tabs",
                           subtitle: "Tabs you write on the neck",
                           spoken: "My tabs, tabs you write on the neck")
        case .tuner:
            ToolkitRowInfo(icon: "tuningfork", title: "Tuner", subtitle: "Tune by ear or mic",
                           spoken: "Tuner, tune by ear or mic")
        case .glossary:
            ToolkitRowInfo(icon: "text.book.closed", title: "Glossary", subtitle: "Chord, scale & theory terms",
                           spoken: "Glossary, chord, scale and theory terms")
        case .help:
            // Spelled "and" rather than "&": it's read aloud, and it's the prefix the Toolkit UI test matches.
            ToolkitRowInfo(icon: "questionmark.circle", title: "Help & FAQs", subtitle: "How Red Moon works",
                           spoken: "Help and FAQs, how Red Moon works")
        }
    }
}
