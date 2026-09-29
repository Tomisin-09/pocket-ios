import XCTest
@testable import Pocket

/// The fixtures the song map's slice 3 tests share (ADR 0232): a grid, markers and loops as plain values.
/// No tests of its own; the two classes below are split only to keep each one readable.
class SongMapSlice3Case: XCTestCase {

    /// 120 BPM in 4/4: a bar every 2 s, the first downbeat at 0.
    func grid(duration: TimeInterval = 64) -> SongMapInput.Grid {
        SongMapInput.Grid(downbeats: Array(stride(from: 0, to: duration, by: 2)), barSeconds: 2)
    }

    func marker(_ seconds: TimeInterval, _ label: String, section: Bool = true, uid: UUID = UUID(),
                sameAs: UUID? = nil) -> SongMapInput.MarkerInput {
        .init(uid: uid, seconds: seconds, label: label, startsSection: section, sameAsUID: sameAs)
    }

    func loop(_ start: TimeInterval, _ end: TimeInterval, type: LoopType = .chords,
              piece: PieceTranscription? = nil, repeats: Bool = false, to reach: SongMap.RepeatsTo = .sectionEnd,
              name: String = "Changes", uid: UUID = UUID()) -> SongMapInput.LoopInput {
        .init(uid: uid, name: name, start: start, end: end, type: type, piece: piece, handTagged: false,
              repeatsToSectionEnd: repeats, repeatsTo: reach)
    }

    func build(duration: TimeInterval = 64, grid: SongMapInput.Grid? = nil,
               markers: [SongMapInput.MarkerInput] = [],
               loops: [SongMapInput.LoopInput] = []) -> SongMap {
        SongMapLayout.build(SongMapInput(duration: duration, grid: grid, markers: markers, loops: loops))
    }

    /// Verse 8–40, Chorus 40–64, with a *Start* before the verse.
    func verseAndChorus() -> [SongMapInput.MarkerInput] {
        [marker(8, "Verse"), marker(40, "Chorus")]
    }

    func section(_ map: SongMap, _ label: String) throws -> SongMap.Section {
        try XCTUnwrap(map.sections.first {
            if case .marker(_, let name) = $0.heading { return name == label }
            return false
        })
    }

    func chordsGaps(_ section: SongMap.Section) -> [SongMap.Gap] {
        var gaps: [SongMap.Gap] = []
        for row in section.rows {
            for gap in row.lanes.first(where: { $0.layer == .chords && $0.index == 0 })?.gaps ?? []
            where !gaps.contains(gap) { gaps.append(gap) }
        }
        return gaps
    }

    let standard = [64, 59, 55, 50, 45, 40]
}

/// A loop that repeats to the end of its section (ADR 0232 D14), and a section that reads *as* an earlier
/// one (D8). Pure arithmetic over plain values, the kind that breaks silently (AGENTS.md).
final class SongMapSectionsTests: SongMapSlice3Case {

    // MARK: - Repeats (D14)

    func testARepeatRunsFromTheLoopsEndToItsSectionsEnd() throws {
        let uid = UUID()
        let map = build(grid: grid(), markers: verseAndChorus(), loops: [loop(8, 16, repeats: true, uid: uid)])
        XCTAssertEqual(map.pieces[uid]?.repeats, SongMap.Repeat(end: 40, passes: 4))
        let rows = try section(map, "Verse").rows
        XCTAssertEqual(rows.map(\.start), [8, 24])
        let first = try XCTUnwrap(rows[0].lanes.first { $0.layer == .chords })
        XCTAssertEqual(first.placements.map(\.end), [16], "the piece itself stops where it stops")
        XCTAssertEqual(first.bands, [SongMap.Band(uid: uid, start: 16, end: 24, continuesBefore: false,
                                                  continuesAfter: true, passes: 4)])
        let second = try XCTUnwrap(rows[1].lanes.first { $0.layer == .chords })
        XCTAssertTrue(second.placements.isEmpty, "no copies of the piece")
        XCTAssertEqual(second.bands, [SongMap.Band(uid: uid, start: 24, end: 40, continuesBefore: true,
                                                   continuesAfter: false, passes: 4)])
    }

