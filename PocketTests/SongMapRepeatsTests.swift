import XCTest
@testable import Pocket

/// **A loop's repeats keep to the bar** (ADR 0315), with *Sunday Morning*'s own numbers: 88.25 BPM in 4/4,
/// and the intro's *Chords* drawn 10.837 s long where its four bars are 10.878 s. Stepped by the length as
/// drawn, each pass came 41 ms early, a beat out by the Solo. Stepped by whole bars, the last pass lands
/// on its bar line, in the map's count, the Tab view and what Watch lights.
final class SongMapRepeatsTests: XCTestCase {

    /// A bar at 88.25 BPM in 4/4.
    private let bar = 4 * 60 / 88.25
    /// The first downbeat, a little into the record.
    private let one: TimeInterval = 0.6
    private let duration: TimeInterval = 240
    /// *Chords* as Tomisin drew it: from the 1, 10.837 s long.
    private var chordsStart: TimeInterval { one }
    private var chordsEnd: TimeInterval { one + 10.837 }

    private var grid: SongMapInput.Grid {
        SongMapInput.Grid(downbeats: Array(stride(from: one, to: duration, by: bar)), barSeconds: bar)
    }

    // MARK: - The steps

    func testAPassIsTheLoopsLengthToTheNearestWholeBar() {
        XCTAssertEqual(SongMapRepeats.period(from: chordsStart, to: chordsEnd, grid: grid), 4 * bar, accuracy: 1e-9)
        XCTAssertEqual(SongMapRepeats.period(from: chordsStart, to: chordsEnd, grid: nil), 10.837, accuracy: 1e-9,
                       "without bars, a pass is the loop as drawn")
    }

    func testTheTwentiethPassStartsOnItsBarLine() {
        let twentieth = SongMapRepeats.time(of: chordsStart, pass: 20, from: chordsStart, to: chordsEnd, grid: grid)
        XCTAssertEqual(twentieth, one + 80 * bar, accuracy: 0.001, "the 1 of bar 81")
        let asDrawn = SongMapRepeats.time(of: chordsStart, pass: 20, from: chordsStart, to: chordsEnd, grid: nil)
        XCTAssertEqual(one + 80 * bar - asDrawn, 20 * (4 * bar - 10.837), accuracy: 0.001,
                       "as drawn it's 41 ms early a pass: what Tomisin heard")
        XCTAssertGreaterThan(one + 80 * bar - asDrawn, 0.68, "more than a beat out")
    }

    func testATapKeepsItsPlaceInTheBar() {
        let beatTwoOfBarTwo = one + bar + bar / 4
        let later = SongMapRepeats.time(of: beatTwoOfBarTwo, pass: 7, from: chordsStart, to: chordsEnd, grid: grid)
        XCTAssertEqual(SongMapBars.place(of: later, in: grid), 1.25 + 28, accuracy: 1e-6)
    }

    func testOnABeatMapAPassFollowsTheBarsAsPlayed() {
        // Bars that slow down: each a little longer than the last.
        var downbeats: [TimeInterval] = [0]
        for index in 0..<40 { downbeats.append(downbeats[index] + 2 + Double(index) * 0.01) }
        let beatMap = SongMapInput.Grid(downbeats: downbeats, barSeconds: 2)
        let pass = SongMapRepeats.time(of: 0, pass: 5, from: 0, to: 7.9, grid: beatMap)
        XCTAssertEqual(pass, downbeats[20], accuracy: 1e-9, "four bars a pass, the 1 of bar 21 as it was played")
        XCTAssertEqual(SongMapRepeats.passes(from: 0, to: 7.9, reach: downbeats[40], grid: beatMap), 10,
                       "counted in bars, not seconds")
    }

    func testTheCountIsInWholeBarPasses() {
        let reach = one + 64 * bar
        XCTAssertEqual(SongMapRepeats.passes(from: chordsStart, to: chordsEnd, reach: reach, grid: grid), 16)
        XCTAssertEqual(SongMapRepeats.passes(from: chordsStart, to: chordsEnd, reach: 40, grid: nil), 4,
                       "without bars, as before: 39.4 s over 10.837 s")
    }

    func testOnlyOnePassWorthOfTapsRepeats() {
        // Drawn a hair over four bars, with the next 1 counted in that hair.
        let start = one, end = one + 4.04 * bar
        XCTAssertTrue(SongMapRepeats.repeats(one + 3.9 * bar, from: start, to: end, grid: grid))
        XCTAssertFalse(SongMapRepeats.repeats(one + 4.01 * bar, from: start, to: end, grid: grid),
                       "the next pass's 1, counted early: the pass already plays it")
        XCTAssertTrue(SongMapRepeats.repeats(one + 4.01 * bar, from: start, to: end, grid: nil),
                      "without bars, every tap in the loop repeats")
    }

    // MARK: - Where it shows

    /// The intro's chords, a change on every bar, repeating to the end of a song with no sections.
    private func sundayMorning() -> (map: SongMap, uid: UUID) {
        let uid = UUID()
        var changes: [PieceTranscription.Tap] = []
        for index in 0..<4 {
            let seconds: TimeInterval = one + Double(index) * bar + 0.01
            let label = PieceLabel.fretted([FrettedNote(string: 5, fret: 3 + index)], into: nil)
            changes.append(PieceTranscription.Tap(seconds: seconds, label: label))
        }
        let openMidi = Instrument.guitar.standardTuning.engineOpenMidi
        let piece = PieceTranscription(taps: changes, openMidi: openMidi)
        let loop = SongMapInput.LoopInput(uid: uid, name: "Chords", start: chordsStart, end: chordsEnd, type: .chords,
                                          piece: piece, handTagged: false, repeatsToSectionEnd: true,
                                          repeatsTo: .songEnd)
        let map = SongMapLayout.build(SongMapInput(duration: duration, grid: grid, markers: [], loops: [loop]))
        return (map, uid)
    }

