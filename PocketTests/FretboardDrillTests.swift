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

    // MARK: - Following viewport (ADR 0083 S5 — pure "only scroll when you have to" fn of the walk)

    /// A run climbing one string from fret 1 to fret 12 in eighths — a genuine neck-climb, too wide for
    /// the static board, so the following viewport engages. `notes[i]` is fret `i + 1`.
    private func climb1to12() -> FretboardDrill {
        FretboardDrill(notesPerBeat: 2, notes: (1...12).map { FretNote(string: 5, fret: $0) })
    }

    /// A longer climb (frets 1 → 16) whose top is far enough up the neck that the follow window is not
    /// pinned by the run's own ceiling — so the look-ahead behaviour shows without the `maxLow` clamp.
    private func climb1to16() -> FretboardDrill {
        FretboardDrill(notesPerBeat: 2, notes: (1...16).map { FretNote(string: 5, fret: $0) })
    }

    func testFollowingIsInertAtRestAndForNarrowRuns() {
        // A rest / animate-off read (activeIndex nil) always keeps the full static window…
        let climb = climb1to12()
        XCTAssertEqual(climb.displayWindow(activeIndex: nil),
                       FretWindow(lowestFret: climb.displayLowestFret, span: climb.displayFretSpan))
        // …and a run that already fits the comfortable board never follows, even mid-walk.
        let narrow = FretboardDrill.spiderWalk
        XCTAssertEqual(narrow.displayWindow(activeIndex: 3),
                       FretWindow(lowestFret: narrow.displayLowestFret, span: narrow.displayFretSpan))
    }

    func testGentleClimbThatFitsTheComfortableBoardNeverFollows() {
        // The reported case: a 1-2-3-4 pattern climbing +1 fret per pass over 4 passes lives entirely
        // in frets 1–7 (≤ the comfortable board), so the window must stay static the whole walk — no
        // pointless mid-run shift.
        let run = FretboardRun(fingers: [1, 2, 3, 4], baseFret: 1, fromString: 5, toString: 0,
                               roundTrip: false, fretShiftPerPass: 1, passCount: 4)
        let drill = run.expanded()
        XCTAssertEqual(drill.displayFretSpan, 7)   // frets 1…7
        let staticWindow = FretWindow(lowestFret: drill.displayLowestFret, span: drill.displayFretSpan)
        for activeIndex in 0..<drill.noteCount {
            XCTAssertEqual(drill.displayWindow(activeIndex: activeIndex), staticWindow,
                           "a gentle climb reframed at index \(activeIndex) when it should stay static")
        }
    }

    func testFollowingHoldsStillThenScrollsOnlyWhenTheNoteReachesTheEdge() {
        let climb = climb1to12()   // width-8 following window
        // Frets 1–7 all sit inside the opening window [1…8] — it does not budge as the note climbs.
        for activeIndex in 0...6 {
            XCTAssertEqual(climb.displayWindow(activeIndex: activeIndex), FretWindow(lowestFret: 1, span: 8))
        }
        // Fret 8 reaches the right edge → a single scroll, and that one scroll carries the rest of the
        // climb (frets 8–12 all sit in the new window — no further reframes near the run's ceiling).
        for activeIndex in 7...11 {
            XCTAssertEqual(climb.displayWindow(activeIndex: activeIndex), FretWindow(lowestFret: 5, span: 8))
        }
    }

    func testFollowingLandsTheNoteNearTheTrailingEdgeToMaximiseLookAhead() {
        // The look-ahead priority: when the window scrolls mid-neck (away from the run's ceiling), the
        // note lands one fret in from the trailing edge, so most of the window is the runway ahead and
        // the board travels far before it needs to scroll again.
        let climb = climb1to16()
        // Holds [1…8] up to fret 7, then one scroll at fret 8 places it at column 1 of [7…14].
        XCTAssertEqual(climb.displayWindow(activeIndex: 6), FretWindow(lowestFret: 1, span: 8))
        XCTAssertEqual(climb.displayWindow(activeIndex: 7), FretWindow(lowestFret: 7, span: 8))
        XCTAssertEqual(climb.displayWindow(activeIndex: 7).lowestFret, 8 - FretboardDrill.followTrailing)
        // That one scroll then carries five more frets before the next — frets 8–13 share the window.
        for activeIndex in 7...12 {
            XCTAssertEqual(climb.displayWindow(activeIndex: activeIndex).lowestFret, 7)
        }
        XCTAssertNotEqual(climb.displayWindow(activeIndex: 13).lowestFret, 7)   // fret 14 finally reframes
    }

    func testFollowingKeepsTheNoteInViewEveryFrame() {
        for climb in [climb1to12(), climb1to16()] {
            for activeIndex in 0..<climb.noteCount {
                let window = climb.displayWindow(activeIndex: activeIndex)
                let activeFret = activeIndex + 1
                XCTAssertTrue((window.lowestFret..<(window.lowestFret + window.span)).contains(activeFret),
                              "fret \(activeFret) fell outside \(window)")
            }
        }
    }

    func testFollowingReframesRarely() {
        // The whole point of the trailing-edge landing: a full 16-fret climb reframes only a couple of
        // times, so the board is easy to track (fewer shifts read as calmer than many small ones).
        let climb = climb1to16()
        let lows = (0..<climb.noteCount).map { climb.displayWindow(activeIndex: $0).lowestFret }
        let reframes = zip(lows, lows.dropFirst()).filter { $0 != $1 }.count
        XCTAssertLessThanOrEqual(reframes, 2, "a 16-fret climb should reframe at most twice, got \(reframes)")
    }

    func testFollowingResetsToTheBottomWhenTheCycleWraps() {
        // The walk loops: the top of the climb reframes high, and returning to note 0 snaps back to the
        // opening window rather than staying stuck at the top.
        let climb = climb1to12()
        XCTAssertEqual(climb.displayWindow(activeIndex: 11).lowestFret, 5)   // top of the climb
        XCTAssertEqual(climb.displayWindow(activeIndex: 0).lowestFret, 1)    // wrapped back to the start
    }

    func testFollowingTracksTheNearestFrettedNoteAcrossARest() {
        // A rest mid-climb holds the window on the nearest fretted neighbour rather than snapping it.
        var notes: [FretNote?] = (1...12).map { FretNote(string: 5, fret: $0) }
        notes[8] = nil   // a rest where fret 9 would sound; the fretted neighbour is fret 8 (index 7)
        let drill = FretboardDrill(notesPerBeat: 2, notes: notes)
        XCTAssertEqual(drill.displayWindow(activeIndex: 8), FretWindow(lowestFret: 5, span: 8))
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

    func testClearedResetsEveryNoteButKeepsTheGrid() {
        let drill = FretboardDrill(notesPerBeat: 3,
                                   notes: [FretNote(string: 5, fret: 1), nil, FretNote(string: 4, fret: 3)],
                                   stringCount: 6, rootPitchClass: 7)
        let cleared = drill.cleared()
        XCTAssertTrue(cleared.notes.allSatisfy { $0 == nil }, "every slot becomes a rest")
        XCTAssertEqual(cleared.notes.count, drill.notes.count, "same length")
        XCTAssertEqual(cleared.notesPerBeat, 3, "subdivision preserved")
        XCTAssertEqual(cleared.stringCount, 6)
        XCTAssertEqual(cleared.rootPitchClass, 7, "root preserved")
    }

    func testHasNoNotesReflectsWhetherAnySlotIsPlaced() {
        XCTAssertFalse(FretboardDrill.spiderWalk.hasNoNotes)
        XCTAssertTrue(FretboardDrill.spiderWalk.cleared().hasNoNotes)
        XCTAssertTrue(FretboardDrill(notesPerBeat: 2, notes: [nil, nil]).hasNoNotes)
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

    /// `noteGroups` (ADR 0083 S2b — pass focus) is a transient generation artifact: it must never
    /// touch the encoded shape (no persisted-blob change, no migration) and decodes back to `nil`.
    func testPassGroupsAreNeverEncodedAndDecodeToNil() throws {
        let tagged = FretboardDrill(notesPerBeat: 2,
                                    notes: [FretNote(string: 5, fret: 1), FretNote(string: 5, fret: 3)],
                                    noteGroups: [0, 1])
        let data = try JSONEncoder().encode(tagged)
        let json = try XCTUnwrap(String(bytes: data, encoding: .utf8))
        XCTAssertFalse(json.contains("noteGroups"))
        XCTAssertNil(try JSONDecoder().decode(FretboardDrill.self, from: data).noteGroups)
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
