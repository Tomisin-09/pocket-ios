import XCTest
@testable import Pocket

/// **Writing a progression** (ADR 0218 D10): what the builder's controls do to a draft, and how a draft
/// becomes a saved row. Models are left uninserted — inserting in the XCTest host traps
/// (`docs/swiftdata-gotchas.md`), and nothing here needs a store.
final class SavedProgressionTests: XCTestCase {

    private func names(_ draft: ProgressionDraft) -> [String] {
        draft.steps.map { draft.key.chordName(of: $0, preference: .sharps) }
    }

    // MARK: - The draft

    func testADraftNeedsANameAndAChord() {
        var draft = ProgressionDraft()
        XCTAssertFalse(draft.canSave)
        draft.name = "   "
        draft.append(ProgressionStep(0))
        XCTAssertFalse(draft.canSave, "a blank name is no name")
        draft.name = "Verse"
        XCTAssertTrue(draft.canSave)
        draft.remove(at: 0)
        XCTAssertFalse(draft.canSave, "a name with no chords is nothing to insert")
    }

    /// **Picking the key corrects it; it doesn't transpose.** A player who wrote G · C · D against C and
    /// then says "it's in G" wants the same chords, read as I · IV · V.
    func testChangingTheKeyKeepsTheChordsAndRereadsTheNumerals() {
        var draft = ProgressionDraft(name: "Verse", tonic: 0,
                                     steps: [ProgressionStep(7), ProgressionStep(0), ProgressionStep(2)])
        XCTAssertEqual(names(draft), ["G", "C", "D"])
        XCTAssertEqual(draft.steps.numerals, "V – I – II")

        draft.setTonic(7)
        XCTAssertEqual(names(draft), ["G", "C", "D"], "the chords stay put")
        XCTAssertEqual(draft.steps.numerals, "I – IV – V", "only their reading changes")
        XCTAssertEqual(draft.tonic, 7)
    }

    func testMovingRemovingAndHoldingStayInBounds() {
        var draft = ProgressionDraft(steps: [ProgressionStep(0), ProgressionStep(5), ProgressionStep(7)])
        draft.move(at: 2, by: -2)
        XCTAssertEqual(draft.steps.map(\.semitones), [7, 0, 5])
        draft.move(at: 0, by: -1)
        XCTAssertEqual(draft.steps.map(\.semitones), [7, 0, 5], "off the top is a no-op, not a wrap")
        draft.remove(at: 9)
        XCTAssertEqual(draft.steps.count, 3)

        draft.setBars(at: 1, to: 99)
        XCTAssertEqual(draft.steps[1].bars, ProgressionDraft.maxBars)
        draft.setBars(at: 1, to: 0)
        XCTAssertEqual(draft.steps[1].bars, 1)
    }

    func testTheInKeyRowIsTheSixChordsEveryKeyCanFret() {
        XCTAssertEqual(ProgressionDraft.inKey.numerals, "I – ii – iii – IV – V – vi")
        for tonic in 0..<12 {
            let key = ProgressionKey(tonic: tonic)
            for step in ProgressionDraft.inKey {
                let voicing = ProgressionResolver.resolve(step, in: key, instrument: .guitar).voicing
                XCTAssertTrue(ProgressionResolver.fits(voicing, root: key.rootPitchClass(of: step),
                                                       quality: step.quality),
                              "\(step.numeral) in \(tonic) has no shape")
            }
        }
    }

    // MARK: - The saved row

    func testSavingADraftTrimsTheNameAndKeepsTheKeyItWasWrittenIn() {
        let draft = ProgressionDraft(name: "  Verse changes ", tonic: 2,
                                     steps: [ProgressionStep(0), ProgressionStep(7, .dom7, bars: 2)])
        let saved = SavedProgression(draft)
        XCTAssertEqual(saved.name, "Verse changes")
        XCTAssertEqual(saved.steps, draft.steps)
        XCTAssertEqual(saved.payload.tonic, 2)
        XCTAssertEqual(saved.draft.tonic, 2, "an edit opens in the key it was written in")
    }

    func testAnEditWritesTheNameAndTheChordsTogether() {
        let saved = SavedProgression(ProgressionDraft(name: "Old", steps: [ProgressionStep(0)]))
        var edit = saved.draft
        edit.name = "New"
        edit.append(ProgressionStep(5))
        saved.update(from: edit)
        XCTAssertEqual(saved.name, "New")
        XCTAssertEqual(saved.steps.count, 2)

        var blank = saved.draft
        blank.name = ""
        saved.update(from: blank)
        XCTAssertEqual(saved.name, "New", "a draft that can't be saved changes nothing")
    }

    func testAnUnreadableBlobIsAnEmptyProgressionNotACrash() {
        let saved = SavedProgression(name: "Broken", stepsData: Data("not json".utf8))
        XCTAssertEqual(saved.steps, [])
        XCTAssertNil(saved.payload.tonic)
    }

    func testAPayloadMissingItsVersionOrKeyStillDecodes() throws {
        let json = Data(#"{"steps":[{"semitones":9,"quality":"minor","bars":1}]}"#.utf8)
        let payload = try JSONDecoder().decode(SavedProgressionPayload.self, from: json)
        XCTAssertEqual(payload.steps, [ProgressionStep(9, .minor)])
        XCTAssertEqual(payload.version, SavedProgressionPayload.currentVersion)
        XCTAssertNil(payload.tonic)
    }
}
