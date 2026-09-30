import XCTest
@testable import Pocket

/// The fixtures slice 3b's tests share (ADR 0232 D15, D16): a song cut into five sections.
class SongMapSlice3bCase: SongMapSlice3Case {
    let verse = UUID(), chorus = UUID(), bridge = UUID(), outro = UUID()

    /// Start 0–8, Verse 8–24, Chorus 24–40, Bridge 40–52, Outro 52–64.
    func fiveSections() -> [SongMapInput.MarkerInput] {
        [marker(8, "Verse", uid: verse), marker(24, "Chorus", uid: chorus), marker(40, "Bridge", uid: bridge),
         marker(52, "Outro", uid: outro)]
    }

    func chord(_ seconds: TimeInterval, _ root: Int) -> PieceTranscription.Tap {
        .init(seconds: seconds, label: .chord(root: root, suffix: ""))
    }

    /// The loop copied from: the verse's first four bars, holding `piece` (the changes, unless another).
    func verseChanges(_ piece: PieceTranscription? = nil, end: TimeInterval = 16) -> SongMapCopy.Source {
        SongMapCopy.Source(piece: piece ?? changes(), start: 8, end: end)
    }

    /// Four bars of changes, one chord a bar, each tapped a quarter of a second late: a time that shifts
    /// exactly in binary, so a copy's taps can be compared exactly.
    func changes(from start: TimeInterval = 8) -> PieceTranscription {
        PieceTranscription(taps: [chord(start + 0.25, 0), chord(start + 2.25, 5), chord(start + 4.25, 7),
                                  chord(start + 6.25, 0)])
    }
}

/// How far a loop repeats (ADR 0232 D15): its section, a later section, or the song, and what the hold menu
/// offers. The player's word; the map only draws it.
final class SongMapRepeatReachTests: SongMapSlice3bCase {

    func testARepeatThroughALaterSectionRunsToThatSectionsEnd() throws {
        let uid = UUID()
        let map = build(grid: grid(), markers: fiveSections(),
                        loops: [loop(8, 16, repeats: true, to: .through(chorus), uid: uid)])
        XCTAssertEqual(map.pieces[uid]?.repeats, SongMap.Repeat(end: 40, passes: 4))
        XCTAssertEqual(map.pieces[uid]?.repeatsTo, .through(chorus))
        let chorusRows = try section(map, "Chorus").rows
        let bands = chorusRows.flatMap { $0.lanes.first { $0.layer == .chords }?.bands ?? [] }
        XCTAssertEqual(bands.map { [$0.start, $0.end] }, [[24, 40]], "the band carries on across the chorus")
        XCTAssertEqual(bands.map(\.continuesBefore), [true])
        XCTAssertEqual(chordsGaps(try section(map, "Chorus")), [], "the repeats cover it")
        XCTAssertEqual(chordsGaps(try section(map, "Bridge")).map(\.start), [40], "and stop where it ends")
    }

    func testARepeatToTheSongsEndRunsAcrossEverySectionAndHoldsItsLane() throws {
        let vamp = UUID(), turnaround = UUID(), lick = UUID()
        let map = build(markers: fiveSections(),
                        loops: [loop(8, 16, repeats: true, to: .songEnd, uid: vamp),
                                loop(44, 48, uid: turnaround), loop(44, 48, type: .lick, uid: lick)])
        XCTAssertEqual(map.pieces[vamp]?.repeats, SongMap.Repeat(end: 64, passes: 7))
        XCTAssertEqual(map.pieces[turnaround]?.lane, 1, "under the repeats, not over them")
        XCTAssertEqual(map.pieces[lick]?.lane, 0, "only the chords lane is held")
        for label in ["Chorus", "Bridge", "Outro"] {
            XCTAssertEqual(chordsGaps(try section(map, label)), [], "\(label) is covered")
        }
    }

    func testTheReachMeansNothingUntilTheLoopRepeats() {
        let uid = UUID()
        let map = build(markers: fiveSections(), loops: [loop(8, 16, to: .songEnd, uid: uid)])
        XCTAssertNil(map.pieces[uid]?.repeats)
    }

    func testASectionThatsGoneOrEarlierReadsAsItsOwn() {
        let gone = UUID(), earlier = UUID()
        let map = build(markers: fiveSections(),
                        loops: [loop(8, 16, repeats: true, to: .through(UUID()), uid: gone),
                                loop(24, 32, repeats: true, to: .through(verse), uid: earlier)])
        XCTAssertEqual(map.pieces[gone]?.repeats?.end, 24)
        XCTAssertEqual(map.pieces[gone]?.repeatsTo, .sectionEnd)
        XCTAssertEqual(map.pieces[earlier]?.repeats?.end, 40, "not back to the verse's end")
        XCTAssertEqual(map.pieces[earlier]?.repeatsTo, .sectionEnd)
    }

