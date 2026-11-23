import XCTest
@testable import Pocket

/// **An editor doesn't write over what it can't read** (ADR 0313 D4). A newer build's content — a Triads
/// run, say — reads as nothing here, and the run falls back to the click. The shape sheet would then seed
/// its own default and Done would write it over the payload. These hold the guard at the setters, which
/// is where every editor's write goes through. Uninserted models: no context is needed for a payload.
final class ExerciseUnreadableContentTests: XCTestCase {

    /// What a later build writes for a Triads run: a `FretboardContent` kind this build has no case for.
    private let newerFretboardBlob = Data(#"{"kind":"triads","triads":{"version":1,"tonic":0}}"#.utf8)

    func testANewerBuildsFretboardContentReadsAsNothingAndIsUnreadable() {
        let exercise = Exercise(name: "Triads", template: .arpeggios, templatePayload: newerFretboardBlob)
        XCTAssertNil(exercise.fretboardContent, "precondition: this build can't read it")
        XCTAssertNil(exercise.fretboardDrill, "so the run plays as a click")
        XCTAssertTrue(exercise.hasUnreadableContent)
    }

    func testWritingNewContentLeavesAnUnreadablePayloadAsItWas() {
        let exercise = Exercise(name: "Triads", template: .arpeggios, templatePayload: newerFretboardBlob)
        exercise.setFretboardContent(.arpeggio(.aMinorSeventh))
        XCTAssertEqual(exercise.templatePayload, newerFretboardBlob, "the editor's A minor 7 must not land")
    }

    func testEveryPayloadKindIsGuarded() {
        let unreadable = Data(#"{"from":"a later build"}"#.utf8)

        let strum = Exercise(name: "Strum", template: .strumming, templatePayload: unreadable)
        XCTAssertTrue(strum.hasUnreadableContent)
        strum.setStrumPattern(.folk)
        XCTAssertEqual(strum.templatePayload, unreadable)

        let chords = Exercise(name: "Chords", template: .chords, templatePayload: unreadable)
        XCTAssertTrue(chords.hasUnreadableContent)
        chords.setChordProgression(.gMajorPop)
        XCTAssertEqual(chords.templatePayload, unreadable)

        let sheet = Exercise(name: "Strum and chords", template: .strumChords, templatePayload: unreadable)
        XCTAssertTrue(sheet.hasUnreadableContent)
        sheet.setStrumChordSheet(.popGroove)
        XCTAssertEqual(sheet.templatePayload, unreadable)
    }

    func testReadableContentAndNoContentAreStillWritten() {
        let readable = Exercise(name: "Arpeggio", template: .arpeggios)
        XCTAssertFalse(readable.hasUnreadableContent, "no payload: nothing to lose")
        readable.setFretboardContent(.arpeggio(.aMinorSeventh))
        XCTAssertEqual(readable.fretboardContent, .arpeggio(.aMinorSeventh))
        XCTAssertFalse(readable.hasUnreadableContent)

        let custom = FretboardContent.custom(.spiderWalk)
        readable.setFretboardContent(custom)
        XCTAssertEqual(readable.fretboardContent, custom, "an edit of readable content still saves")
    }

    func testABlobFromBeforeTheGenerativePayloadStillCountsAsReadable() throws {
        // A bare `FretboardDrill` is how fretboard content was first written; it reads as `.custom`.
        let bare = try JSONEncoder().encode(FretboardDrill.spiderWalk)
        let exercise = Exercise(name: "Spider", template: .picking, templatePayload: bare)
        XCTAssertFalse(exercise.hasUnreadableContent)
    }

    func testAClickOnlyTemplateHasNoContentToProtect() {
        let basic = Exercise(name: "Click", template: .basic, templatePayload: Data("anything".utf8))
        XCTAssertFalse(basic.hasUnreadableContent)
    }
}