    func testWithoutSectionsARepeatRunsToTheSongsEnd() {
        let uid = UUID()
        let map = build(loops: [loop(0, 8, repeats: true, uid: uid)])
        XCTAssertFalse(map.hasSections)
        XCTAssertEqual(map.pieces[uid]?.repeats, SongMap.Repeat(end: 64, passes: 8))
    }

    func testARepeatStopsAtTheSectionEvenWhenTheSongGoesOn() {
        let uid = UUID()
        let map = build(markers: verseAndChorus(), loops: [loop(8, 16, repeats: true, uid: uid)])
        XCTAssertEqual(map.pieces[uid]?.repeats?.end, 40, "not the song's end at 64")
    }

    func testTheCountIsToTheNearestWholePassAndTheBandStillRunsToTheEnd() {
        let uid = UUID()
        let map = build(markers: verseAndChorus(), loops: [loop(8, 14, repeats: true, uid: uid)])
        XCTAssertEqual(map.pieces[uid]?.repeats, SongMap.Repeat(end: 40, passes: 5), "32 s over 6 s is 5.33")
    }

    func testHalfAPassOfRoomIsEnoughAndLessIsNot() throws {
        let enough = UUID(), tooLittle = UUID()
        let map = build(markers: verseAndChorus(), loops: [loop(8, 24, repeats: true, uid: enough)])
        XCTAssertEqual(map.pieces[enough]?.repeats, SongMap.Repeat(end: 40, passes: 2))
        let tight = build(markers: verseAndChorus(), loops: [loop(8, 38, repeats: true, uid: tooLittle)])
        let piece = tight.pieces[tooLittle]
        XCTAssertNil(piece?.repeats, "2 s of room after a 30 s loop is nothing to draw")
        XCTAssertEqual(piece?.repeatsDeclared, true, "the switch stays on, so it can be switched off")
        XCTAssertEqual(try tight.repeatChoices(for: XCTUnwrap(piece)).map(\.to), [.songEnd],
                       "no room in its section, but 24 s more in the song")
    }

    func testALoopNotDeclaredToRepeatDoesntButCanBeOffered() throws {
        let uid = UUID()
        let map = build(markers: verseAndChorus(), loops: [loop(8, 16, uid: uid)])
        XCTAssertNil(map.pieces[uid]?.repeats)
        XCTAssertEqual(try map.repeatChoices(for: XCTUnwrap(map.pieces[uid])).first,
                       SongMap.RepeatChoice(to: .sectionEnd, title: "To the end of the section", passes: 4))
        XCTAssertEqual(map.pieces[uid]?.sectionEnd, 40)
    }

    func testALoopBelongsToTheSectionHoldingItsMiddle() {
        let uid = UUID()
        // Starts half a second before the verse, as a loop dragged by hand often does.
        let map = build(markers: verseAndChorus(), loops: [loop(7.5, 15.5, repeats: true, uid: uid)])
        XCTAssertEqual(map.pieces[uid]?.sectionEnd, 40, "the verse's, not the Start's")
        XCTAssertEqual(map.pieces[uid]?.repeats?.end, 40)
    }

    func testRepeatsHoldTheirLaneSoAPieceLaterInTheSectionTakesTheNext() {
        let vamp = UUID(), turnaround = UUID()
        let repeating = build(markers: verseAndChorus(),
                              loops: [loop(8, 16, repeats: true, uid: vamp), loop(32, 40, uid: turnaround)])
        XCTAssertEqual(repeating.pieces[vamp]?.lane, 0)
        XCTAssertEqual(repeating.pieces[turnaround]?.lane, 1, "drawn under the repeats, not over them")
        let plain = build(markers: verseAndChorus(), loops: [loop(8, 16, uid: vamp), loop(32, 40, uid: turnaround)])
        XCTAssertEqual(plain.pieces[turnaround]?.lane, 0)
    }

    func testRepeatsHoldOnlyTheirOwnLayer() {
        let vamp = UUID(), lick = UUID()
        let map = build(markers: verseAndChorus(),
                        loops: [loop(8, 16, repeats: true, uid: vamp), loop(24, 28, type: .lick, uid: lick)])
        XCTAssertEqual(map.pieces[lick]?.lane, 0)
    }

    // MARK: - Same as (D8)

