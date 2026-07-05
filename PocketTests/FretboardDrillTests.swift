import XCTest
@testable import Pocket

/// Pure note-timing + display math for the fretboard content template (ADR 0065 build 2). The
/// SwiftUI-free core the board renderer only skins — exhaustively unit-tested per AGENTS.md
/// ("which note is active at time t" is pure logic that breaks silently otherwise).
final class FretboardDrillTests: XCTestCase {

    // MARK: - Geometry

    func testNotesPerBeatAndStringCountClampToAtLeastOne() {
        let drill = FretboardDrill(notesPerBeat: 0, notes: [FretNote(string: 5, fret: 1)], stringCount: 0)
        XCTAssertEqual(drill.notesPerBeat, 1)
        XCTAssertEqual(drill.stringCount, 1)
    }

    func testLengthInBeatsForEighthsRun() {
        // Eight eighth-note notes = four beats (one 4/4 bar).
        XCTAssertEqual(FretboardDrill.spiderWalk.lengthInBeats, 4, accuracy: 0.0001)
    }

    func testLengthInBeatsIsZeroForEmptyDrill() {
        XCTAssertEqual(FretboardDrill(notesPerBeat: 2, notes: []).lengthInBeats, 0, accuracy: 0.0001)
    }

    func testBeatOffsetOfNote() {
        let drill = FretboardDrill.spiderWalk   // eighths → each note half a beat apart
        XCTAssertEqual(drill.beatOffset(ofNote: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(drill.beatOffset(ofNote: 1), 0.5, accuracy: 0.0001)
        XCTAssertEqual(drill.beatOffset(ofNote: 4), 2.0, accuracy: 0.0001)
    }

    // MARK: - activeNoteIndex(atBeat:)

    func testActiveNoteAdvancesWithinABeatForEighths() {
        let drill = FretboardDrill.spiderWalk
        XCTAssertEqual(drill.activeNoteIndex(atBeat: 0.0), 0)
        XCTAssertEqual(drill.activeNoteIndex(atBeat: 0.49), 0)
        XCTAssertEqual(drill.activeNoteIndex(atBeat: 0.5), 1)
        XCTAssertEqual(drill.activeNoteIndex(atBeat: 0.99), 1)
        XCTAssertEqual(drill.activeNoteIndex(atBeat: 1.0), 2)
    }

    func testActiveNoteWrapsAtCycleLength() {
        let drill = FretboardDrill.spiderWalk   // eight notes, wraps every four beats
        XCTAssertEqual(drill.activeNoteIndex(atBeat: 4.0), 0)
        XCTAssertEqual(drill.activeNoteIndex(atBeat: 4.5), 1)
        XCTAssertEqual(drill.activeNoteIndex(atBeat: 8.0), 0)
    }

    func testActiveNoteIsNilBeforeBeatZero() {
        XCTAssertNil(FretboardDrill.spiderWalk.activeNoteIndex(atBeat: -0.1))
        XCTAssertNil(FretboardDrill.spiderWalk.activeNoteIndex(atBeat: -1.0))
    }

    func testActiveNoteIsNilForEmptyOrNonFinite() {
        XCTAssertNil(FretboardDrill(notesPerBeat: 2, notes: []).activeNoteIndex(atBeat: 1.0))
        XCTAssertNil(FretboardDrill.spiderWalk.activeNoteIndex(atBeat: .infinity))
        XCTAssertNil(FretboardDrill.spiderWalk.activeNoteIndex(atBeat: .nan))
    }

    // MARK: - note(at:)

    func testNoteAtWrapsForAnyIndex() {
        let drill = FretboardDrill.spiderWalk
        XCTAssertEqual(drill.note(at: 0), FretNote(string: 5, fret: 1))
        XCTAssertEqual(drill.note(at: 8), FretNote(string: 5, fret: 1))   // wraps to 0
        XCTAssertEqual(drill.note(at: -1), FretNote(string: 4, fret: 4))  // wraps to 7
    }

    func testNoteAtIsNilForRestSlotAndEmptyDrill() {
        let withRest = FretboardDrill(notesPerBeat: 2, notes: [FretNote(string: 5, fret: 1), nil])
        XCTAssertNil(withRest.note(at: 1))
        XCTAssertNil(FretboardDrill(notesPerBeat: 2, notes: []).note(at: 0))
    }

    // MARK: - Display window (derived, so the payload stays lean)

    func testDisplayWindowSpansTheFrettedNotesWithAMinimumWidth() {
        // Spider walk uses frets 1–4 → window starts at fret 1, four columns wide.
        XCTAssertEqual(FretboardDrill.spiderWalk.displayLowestFret, 1)
        XCTAssertEqual(FretboardDrill.spiderWalk.displayFretSpan, 4)
    }

    func testDisplayWindowWidensToReachAHighNote() {
        let drill = FretboardDrill(notesPerBeat: 1,
                                   notes: [FretNote(string: 3, fret: 5), FretNote(string: 3, fret: 9)])
        XCTAssertEqual(drill.displayLowestFret, 5)
        XCTAssertEqual(drill.displayFretSpan, 5)   // frets 5…9 inclusive
    }

    func testDisplayWindowDefaultsWhenOnlyOpenOrEmpty() {
        // All-open (or empty) drills fall back to a fret-1, four-wide window rather than dividing by
        // an empty set — open notes sit on the nut, not a fret column.
        let openOnly = FretboardDrill(notesPerBeat: 1, notes: [FretNote(string: 5, fret: 0)])
        XCTAssertEqual(openOnly.displayLowestFret, 1)
        XCTAssertEqual(openOnly.displayFretSpan, 4)
    }

    // MARK: - Presets

    func testSpiderWalkIsChromaticOnTheLowTwoStrings() {
        let notes = FretboardDrill.spiderWalk.notes.compactMap { $0 }
        XCTAssertEqual(notes, [
            FretNote(string: 5, fret: 1), FretNote(string: 5, fret: 2),
            FretNote(string: 5, fret: 3), FretNote(string: 5, fret: 4),
            FretNote(string: 4, fret: 1), FretNote(string: 4, fret: 2),
            FretNote(string: 4, fret: 3), FretNote(string: 4, fret: 4)
        ])
        XCTAssertEqual(FretboardDrill.spiderWalk.notesPerBeat, 2)
    }

    // MARK: - Editing (pure ops the authoring editor skins)

    func testReplacingNotePlacesAndClearsOnlyThatSlot() {
        let drill = FretboardDrill(notesPerBeat: 2,
                                   notes: [FretNote(string: 5, fret: 1), nil, nil, nil])
        let placed = drill.replacingNote(at: 2, with: FretNote(string: 4, fret: 3))
        XCTAssertEqual(placed.notes[2], FretNote(string: 4, fret: 3))
        XCTAssertEqual(placed.notes[0], FretNote(string: 5, fret: 1))   // untouched
        let cleared = placed.replacingNote(at: 0, with: nil)
        XCTAssertNil(cleared.notes[0])
    }

    func testReplacingNoteOutOfRangeIsUnchanged() {
        let drill = FretboardDrill.spiderWalk
        XCTAssertEqual(drill.replacingNote(at: 99, with: FretNote(string: 0, fret: 0)), drill)
        XCTAssertEqual(drill.replacingNote(at: -1, with: nil), drill)
    }

    func testResizedToFinerResolutionKeepsNotesOnTheirBeats() {
        // Quarters [A,B,C,D] → eighths over 4 beats = 8 slots: each note stays on its beat, the new
        // "and" positions between them are rests (not crammed into the first half — the index bug).
        let quarters = FretboardDrill(notesPerBeat: 1, notes: [
            FretNote(string: 5, fret: 1), FretNote(string: 5, fret: 2),
            FretNote(string: 5, fret: 3), FretNote(string: 5, fret: 4)
        ])
        let eighths = quarters.resized(notesPerBeat: 2, beatsPerBar: 4)
        XCTAssertEqual(eighths.notesPerBeat, 2)
        XCTAssertEqual(eighths.notes, [
            FretNote(string: 5, fret: 1), nil, FretNote(string: 5, fret: 2), nil,
            FretNote(string: 5, fret: 3), nil, FretNote(string: 5, fret: 4), nil
        ])
    }

    func testResizingCoarserThenFinerDoesNotWipeTheBar() {
        // The strumming round-trip bug, guarded for fretboard too: eighths → quarters → eighths keeps
        // the on-beat notes (offsets 0,1,2,3), sub-beat notes are the deliberate downsample loss.
        let roundTrip = FretboardDrill.spiderWalk   // 8 eighth notes over 4 beats
            .resized(notesPerBeat: 1, beatsPerBar: 4)
            .resized(notesPerBeat: 2, beatsPerBar: 4)
        XCTAssertEqual(roundTrip.notesPerBeat, 2)
        XCTAssertEqual(roundTrip.notes, [
            FretNote(string: 5, fret: 1), nil, FretNote(string: 5, fret: 3), nil,
            FretNote(string: 4, fret: 1), nil, FretNote(string: 4, fret: 3), nil
        ])
    }

    func testResizedClampsNotesPerBeatToAtLeastOne() {
        let resized = FretboardDrill.spiderWalk.resized(notesPerBeat: 0, beatsPerBar: 3)
        XCTAssertEqual(resized.notesPerBeat, 1)
        XCTAssertEqual(resized.notes.count, 3)
    }

    // MARK: - Codable round-trip + versioning (T4)

    func testDrillRoundTripsThroughCodable() throws {
        let original = FretboardDrill(notesPerBeat: 2,
                                      notes: [FretNote(string: 5, fret: 3, technique: .hammerOn), nil])
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(FretboardDrill.self, from: data), original)
    }

    func testNewDrillCarriesCurrentVersion() {
        XCTAssertEqual(FretboardDrill.spiderWalk.version, FretboardDrill.currentVersion)
    }

    /// A blob written by a newer build still decodes best-effort — the version rides along so a
    /// future decode-time upgrade can act on it (T4).
    func testDecodesPayloadFromANewerVersion() throws {
        let future = FretboardDrill(notesPerBeat: 4,
                                    notes: [FretNote(string: 0, fret: 7)],
                                    version: FretboardDrill.currentVersion + 1)
        let data = try JSONEncoder().encode(future)
        let decoded = try JSONDecoder().decode(FretboardDrill.self, from: data)
        XCTAssertEqual(decoded.version, FretboardDrill.currentVersion + 1)
        XCTAssertEqual(decoded.notes.compactMap { $0 }, [FretNote(string: 0, fret: 7)])
    }
}
