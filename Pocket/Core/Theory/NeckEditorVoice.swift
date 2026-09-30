import Foundation

/// The words the neck editor says that depend on what it's for (ADR 0235 D3): naming a recording, where a
/// note is what you **heard**, or writing a tab, where it's what you **play**. Everything else it says is
/// the same for both. Name the notes' words are kept byte for byte (`NeckEditorVoiceTests`).
struct NeckEditorVoice: Equatable, Sendable {
    /// Over the neck, beside the instrument.
    let whereLabel: String
    /// A note that started inside itself: *Started at fret 5, heard as one note.*
    let asOneNote: String
    /// A join from the note before: *From note 3 (G5), heard as two notes.*
    let asTwoNotes: String
    /// The offer to move a join from the note before inside this note, for one note.
    let oneNoteOffer: String
    /// Said after why a note can't join the one before, for one note.
    let startedElsewhere: String
    /// The ⓘ beside *Into it*.
    let intoInfo: String
    /// The ⓘ beside *Chords*.
    let chordsInfo: String

    static let naming = NeckEditorVoice(
        whereLabel: "Where did you play it?",
        asOneNote: "heard as one note",
        asTwoNotes: "heard as two notes",
        oneNoteOffer: "Heard as one note?",
        startedElsewhere: " Heard as one note that started elsewhere? Pick how.",
        intoInfo: NamingInfo.into,
        chordsInfo: NamingInfo.chords)

    static let writing = NeckEditorVoice(
        whereLabel: "Where do you play it?",
        asOneNote: "as one note",
        asTwoNotes: "as two notes",
        oneNoteOffer: "Write it as one note?",
        startedElsewhere: " One note that starts elsewhere? Pick how.",
        intoInfo: WritingInfo.into,
        chordsInfo: WritingInfo.chords)
}

/// What the ⓘ beside *Chords* and *Into it* say in the tab writer: Name the notes' words, less what's about
/// hearing and By ear.
enum WritingInfo {
    static let chords =
        "One tap can hold more than one note: a double-stop, a triad or a whole chord, one note per "
        + "string, as in My chords. Turn Chords on, then tap the other strings. Tap a note twice to take it "
        + "out. Bend and vibrato go on the ringed note, and the neck names what you placed."
    static let into =
        "How you get to this note: picked, a hammer-on or pull-off (fretted from a lower or higher fret on "
        + "the same string, without picking it), or a slide.\n\nFrom the note before? It joins from that "
        + "note. One note that starts elsewhere, like a grace note? Pick how it starts, then tap the fret it "
        + "comes from; a slide can also come in From below or From above. A double-stop that moves as one "
        + "works the same way. The tab reads the same either way."
}

/// What the ⓘ beside *Chords* and *Into it* say (ADR 0227 D4, D5; ADR 0230), kept together so the two read
/// as one voice.
enum NamingInfo {
    static let chords =
        "One tap can hold more than one note: a double-stop, a triad or a whole chord, one note per "
        + "string, as in My chords. Turn Chords on, then tap the other strings. Tap a note twice to take it "
        + "out. Bend and vibrato go on the ringed note, and the neck names what you placed. A chord you "
        + "heard but didn't play is named on By ear."
    static let into =
        "How you got to this note: picked, a hammer-on or pull-off (fretted from a lower or higher fret on "
        + "the same string, without picking it), or a slide.\n\nTapped twice, heard as two notes? It "
        + "joins from the note before. Tapped once, heard as one? Pick how it started, then tap the fret "
        + "it came from; a slide can also come in From below or From above. A double-stop that moves as "
        + "one works the same way. The tab reads the same however you tapped it."
}