    func testASectionReadsAsTheEarlierOneItNames() throws {
        let first = UUID()
        let map = build(markers: [marker(8, "Verse 1", uid: first), marker(24, "Chorus"),
                                  marker(40, "Verse 2", sameAs: first)])
        XCTAssertEqual(try section(map, "Verse 2").sameAs, SongMap.SectionRef(uid: first, label: "Verse 1", start: 8))
        XCTAssertNil(try section(map, "Verse 1").sameAs)
        XCTAssertNil(try section(map, "Chorus").sameAs)
    }

    func testAChainReadsAsTheFirst() throws {
        let one = UUID(), two = UUID()
        let map = build(markers: [marker(8, "Verse 1", uid: one), marker(24, "Verse 2", uid: two, sameAs: one),
                                  marker(40, "Verse 3", sameAs: two)])
        XCTAssertEqual(try section(map, "Verse 3").sameAs?.uid, one)
        XCTAssertEqual(try section(map, "Verse 2").sameAs?.uid, one)
    }

    func testOnlyAnEarlierSectionCounts() throws {
        let later = UUID(), pin = UUID()
        let map = build(markers: [marker(8, "Verse 1", sameAs: later), marker(40, "Verse 2", uid: later),
                                  marker(20, "Bend", section: false, uid: pin), marker(48, "Verse 3", sameAs: pin),
                                  marker(56, "Outro", sameAs: UUID())])
        XCTAssertNil(try section(map, "Verse 1").sameAs, "a later section can't be named")
        XCTAssertNil(try section(map, "Verse 3").sameAs, "a pin isn't a section")
        XCTAssertNil(try section(map, "Outro").sameAs, "a marker that's gone reads plain")
    }

    func testAChainBrokenPartWayReadsAsTheLastGoodLink() throws {
        let two = UUID()
        let map = build(markers: [marker(8, "Verse 1"), marker(24, "Verse 2", uid: two, sameAs: UUID()),
                                  marker(40, "Verse 3", sameAs: two)])
        XCTAssertEqual(try section(map, "Verse 3").sameAs?.uid, two)
    }

    func testTheNamedSectionIsFoundWhereItsDrawn() throws {
        let intro = UUID()
        let map = build(markers: [marker(0.4, "Intro", uid: intro), marker(40, "Outro", sameAs: intro)])
        XCTAssertEqual(try section(map, "Outro").sameAs?.start, 0, "the intro's short lead is folded into it")
    }

    func testAMarkerThatIsNotASectionIgnoresItsSameAs() {
        let first = UUID()
        let map = build(markers: [marker(8, "Verse 1", uid: first),
                                  marker(40, "Verse 2", section: false, sameAs: first)])
        XCTAssertEqual(map.sections.compactMap(\.sameAs), [])
    }
}

/// The gaps *Make a piece here* fills (ADR 0232 D9), which marker labels *Use your markers as sections?*
/// ticks (D7), and how the Tab view writes a repeat and a "same as" section (D8, D14).
final class SongMapGapsTests: SongMapSlice3Case {

    // MARK: - Gaps (D9)

    func testAGapRunsFromTheNeighbourBeforeToTheNeighbourAfter() throws {
        let map = build(grid: grid(), markers: verseAndChorus(), loops: [loop(8, 16), loop(28, 40)])
        XCTAssertEqual(chordsGaps(try section(map, "Verse")),
                       [SongMap.Gap(layer: .chords, start: 16, end: 28, name: "Verse chords")])
        let notes = try section(map, "Verse").rows[0].lanes.first { $0.layer == .notes }?.gaps
        XCTAssertEqual(notes, [SongMap.Gap(layer: .notes, start: 8, end: 40, name: "Verse notes")],
                       "the whole section, with nothing on it, is one gap")
    }

    func testAGapCrossingRowsIsTheSameGapInEach() throws {
        let rows = try section(build(grid: grid(), markers: verseAndChorus()), "Verse").rows
        let gaps = rows.map { $0.lanes.first { $0.layer == .chords }?.gaps.first }
        XCTAssertEqual(gaps.count, 2)
        XCTAssertEqual(gaps[0], gaps[1])
        XCTAssertEqual(gaps[0]?.start, 8)
        XCTAssertEqual(gaps[0]?.end, 40)
    }

