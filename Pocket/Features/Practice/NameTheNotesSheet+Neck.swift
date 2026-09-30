import SwiftUI

// **Fret & string** on the neck (ADR 0227 D3): where you played it. The neck, its marks, *Into it* and
// *Chords* are `NeckNoteEditor`, which the tab writer shares (ADR 0235 D9); the sheet hands it the pass's
// answers and its cursor, and says what a tap on the neck means here. Split out for file length.
extension NameTheNotesSheet {

    var neckPicker: some View {
        NeckNoteEditor(answers: labels, cursor: $cursor, tuning: tuning, spelling: spelling, noun: noun,
                       voice: .naming, scrollTarget: neckTarget, hearing: hearing,
                       write: { labels = $0 },
                       onPlace: { string, fret in place(string: string, fret: fret) },
                       onInstrument: { showingInstrument = true })
    }

    /// A tap on the neck, by `NeckEditing.place`: with Chords off it replaces the note (which keeps its
    /// marks), with Chords on it builds a shape one note per string. A name given by ear just gives way:
    /// only overwriting neck work asks first (0227 D7). A join that no longer fits is dropped by the
    /// sheet's tidy. While *Into it* waits for where a note started, the tap says that instead.
    ///
    /// With Chords off, **placing a note moves on to the next**, silently (ADR 0234 D3): the strip was a
    /// second tap per note, and moving by tapping a chip played it, which with *Hear 8 notes* was eight
    /// notes every time. The marks stay on the note just placed until the next one is (`placedNote`), and
    /// the board stays put. Tapping the note already there confirms it and moves on.
    private func place(string: Int, fret: Int) {
        if awaitingStart == nil { replacing = nil }
        let edit = NeckEditing.place(string: string, fret: fret, labels: labels, cursor: cursor)
        if edit.labels != labels { labels = edit.labels }
        cursor = edit.cursor
    }

    /// Where a placed note sits from the one being named, said after the spot: ", note 11, 1 before".
    nonisolated static func neighbourWords(_ mark: NeckNeighbours.Mark?, noun: String) -> String {
        NeckNoteEditor.neighbourWords(mark, noun: noun)
    }
}

// MARK: - The cursor, by the names the sheet has always used

extension NameTheNotesSheet {
    var active: Int {
        get { cursor.active }
        nonmutating set { cursor.active = newValue }
    }
    var placedNote: Int? {
        get { cursor.placedNote }
        nonmutating set { cursor.placedNote = newValue }
    }
    var ringed: Int? {
        get { cursor.ringed }
        nonmutating set { cursor.ringed = newValue }
    }
    var chordsOn: Bool {
        get { cursor.chordsOn }
        nonmutating set { cursor.chordsOn = newValue }
    }
    var awaitingStart: LeadInRequest? {
        get { cursor.awaitingStart }
        nonmutating set { cursor.awaitingStart = newValue }
    }
}
