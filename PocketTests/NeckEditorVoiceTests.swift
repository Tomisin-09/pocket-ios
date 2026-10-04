import XCTest
@testable import Pocket

/// What the shared neck editor says (ADR 0235 D9). Name the notes' words were literals in its sheet until
/// the editor was shared; they are pinned here exactly as they were, so moving them changed nothing a player
/// reads. The tab writer's words are its own: about what you play, never what you heard, and no By ear.
final class NeckEditorVoiceTests: XCTestCase {

    func testNameTheNotesSaysWhatItAlwaysSaid() {
        let naming = NeckEditorVoice.naming
        XCTAssertEqual(naming.asOneNote, "heard as one note")
        XCTAssertEqual(naming.asTwoNotes, "heard as two notes")
        XCTAssertEqual(naming.oneNoteOffer, "Heard as one note?")
        XCTAssertEqual(naming.startedElsewhere, " Heard as one note that started elsewhere? Pick how.")
        XCTAssertEqual(naming.intoInfo, NamingInfo.into)
        XCTAssertEqual(naming.chordsInfo, NamingInfo.chords)
        XCTAssertTrue(NamingInfo.chords.hasSuffix("A chord you heard but didn't play is named on By ear."))
        XCTAssertTrue(NamingInfo.into.hasPrefix("How you got to this note: picked, a hammer-on or pull-off"))
    }

    func testTheWriterNeverTalksAboutHearing() {
        let writing = NeckEditorVoice.writing
        let said = [writing.asOneNote, writing.asTwoNotes, writing.oneNoteOffer,
                    writing.startedElsewhere, writing.intoInfo, writing.chordsInfo]
        for line in said {
            XCTAssertFalse(line.localizedCaseInsensitiveContains("heard"), line)
            XCTAssertFalse(line.localizedCaseInsensitiveContains("By ear"), line)
        }
        XCTAssertNotEqual(writing, NeckEditorVoice.naming)
    }
}