    func testTheMapCountsWholeBarPasses() throws {
        let (map, uid) = sundayMorning()
        let repeats = try XCTUnwrap(map.pieces[uid]?.repeats)
        XCTAssertEqual(repeats.end, duration)
        XCTAssertEqual(repeats.passes, Int(((duration - one) / (4 * bar)).rounded()))
        // Drawn three and a half bars and a bit: it repeats every four, so 64 bars are 16 passes, not 18.
        let short = UUID()
        let loop = SongMapInput.LoopInput(uid: short, name: "Vamp", start: 0, end: 7.2, type: .chords, piece: nil,
                                          handTagged: false, repeatsToSectionEnd: true, repeatsTo: .songEnd)
        let even = SongMapInput.Grid(downbeats: Array(stride(from: 0, to: 128, by: 2)), barSeconds: 2)
        let vamp = SongMapLayout.build(SongMapInput(duration: 128, grid: even, markers: [], loops: [loop]))
        XCTAssertEqual(vamp.pieces[short]?.repeats?.passes, 16)
    }

    /// Drawn a hair over four 2 s bars, with the next pass's 1 counted in that hair (8.04 s).
    private func drawnLong() -> (map: SongMap, uid: UUID) {
        let uid = UUID()
        let one = PieceLabel.fretted([FrettedNote(string: 5, fret: 3)], into: nil)
        let next = PieceLabel.fretted([FrettedNote(string: 5, fret: 5)], into: nil)
        let piece = PieceTranscription(taps: [.init(seconds: 0.02, label: one), .init(seconds: 8.04, label: next)],
                                       openMidi: Instrument.guitar.standardTuning.engineOpenMidi)
        let loop = SongMapInput.LoopInput(uid: uid, name: "Chords", start: 0, end: 8.08, type: .chords, piece: piece,
                                          handTagged: false, repeatsToSectionEnd: true, repeatsTo: .songEnd)
        let even = SongMapInput.Grid(downbeats: Array(stride(from: 0, to: 40, by: 2)), barSeconds: 2)
        return (SongMapLayout.build(SongMapInput(duration: 40, grid: even, markers: [], loops: [loop])), uid)
    }

    func testALoopDrawnLongPlaysEachPassOnce() throws {
        let (map, _) = drawnLong()
        let tab = tabTimes(map)
        XCTAssertEqual(tab.count, 5, "\(tab)")
        for (time, expected) in zip(tab, [0.02, 8.04, 16.02, 24.02, 32.02]) {
            XCTAssertEqual(time, expected, accuracy: 1e-6, "the second pass's 1 isn't written over the loop's own")
        }
        let watch = SectionWatch.merge(SectionWatch.sources(of: map), from: 0, to: 40).taps.map(\.seconds)
        XCTAssertEqual(watch.count, 5, "\(watch)")
        for (time, expected) in zip(watch, [0.02, 8.04, 16.02, 24.02, 32.02]) {
            XCTAssertEqual(time, expected, accuracy: 1e-6)
        }
    }

    /// Every time the Tab view writes a tap, built as the app builds it, the repeat signs left out.
    private func tabTimes(_ map: SongMap) -> [TimeInterval] {
        SongTabLayout.build(map, spelling: .flats).sections.flatMap(\.rows).flatMap(\.lines).flatMap(\.columns)
            .filter { column in
                if case .repeats = column.mark { return false }
                return true
            }
            .map(\.time).sorted()
    }

    func testTheTabWritesTheLastPassOnItsBarLines() throws {
        let (map, _) = sundayMorning()
        let times = tabTimes(map)
        let last = try XCTUnwrap(times.last)
        let place = SongMapBars.place(of: last, in: grid)
        XCTAssertEqual(place - place.rounded(.down), 0.01 / bar, accuracy: 1e-6,
                       "the last change still sits just after its 1, not a beat early")
        XCTAssertGreaterThan(last, duration - 4 * bar, "it runs to the end of the song")
        XCTAssertEqual(Set(times).count, times.count, "no tap written twice")
    }

    func testWatchLightsTheLastPassOnItsBarLines() throws {
        let (map, _) = sundayMorning()
        let run = SectionWatch.merge(SectionWatch.sources(of: map), from: 0, to: duration)
        let last = try XCTUnwrap(run.taps.last)
        let place = SongMapBars.place(of: last.seconds, in: grid)
        XCTAssertEqual(place - place.rounded(.down), 0.01 / bar, accuracy: 1e-6)
        XCTAssertGreaterThan(last.seconds, duration - 4 * bar, "it runs to the end of the song")
    }

    func testWithoutBarsTheTabStepsAsDrawn() throws {
        let uid = UUID()
        let loop = SongMapInput.LoopInput(uid: uid, name: "Chords", start: 0, end: 10, type: .chords,
                                          piece: PieceTranscription(taps: [.init(seconds: 1, label: nil)]),
                                          handTagged: false, repeatsToSectionEnd: true, repeatsTo: .songEnd)
        let map = SongMapLayout.build(SongMapInput(duration: 40, grid: nil, markers: [], loops: [loop]))
        XCTAssertNotNil(map.pieces[uid]?.repeats)
        XCTAssertEqual(tabTimes(map), [1, 11, 21, 31])
    }
}