    func testAGapIsBoundedByItsSection() {
        let map = build(grid: grid(), markers: verseAndChorus())
        let gaps = map.sections.flatMap { chordsGaps($0) }
        XCTAssertEqual(gaps.map(\.start), [0, 8, 40])
        XCTAssertEqual(gaps.map(\.end), [8, 40, 64])
        XCTAssertEqual(gaps.map(\.name), ["Chords, bars 1–4", "Verse chords", "Chorus chords"],
                       "the stretch before the first section is named by where it is")
    }

    func testWithoutSectionsAGapIsBoundedByItsRow() {
        let map = build(grid: grid(), loops: [loop(4, 6)])
        let gaps = chordsGaps(map.sections[0])
        XCTAssertEqual(gaps.map(\.start), [0, 6, 16, 32, 48])
        XCTAssertEqual(gaps.map(\.end), [4, 16, 32, 48, 64])
        XCTAssertEqual(gaps.prefix(3).map(\.name), ["Chords, bars 1–2", "Chords, bars 4–8", "Chords, bars 9–16"])
    }

    func testWithoutAGridAGapIsNamedByItsTimes() {
        let map = build(duration: 20)
        XCTAssertEqual(chordsGaps(map.sections[0]).map(\.name), ["Chords, 0:00–0:16", "Chords, 0:16–0:20"])
    }

    func testAnUnnamedSectionIsNamedByWhereItIs() {
        let map = build(grid: grid(), markers: [marker(8, " ")])
        XCTAssertEqual(chordsGaps(map.sections[1]).first?.name, "Chords, bars 5–32")
    }

    func testASliverIsNotAGap() {
        let map = build(markers: verseAndChorus(), loops: [loop(8, 15.5), loop(16, 40)])
        XCTAssertEqual(chordsGaps(map.sections[1]), [], "half a second between two loops is nothing to fill")
    }

    func testRepeatsLeaveNoGap() {
        let map = build(markers: verseAndChorus(), loops: [loop(8, 16, repeats: true)])
        XCTAssertEqual(chordsGaps(map.sections[1]), [])
    }

    func testGapsSitOnTheLayersFirstLaneOnly() throws {
        let map = build(markers: verseAndChorus(), loops: [loop(8, 16), loop(12, 20)])
        let lanes = try section(map, "Verse").rows[0].lanes.filter { $0.layer == .chords }
        XCTAssertEqual(lanes.count, 2)
        XCTAssertEqual(lanes[0].gaps.map(\.start), [20])
        XCTAssertEqual(lanes[1].gaps, [])
    }

    func testAMadePieceTakesAnUnusedName() {
        XCTAssertEqual(SongMapLayout.unusedName("Verse chords", among: []), "Verse chords")
        XCTAssertEqual(SongMapLayout.unusedName("Verse chords", among: ["Verse chords"]), "Verse chords 2")
        XCTAssertEqual(SongMapLayout.unusedName("Verse chords", among: ["Verse chords", "Verse chords 2"]),
                       "Verse chords 3")
    }

    // MARK: - Use your markers as sections? (D7)

    func testSectionWordsAreRecognisedWhole() {
        for label in ["Intro", "Verse 2", "verse2", "Chorus x2", "Pre-chorus", "pre chorus", "PRECHORUS",
                      "Guitar solo", "Bridge", "Break", "Outro"] {
            XCTAssertTrue(SectionWords.readsAsSection(label), label)
        }
        for label in ["Tricky bend", "Breakdown", "Versed", "M3", ""] {
            XCTAssertFalse(SectionWords.readsAsSection(label), label)
        }
    }

    func testSuggestionsAreEveryMarkerInTheSongWithSectionWordsTicked() {
        let suggestions = SectionWords.suggestions([marker(30, "Chorus", section: false), marker(-1, "Before"),
                                                    marker(10, "Bend", section: false), marker(64, "At the end")],
                                                   duration: 64)
        XCTAssertEqual(suggestions.map(\.marker.label), ["Bend", "Chorus"])
        XCTAssertEqual(suggestions.map(\.ticked), [false, true])
    }

