import XCTest
@testable import Pocket

/// Pure slot-timing math for the strumming content template (ADR 0065 T4/T5). This is the
/// SwiftUI-free core the lane renderer only skins — so it is exhaustively unit-tested per
/// AGENTS.md ("which slot is active at time t" is pure logic that breaks silently otherwise).
final class StrumPatternTests: XCTestCase {

    // MARK: - Geometry

    func testSlotsPerBeatClampsToAtLeastOne() {
        XCTAssertEqual(StrumPattern(slotsPerBeat: 0, slots: [.down]).slotsPerBeat, 1)
        XCTAssertEqual(StrumPattern(slotsPerBeat: -3, slots: [.down]).slotsPerBeat, 1)
    }

    func testLengthInBeatsForEighthsPattern() {
        // Eight eighth-note slots = four beats (one 4/4 bar).
        XCTAssertEqual(StrumPattern.folk.lengthInBeats, 4, accuracy: 0.0001)
    }

    func testLengthInBeatsForQuarterPattern() {
        XCTAssertEqual(StrumPattern.downstrokes(beatsPerBar: 3).lengthInBeats, 3, accuracy: 0.0001)
    }

    func testLengthInBeatsIsZeroForEmptyPattern() {
        XCTAssertEqual(StrumPattern(slotsPerBeat: 2, slots: []).lengthInBeats, 0, accuracy: 0.0001)
    }