    func testThroughTheLastSectionReadsAsTheSongsEnd() {
        let uid = UUID()
        let map = build(markers: fiveSections(), loops: [loop(8, 16, repeats: true, to: .through(outro), uid: uid)])
        XCTAssertEqual(map.pieces[uid]?.repeats?.end, 64)
        XCTAssertEqual(map.pieces[uid]?.repeatsTo, .songEnd, "so the menu ticks To the end of the song")
    }

    func testTheMenuOffersItsSectionEachLaterSectionButTheLastAndTheSong() throws {
        let uid = UUID()
        let map = build(markers: fiveSections(), loops: [loop(8, 16, uid: uid)])
        XCTAssertEqual(map.repeatChoices(for: try XCTUnwrap(map.pieces[uid])), [
            SongMap.RepeatChoice(to: .sectionEnd, title: "To the end of the section", passes: 2),
            SongMap.RepeatChoice(to: .through(chorus), title: "Through Chorus", passes: 4),
            SongMap.RepeatChoice(to: .through(bridge), title: "Through Bridge", passes: 6),
            SongMap.RepeatChoice(to: .songEnd, title: "To the end of the song", passes: 7)
        ])
    }

    func testALoopFillingItsSectionCanStillRepeatOnThroughTheNext() throws {
        let uid = UUID()
        let map = build(markers: fiveSections(), loops: [loop(8, 24, uid: uid)])
        XCTAssertEqual(map.repeatChoices(for: try XCTUnwrap(map.pieces[uid])).map(\.to),
                       [.through(chorus), .through(bridge), .songEnd])
    }

    func testInTheLastSectionItsEndIsTheSongsAndIsOfferedOnce() throws {
        let uid = UUID()
        let map = build(markers: fiveSections(), loops: [loop(52, 56, uid: uid)])
        XCTAssertEqual(map.repeatChoices(for: try XCTUnwrap(map.pieces[uid])).map(\.to), [.sectionEnd])
    }

    func testWithoutSectionsTheSongsEndIsTheOnlyChoice() throws {
        let uid = UUID()
        let map = build(loops: [loop(0, 8, uid: uid)])
        XCTAssertEqual(map.repeatChoices(for: try XCTUnwrap(map.pieces[uid])),
                       [SongMap.RepeatChoice(to: .sectionEnd, title: "To the end of the song", passes: 8)])
    }

    func testTwoSectionsWithOneNameAreToldApartByWhereTheyStart() throws {
        let uid = UUID()
        let map = build(grid: grid(), markers: [marker(8, "Verse"), marker(24, "Chorus"), marker(32, "Verse"),
                                                marker(40, "Chorus"), marker(56, "Outro")],
                        loops: [loop(8, 12, uid: uid)])
        XCTAssertEqual(map.repeatChoices(for: try XCTUnwrap(map.pieces[uid])).map(\.title), [
            "To the end of the section", "Through Chorus, bar 13", "Through Verse", "Through Chorus, bar 21",
            "To the end of the song"
        ])
    }

    func testTheTabSheetSaysHowFarAndHowManyTimes() throws {
        let uid = UUID()
        let map = build(markers: fiveSections(), loops: [loop(8, 16, repeats: true, to: .through(chorus), uid: uid)])
        XCTAssertEqual(map.repeatLine(for: try XCTUnwrap(map.pieces[uid])), "Repeats through Chorus, 4 times in all.")
        let plain = build(markers: fiveSections(), loops: [loop(8, 16, uid: uid)])
        XCTAssertNil(plain.repeatLine(for: try XCTUnwrap(plain.pieces[uid])))
    }

    func testTheReachIsStoredAsTextAndAnUnknownOneReadsAsItsSection() {
        let uid = UUID()
        for reach in [SongMap.RepeatsTo.sectionEnd, .songEnd, .through(uid)] {
            XCTAssertEqual(SongMap.RepeatsTo(stored: reach.stored), reach)
        }
        XCTAssertNil(SongMap.RepeatsTo.sectionEnd.stored, "a loop that never chose reads as D14's")
        XCTAssertEqual(SongMap.RepeatsTo(stored: "a later build's reach"), .sectionEnd)
    }
}

/// Copying a piece (ADR 0232 D16): where it can go, and what's written there. The player's act; every copy
/// is a loop of its own.
final class SongMapCopyTests: SongMapSlice3bCase {

    // MARK: - What's written

