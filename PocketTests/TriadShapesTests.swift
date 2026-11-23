import XCTest
@testable import Pocket

/// **The finder** (ADR 0313 D3): every close triad shape of a three-note chord on three adjacent strings,
/// and the nearest move from one chord to the next. Pure, so it is held over every key, string set and
/// range rather than a few hand-picked cases. The 5-fret table in the ADR is pinned here too, so if the
/// rules change the numbers get checked again.
final class TriadShapesTests: XCTestCase {

    private let triadQualities: [ChordGrip.Quality] = [.major, .minor, .diminished, .augmented, .sus2, .sus4]

    // MARK: - The picker and the exercise agree (D3)

    /// For every triad grip at every root, the finder finds that exact shape, in that inversion. So the
    /// chord picker's Triads section and the exercise can't disagree about what a shape is.
    func testEveryTriadGripAtEveryRootIsAShapeTheFinderFinds() throws {
        for grip in ChordGrip.triads {
            let set = try XCTUnwrap(TriadStrings.allCases.first { $0.label == grip.name }, grip.name)
            let intervals = try XCTUnwrap(grip.quality.triadIntervals)
            for root in 0..<12 {
                let voicing = grip.voicing(rootPitchClass: root)
                let frets = set.strings.compactMap { voicing.frets[$0] }
                XCTAssertEqual(frets.count, 3, "\(grip.name) \(grip.quality) has a fret on each string")
                let found = TriadShapes.all(root: root, intervals: intervals, on: set)
                XCTAssertTrue(found.contains { $0.frets == frets && $0.inversion == grip.inversion },
                              "\(voicing.name) \(grip.name) inv \(grip.inversion) at \(frets) wasn't found")
            }
        }
    }

    // MARK: - Every shape is a close triad of the chord

    func testEveryShapeIsTheChordCloseVoicedOnItsStrings() {
        for set in TriadStrings.allCases {
            for quality in triadQualities {
                let intervals = quality.triadIntervals ?? []
                for root in 0..<12 {
                    let shapes = TriadShapes.all(root: root, intervals: intervals, on: set)
                    XCTAssertFalse(shapes.isEmpty)
                    for shape in shapes {
                        let context = "\(root) \(quality) on \(set.label) at \(shape.frets)"
                        XCTAssertEqual(shape.strings, set.strings, context)
                        XCTAssertTrue(shape.frets.allSatisfy { (0...TriadShapes.maxFret).contains($0) }, context)
                        XCTAssertEqual(shape.pitches, shape.pitches.sorted(), context)
                        XCTAssertLessThan(shape.pitches[2] - shape.pitches[0], 12, "within an octave: \(context)")
                        let classes = shape.pitches.map { (($0 - root) % 12 + 12) % 12 }
                        XCTAssertEqual(Set(classes), Set(intervals), "every tone once: \(context)")
                        XCTAssertEqual(shape.tones.map { intervals[$0] }, classes, context)
                        XCTAssertEqual(Set(shape.tones), [0, 1, 2], context)
                    }
                    // Lowest first.
                    let order = shapes.map { ($0.lowestFret, $0.pitches[0]) }
                    XCTAssertTrue(zip(order, order.dropFirst()).allSatisfy { $0 <= $1 })
                }
            }
        }
    }

    /// All three inversions turn up for every chord, so *Climb in* always has something to climb in.
    func testEveryChordHasAllThreeInversions() {
        for set in TriadStrings.allCases {
            for quality in triadQualities {
                for root in 0..<12 {
                    let shapes = TriadShapes.all(root: root, intervals: quality.triadIntervals ?? [], on: set)
                    XCTAssertEqual(Set(shapes.map(\.inversion)), [0, 1, 2], "\(root) \(quality) \(set)")
                }
            }
        }
    }

    /// C major on G-B-e, as the teacher plays it up the neck: the open-position second inversion, then
    /// root position, first, and second again at the twelfth fret.
    func testCMajorOnTheTopThreeStrings() {
        let shapes = TriadShapes.all(root: 0, intervals: [0, 4, 7], on: .gbe, maxFret: 15)
        XCTAssertEqual(shapes.map(\.frets), [[0, 1, 0], [5, 5, 3], [9, 8, 8], [12, 13, 12]])
        XCTAssertEqual(shapes.map(\.inversion), [2, 0, 1, 2])
    }

    func testAPowerChordHasNoTriad() {
        XCTAssertNil(ChordGrip.Quality.fifth.triadIntervals)
        XCTAssertNil(ChordGrip.Quality.fifth.triadQuality)
    }