    func testBeatOffsetOfSlot() {
        let pattern = StrumPattern.folk   // eighths → each slot is half a beat apart
        XCTAssertEqual(pattern.beatOffset(ofSlot: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(pattern.beatOffset(ofSlot: 1), 0.5, accuracy: 0.0001)
        XCTAssertEqual(pattern.beatOffset(ofSlot: 4), 2.0, accuracy: 0.0001)
    }

    // MARK: - activeSlotIndex(atBeat:)

    func testActiveSlotAtBeatStartsAtZero() {
        XCTAssertEqual(StrumPattern.folk.activeSlotIndex(atBeat: 0), 0)
    }

    func testActiveSlotAdvancesWithinABeatForEighths() {
        // Two eighth slots per beat: [0, 0.5) → slot 0, [0.5, 1) → slot 1.
        let pattern = StrumPattern.folk
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 0.0), 0)
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 0.49), 0)
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 0.5), 1)
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 0.99), 1)
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 1.0), 2)
    }

    func testActiveSlotForQuartersIsOnePerBeat() {
        let pattern = StrumPattern.downstrokes(beatsPerBar: 4)   // slotsPerBeat 1
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 0.0), 0)
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 0.9), 0)
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 1.0), 1)
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 3.0), 3)
    }

    func testActiveSlotWrapsAtCycleLength() {
        // An eight-slot eighths pattern wraps every four beats.
        let pattern = StrumPattern.folk
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 4.0), 0)   // start of next cycle
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 4.5), 1)
        XCTAssertEqual(pattern.activeSlotIndex(atBeat: 8.0), 0)
    }

    func testActiveSlotIsNilBeforeBeatZero() {
        // The count-in runs at negative positions — nothing lit until the drill engages.
        XCTAssertNil(StrumPattern.folk.activeSlotIndex(atBeat: -0.1))
        XCTAssertNil(StrumPattern.folk.activeSlotIndex(atBeat: -1.0))
    }

    func testActiveSlotIsNilForEmptyPattern() {
        XCTAssertNil(StrumPattern(slotsPerBeat: 2, slots: []).activeSlotIndex(atBeat: 1.0))
    }

    func testActiveSlotIsNilForNonFinitePosition() {
        XCTAssertNil(StrumPattern.folk.activeSlotIndex(atBeat: .infinity))
        XCTAssertNil(StrumPattern.folk.activeSlotIndex(atBeat: .nan))
    }

    // MARK: - slot(at:)

    func testSlotAtWrapsForAnyIndex() {
        let pattern = StrumPattern.folk   // [D, rest, D, U, rest, U, D, U]
        XCTAssertEqual(pattern.slot(at: 0), .down)
        XCTAssertEqual(pattern.slot(at: 1), .rest)
        XCTAssertEqual(pattern.slot(at: 8), .down)   // wraps to 0
        XCTAssertEqual(pattern.slot(at: -1), .up)    // wraps to 7
    }

    func testSlotAtIsNilForEmptyPattern() {
        XCTAssertNil(StrumPattern(slotsPerBeat: 2, slots: []).slot(at: 0))
    }

    // MARK: - Presets

    func testFolkPatternIsTheClassicDDUUDU() {
        XCTAssertEqual(StrumPattern.folk.slots,
                       [.down, .rest, .down, .up, .rest, .up, .down, .up])
        XCTAssertEqual(StrumPattern.folk.slotsPerBeat, 2)
    }

    func testDownstrokesIsOneDownPerBeat() {
        let pattern = StrumPattern.downstrokes(beatsPerBar: 4)
        XCTAssertEqual(pattern.slots, [.down, .down, .down, .down])
        XCTAssertEqual(pattern.slotsPerBeat, 1)
    }

    func testStrumSlotStrokeClassification() {
        XCTAssertTrue(StrumSlot.down.isStroke)
        XCTAssertTrue(StrumSlot.up.isStroke)
        XCTAssertFalse(StrumSlot.rest.isStroke)
    }

    // MARK: - Editing (pure ops the authoring editor skins)

    func testStrumSlotCyclesDownUpRest() {
        XCTAssertEqual(StrumSlot.down.next, .up)
        XCTAssertEqual(StrumSlot.up.next, .rest)
        XCTAssertEqual(StrumSlot.rest.next, .down)
    }

    func testCyclingSlotAdvancesOnlyThatSlot() {
        let pattern = StrumPattern.downstrokes(beatsPerBar: 4)   // [D, D, D, D]
        let cycled = pattern.cyclingSlot(at: 1)
        XCTAssertEqual(cycled.slots, [.down, .up, .down, .down])
        XCTAssertEqual(cycled.slotsPerBeat, pattern.slotsPerBeat)
    }

    func testCyclingSlotOutOfRangeIsUnchanged() {
        let pattern = StrumPattern.downstrokes(beatsPerBar: 4)
        XCTAssertEqual(pattern.cyclingSlot(at: 99), pattern)
        XCTAssertEqual(pattern.cyclingSlot(at: -1), pattern)
    }

    func testResizedToFinerResolutionKeepsStrokesOnTheirBeats() {
        // Quarters [D, D, D, D] → eighths over 4 beats = 8 slots. Each downstroke stays *on its
        // beat* (offsets 0,1,2,3), the new "and" positions between them are rests — not crammed
        // into the first half of the bar (the old index-copy bug).
        let quarters = StrumPattern.downstrokes(beatsPerBar: 4)
        let eighths = quarters.resized(slotsPerBeat: 2, beatsPerBar: 4)
        XCTAssertEqual(eighths.slotsPerBeat, 2)
        XCTAssertEqual(eighths.slots,
                       [.down, .rest, .down, .rest, .down, .rest, .down, .rest])
    }

    func testResizedToCoarserResolutionKeepsOnBeatArticulations() {
        // Folk eighths (8 slots) → quarters over 4 beats = 4 slots, keeping the articulation on
        // each downbeat (offsets 0,1,2,3 → old indices 0,2,4,6), not the first four by index.
        let quarters = StrumPattern.folk.resized(slotsPerBeat: 1, beatsPerBar: 4)
        XCTAssertEqual(quarters.slotsPerBeat, 1)
        XCTAssertEqual(quarters.slots, [.down, .down, .rest, .down])
    }

    func testResizingCoarserThenFinerDoesNotWipeTheBar() {
        // The reported bug: eighths → quarters → eighths used to delete the second half of the
        // pattern. Beat-offset remapping preserves the on-beat strokes across the round trip (the
        // sub-beat "and" strokes are inherently lost to the coarser grid, but the bar isn't wiped).
        let roundTrip = StrumPattern.folk
            .resized(slotsPerBeat: 1, beatsPerBar: 4)   // → quarters
            .resized(slotsPerBeat: 2, beatsPerBar: 4)   // → eighths again
        XCTAssertEqual(roundTrip.slotsPerBeat, 2)
        // Downbeat strokes survive at their beats; the "ands" are rests, not a truncated tail.
        XCTAssertEqual(roundTrip.slots,
                       [.down, .rest, .down, .rest, .rest, .rest, .down, .rest])
    }

    func testResizedClampsSlotsPerBeatToAtLeastOne() {
        let resized = StrumPattern.folk.resized(slotsPerBeat: 0, beatsPerBar: 3)
        XCTAssertEqual(resized.slotsPerBeat, 1)
        XCTAssertEqual(resized.slots.count, 3)
    }

    // MARK: - Codable round-trip + versioning (T4)

    func testPatternRoundTripsThroughCodable() throws {
        let original = StrumPattern.folk
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StrumPattern.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testNewPatternCarriesCurrentVersion() {
        XCTAssertEqual(StrumPattern.folk.version, StrumPattern.currentVersion)
    }

    /// A blob written by a newer build (higher version) still decodes best-effort — the
    /// version field rides along so a future decode-time upgrade can act on it (T4).
    func testDecodesPayloadFromANewerVersion() throws {
        let future = StrumPattern(slotsPerBeat: 4,
                                  slots: [.down, .up, .down, .up],
                                  version: StrumPattern.currentVersion + 1)
        let data = try JSONEncoder().encode(future)
        let decoded = try JSONDecoder().decode(StrumPattern.self, from: data)
        XCTAssertEqual(decoded.version, StrumPattern.currentVersion + 1)
        XCTAssertEqual(decoded.slots, [.down, .up, .down, .up])
    }
}