    func testAPassIsTheLoopToTheNearestWholeBarWithAGrid() {
        XCTAssertEqual(SongMapCopy.period(from: 8, to: 16.3, grid: grid()), 8, accuracy: 1e-9)
        XCTAssertEqual(SongMapCopy.period(from: 8, to: 8.6, grid: grid()), 2, accuracy: 1e-9, "at least a bar")
        XCTAssertEqual(SongMapCopy.period(from: 8, to: 16.3, grid: nil), 8.3, accuracy: 1e-9)
        XCTAssertEqual(SongMapCopy.every(from: 8, to: 16, grid: grid()), "every 4 bars")
        XCTAssertEqual(SongMapCopy.every(from: 8, to: 10, grid: grid()), "every bar")
        XCTAssertEqual(SongMapCopy.every(from: 8, to: 14, grid: nil), "every 6 seconds")
    }

    func testThePieceIsWrittenPassAfterPassFromWhereTheStretchStarts() {
        let taps = SongMapCopy.taps(of: verseChanges(), across: (24, 40), grid: grid())
        XCTAssertEqual(taps.map(\.seconds), [24.25, 26.25, 28.25, 30.25, 32.25, 34.25, 36.25, 38.25],
                       "each tap as late as it was")
        XCTAssertEqual(taps.map(\.label), changes().taps.map(\.label) + changes().taps.map(\.label))
    }

    func testATapPastTheStretchsEndIsLeftOff() {
        let taps = SongMapCopy.taps(of: verseChanges(), across: (24, 30), grid: grid())
        XCTAssertEqual(taps.map(\.seconds), [24.25, 26.25, 28.25])
    }

    func testOnlyOnePassWorthIsWrittenEachPass() {
        // Drawn a little long: 4.3 bars, so a pass is 4 bars, and the tap in the overhang would land on
        // the next pass's first chord.
        var piece = changes()
        piece.taps.append(chord(16.2, 9))
        let taps = SongMapCopy.taps(of: verseChanges(piece, end: 16.6), across: (24, 40), grid: grid())
        XCTAssertEqual(taps.count, 8)
        XCTAssertFalse(taps.contains { $0.label == .chord(root: 9, suffix: "") })
    }

    func testWithoutAGridAPassIsTheLoopsOwnLength() {
        let piece = PieceTranscription(taps: [chord(8.5, 0), chord(11, 5)])
        let taps = SongMapCopy.taps(of: verseChanges(piece, end: 14), across: (20, 33), grid: nil)
        XCTAssertEqual(taps.map(\.seconds), [20.5, 23, 26.5, 29, 32.5])
    }