    /// A 7th, maj7, 6th or 9th plays its major or minor triad; sus and the other two triads play as written.
    func testBiggerChordsPlayTheirTriad() {
        XCTAssertEqual(ChordGrip.Quality.dom7.triadQuality, .major)
        XCTAssertEqual(ChordGrip.Quality.maj9.triadQuality, .major)
        XCTAssertEqual(ChordGrip.Quality.sixth.triadQuality, .major)
        XCTAssertEqual(ChordGrip.Quality.min7.triadQuality, .minor)
        XCTAssertEqual(ChordGrip.Quality.min9.triadQuality, .minor)
        XCTAssertEqual(ChordGrip.Quality.sus4.triadIntervals, [0, 5, 7])
        XCTAssertEqual(ChordGrip.Quality.sus2.triadIntervals, [0, 2, 7])
        XCTAssertEqual(ChordGrip.Quality.diminished.triadIntervals, [0, 3, 6])
        XCTAssertEqual(ChordGrip.Quality.augmented.triadIntervals, [0, 4, 8])
    }

    // MARK: - The nearest move (D3)

    func testTheNearestMoveIsTheSmallestAndATieGoesToTheLowerShape() {
        func shape(_ frets: [Int]) -> TriadShape {
            TriadShape(strings: [2, 1, 0], frets: frets, pitches: [0, 1, 2], tones: [0, 1, 2])
        }
        let from = shape([5, 5, 5])
        // [3,3,3] and [7,7,7] both cost 6, so the lower wins; [5,6,5] costs 1.
        XCTAssertEqual(TriadShapes.nearest(to: from, among: [shape([3, 3, 3]), shape([5, 6, 5]), shape([7, 7, 7])]),
                       shape([5, 6, 5]))
        XCTAssertEqual(TriadShapes.nearest(to: from, among: [shape([3, 3, 3]), shape([7, 7, 7])]), shape([3, 3, 3]))
        XCTAssertEqual(TriadShapes.nearest(to: nil, among: [shape([3, 3, 3]), shape([7, 7, 7])]), shape([3, 3, 3]),
                       "the first chord takes the lowest shape")
        XCTAssertNil(TriadShapes.nearest(to: from, among: []))
    }

    /// Over every range, the chosen shape costs no more than any other that fits.
    func testTheNearestMoveNeverCostsMoreThanAnotherShapeInTheRange() {
        for set in TriadStrings.allCases {
            let previous = TriadShapes.all(root: 0, intervals: [0, 4, 7], on: set)
            for root in 0..<12 {
                for low in 0...12 {
                    let candidates = TriadShapes.fitting(root: root, intervals: [0, 3, 7], on: set, in: low...(low + 5))
                    for before in previous {
                        guard let chosen = TriadShapes.nearest(to: before, among: candidates) else { continue }
                        let best = candidates.map { $0.moveCost(from: before) }.min()
                        XCTAssertEqual(chosen.moveCost(from: before), best)
                    }
                }
            }
        }
    }

    // MARK: - The 5-fret catch (ADR 0313 Context)

    /// Across the twelve major keys, the three string sets and start frets 1 to 12, five frets hold all
    /// seven chords in 168 of the 432 cases.
    func testFiveFretsHoldTheKeysSevenIn168Of432Cases() {
        var holds = 0, cases = 0
        for tonic in 0..<12 {
            for set in TriadStrings.allCases {
                let run = TriadRun(tonic: tonic, strings: set, source: .keysSeven)
                for start in 1...12 {
                    cases += 1
                    if run.holdsEveryChord(in: start...(start + 4)) { holds += 1 }
                }
            }
        }
        XCTAssertEqual(cases, 432)
        XCTAssertEqual(holds, 168)
    }

    /// The narrowest range that holds the key's seven somewhere in every key, and anywhere in every key.
    /// The B string's tuning is why the top two sets pack tighter.
    func testTheNarrowestRangeThatHoldsEveryKey() {
        let expected: [TriadStrings: (somewhere: Int, anywhere: Int)] = [
            .gbe: (5, 6), .dgb: (5, 6), .adg: (6, 7)
        ]
        for set in TriadStrings.allCases {
            let runs = (0..<12).map { TriadRun(tonic: $0, strings: set, source: .keysSeven) }
            func holdsSomewhere(_ width: Int) -> Bool {
                runs.allSatisfy { run in (1...12).contains { run.holdsEveryChord(in: $0...($0 + width - 1)) } }
            }
            func holdsAnywhere(_ width: Int) -> Bool {
                runs.allSatisfy { run in (1...12).allSatisfy { run.holdsEveryChord(in: $0...($0 + width - 1)) } }
            }
            XCTAssertEqual((3...10).first(where: holdsSomewhere), expected[set]?.somewhere, set.label)
            XCTAssertEqual((3...10).first(where: holdsAnywhere), expected[set]?.anywhere, set.label)
        }
    }
}