    func testTheOfferIsForMarkersWithNoSectionsYet() {
        XCTAssertFalse(SectionWords.shouldOffer([], duration: 64), "no markers, nothing to use")
        XCTAssertTrue(SectionWords.shouldOffer([marker(8, "Verse", section: false)], duration: 64))
        XCTAssertFalse(SectionWords.shouldOffer([marker(8, "Verse"), marker(20, "M2", section: false)], duration: 64),
                       "a song with a section has already been split")
        XCTAssertFalse(SectionWords.shouldOffer([marker(90, "After", section: false)], duration: 64))
    }

    func testTheOfferIsRecordedOncePerSong() throws {
        let store = try XCTUnwrap(UserDefaults(suiteName: "SongMapSectionsTests"))
        store.removePersistentDomain(forName: "SongMapSectionsTests")
        XCTAssertFalse(AppSettings.sectionOfferMade(for: "song-1", store: store))
        AppSettings.recordSectionOffer(for: "song-1", store: store)
        AppSettings.recordSectionOffer(for: "song-1", store: store)
        XCTAssertTrue(AppSettings.sectionOfferMade(for: "song-1", store: store))
        XCTAssertFalse(AppSettings.sectionOfferMade(for: "song-2", store: store))
        XCTAssertEqual(store.stringArray(forKey: AppSettings.Key.songMapSectionOffers), ["song-1"])
        store.removePersistentDomain(forName: "SongMapSectionsTests")
    }

    // MARK: - The Tab view (D8, D14)

    private func tab(markers: [SongMapInput.MarkerInput], loops: [SongMapInput.LoopInput]) -> SongTab {
        SongTabLayout.build(build(grid: grid(), markers: markers, loops: loops), spelling: .flats)
    }

    func testTheTabWritesARepeatedLoopOnceAndLabelsWhereItRepeats() throws {
        let uid = UUID()
        let changes = PieceTranscription(taps: [.init(seconds: 8, label: .chord(root: 7, suffix: "m7")),
                                                .init(seconds: 10, label: .chord(root: 0, suffix: "7"))])
        let sections = tab(markers: verseAndChorus(), loops: [loop(8, 12, piece: changes, repeats: true, uid: uid)])
            .sections
        let rows = try XCTUnwrap(sections.first { $0.start == 8 }).rows
        XCTAssertEqual(rows.map(\.start), [8, 16, 24, 32])
        XCTAssertEqual(rows[0].lines.first?.columns.map(\.name), ["Gm7", "C7"])
        let first = SongTab.RepeatMark(piece: uid, name: "Changes", start: 12, end: 16, passes: 8, continues: false)
        XCTAssertEqual(rows[0].lines.first?.repeats, [first])
        XCTAssertEqual(rows[1].lines.first?.columns, [], "never the taps again")
        XCTAssertEqual(rows[1].lines.first?.repeats.map(\.continues), [true])
        XCTAssertEqual(rows[3].pieces, [uid], "a row of repeats goes back to the piece")
        XCTAssertFalse(sections.first { $0.start == 40 }?.rows.contains { !$0.lines.isEmpty } ?? true,
                       "the chorus is a new section, so the repeats stop")
    }

    func testARepeatedTabLineCarriesItsLabelAboveTheStrings() throws {
        let riff = PieceTranscription(taps: [.init(seconds: 8.5, label: .fretted(string: 1, fret: 5))],
                                      openMidi: standard)
        let line = try XCTUnwrap(tab(markers: verseAndChorus(), loops: [loop(8, 12, type: .riff, piece: riff,
                                                                              repeats: true)])
            .sections.first { $0.start == 8 }?.rows[0].lines.first)
        XCTAssertTrue(line.isTab)
        XCTAssertTrue(line.hasWordsAboveTab)
    }

    func testASameAsSectionWithNothingOfItsOwnIsWrittenAsItsHeadingAlone() {
        let first = UUID()
        let markers = [marker(8, "Verse 1", uid: first), marker(40, "Verse 2", sameAs: first)]
        let bare = tab(markers: markers, loops: [])
        XCTAssertEqual(bare.sections.map(\.showsRows), [true, true, false],
                       "Start and Verse 1 draw their rows, empty or not; Verse 2 is written as Verse 1")
        let counted = PieceTranscription(taps: [.init(seconds: 57)])
        let varied = tab(markers: markers, loops: [loop(56, 60, piece: counted)])
        XCTAssertEqual(varied.sections.last?.showsRows, true, "a variation beats same as")
    }
}