    func testCopiesAreNamedLikeMadePiecesAndNeverTwiceTheSame() throws {
        let target = SongMapCopy.Target(start: 24, end: 40, title: "Chorus", place: nil, name: "Chorus chords",
                                        alongside: [])
        let again = SongMapCopy.Target(start: 40, end: 48, title: "Chorus", place: nil, name: "Chorus chords",
                                       alongside: [])
        let copies = SongMapCopy.copies(of: verseChanges(), into: [again, target], grid: grid(),
                                        existingNames: ["Chorus chords"], now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(copies.map(\.name), ["Chorus chords 2", "Chorus chords 3"], "in song order")
        XCTAssertEqual(copies.map(\.start), [24, 40])
        XCTAssertEqual(copies.first?.end, 40)
    }

    func testACopyKeepsItsTuningAndIsDated() throws {
        var piece = changes()
        piece.openMidi = standard
        piece.tuningLabel = "Guitar · Standard"
        let target = SongMapCopy.Target(start: 24, end: 32, title: "", place: nil, name: "Copy", alongside: [])
        let now = Date(timeIntervalSince1970: 1_000)
        let copy = try XCTUnwrap(SongMapCopy.copies(of: verseChanges(piece), into: [target], grid: grid(),
                                                    existingNames: [], now: now).first)
        XCTAssertEqual(copy.piece.openMidi, standard)
        XCTAssertEqual(copy.piece.tuningLabel, "Guitar · Standard")
        XCTAssertEqual(copy.piece.changedAt, now)
    }

    func testAStretchNoTapLandsInMakesNothing() {
        let late = PieceTranscription(taps: [chord(13, 0)])
        let short = SongMapCopy.Target(start: 24, end: 26, title: "", place: nil, name: "Copy", alongside: [])
        XCTAssertEqual(SongMapCopy.copies(of: verseChanges(late), into: [short], grid: grid(),
                                          existingNames: [], now: .now), [])
    }

    // MARK: - Where to

    func testEverySectionButItsOwnIsOfferedWithWhatsThereAlready() throws {
        let intro = UUID()
        let map = build(grid: grid(), markers: fiveSections(),
                        loops: [loop(8, 16, piece: changes(), name: "Verse changes", uid: intro),
                                loop(40, 44, name: "Bridge chords"), loop(24, 28, type: .lick, name: "Lick")])
        let targets = SongMapCopy.targets(for: try XCTUnwrap(map.pieces[intro]), in: map)
        XCTAssertEqual(targets.map(\.title), ["Start", "Chorus", "Bridge", "Outro"])
        XCTAssertEqual(targets.map(\.name), ["Chords, bars 1–4", "Chorus chords", "Bridge chords", "Outro chords"])
        XCTAssertEqual(targets.map(\.place), ["Bars 1–4", "Bars 13–20", "Bars 21–26", "Bars 27–32"])
        XCTAssertEqual(targets.map(\.alongside), [[], [], ["Bridge chords"], []], "the lick is on another lane")
    }

    func testARepeatReachingInCountsAsAlreadyThere() throws {
        let intro = UUID()
        let map = build(markers: fiveSections(),
                        loops: [loop(8, 16, piece: changes(), repeats: true, to: .through(chorus),
                                     name: "Verse changes", uid: intro)])
        let targets = SongMapCopy.targets(for: try XCTUnwrap(map.pieces[intro]), in: map)
        XCTAssertEqual(targets.first { $0.title == "Chorus" }?.alongside, ["Verse changes"])
    }

    func testWithoutSectionsEveryRowButItsOwnIsOffered() throws {
        let uid = UUID()
        let map = build(duration: 32, grid: grid(duration: 32), loops: [loop(0, 8, piece: changes(from: 0), uid: uid)])
        let targets = SongMapCopy.targets(for: try XCTUnwrap(map.pieces[uid]), in: map)
        XCTAssertEqual(targets.map(\.title), ["Bars 9–16"])
        XCTAssertEqual(targets.map(\.name), ["Chords, bars 9–16"])
        XCTAssertEqual(targets.map(\.place), [nil])
    }

    func testAnyRunOfBarsCanBeChosen() throws {
        let map = build(grid: grid(), markers: fiveSections())
        let bars = try XCTUnwrap(SongMapCopy.bars(9...12, layer: .chords, in: map))
        XCTAssertEqual(bars.start, 16)
        XCTAssertEqual(bars.end, 24)
        XCTAssertEqual(bars.name, "Chords, bars 9–12")
        XCTAssertEqual(SongMapCopy.bars(31...32, layer: .notes, in: map)?.end, 64, "the last bar runs to the end")
        XCTAssertNil(SongMapCopy.bars(31...33, layer: .chords, in: map), "no bar 33")
        XCTAssertNil(SongMapCopy.bars(1...4, layer: .chords, in: build(markers: fiveSections())), "no bars")
    }

    func testAGapCanStartFromAnyCountedPieceOnItsLane() throws {
        let counted = UUID(), later = UUID()
        let map = build(markers: fiveSections(),
                        loops: [loop(24, 32, piece: changes(from: 24), uid: later),
                                loop(8, 16, piece: changes(), uid: counted), loop(40, 44),
                                loop(8, 12, type: .lick, piece: PieceTranscription(taps: [.init(seconds: 9)]))])
        let gap = try XCTUnwrap(chordsGaps(try section(map, "Outro")).first)
        XCTAssertEqual(SongMapCopy.sources(for: gap, in: map).map(\.uid), [counted, later],
                       "in song order; not the empty loop, nor the lick on the other lane")
    }

    func testALoopEndingAHairPastASectionsStartDrawsNothingThere() throws {
        // A copy filling the chorus ends where the bridge starts, but its end is stored as a fraction of the
        // song, and reads back a hair past it. Found in a render: a sliver at the start of the next section.
        // The chords one overlaps another, so it's on a second lane, which the bridge mustn't draw empty.
        let map = build(markers: fiveSections(),
                        loops: [loop(24, 40), loop(32, 40 + 1e-9),
                                loop(24, 40 + 1e-9, type: .lick, repeats: true, to: .songEnd)])
        let bridge = try section(map, "Bridge")
        XCTAssertEqual(bridge.rows[0].lanes.filter { $0.layer == .chords }.map(\.placements), [[]], "one lane")
        XCTAssertEqual(chordsGaps(bridge).map(\.start), [40], "the bridge is still a gap from its start")
        // One that repeats is in the row for its repeats, and only for them.
        let notes = try XCTUnwrap(bridge.rows[0].lanes.first { $0.layer == .notes })
        XCTAssertEqual(notes.placements, [])
        XCTAssertEqual(notes.bands.count, 1)
    }

    func testOnlyACountedPieceCanBeCopied() {
        let empty = UUID(), counted = UUID()
        let map = build(markers: fiveSections(),
                        loops: [loop(8, 16, uid: empty), loop(24, 32, piece: changes(from: 24), uid: counted)])
        XCTAssertEqual(map.pieces[empty]?.canCopy, false)
        XCTAssertEqual(map.pieces[counted]?.canCopy, true)
    }
}
