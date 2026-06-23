import XCTest
@testable import Pocket

/// Pure logic on the SwiftData domain (ADR 0011). The `@Model` classes are
/// exercised as plain in-memory objects — no `ModelContext` needed to verify the
/// computed accessors, identity round-trip, and seed wiring.
final class SongTests: XCTestCase {

    private func makeSong(duration: TimeInterval = 100) -> Song {
        Song(title: "T", duration: duration,
             ref: SongRef(id: "x", source: .localFile, bookmark: nil))
    }

    // MARK: - SongRef round-trip (flattened to sourceID/sourceRaw/bookmark)

    func testRefRoundTripsThroughFlattenedStorage() {
        let ref = SongRef(id: "abc", source: .localFile, bookmark: Data([1, 2, 3]))
        let song = Song(title: "T", duration: 10, ref: ref)
        XCTAssertEqual(song.ref, ref)
        XCTAssertEqual(song.ref.bookmark, Data([1, 2, 3]))
    }

    func testRefFallsBackToLocalFileOnUnknownSourceRaw() {
        let song = makeSong()
        song.sourceRaw = "not-a-real-source"
        XCTAssertEqual(song.ref.source, .localFile)
    }

    // MARK: - Sorted display accessors

    func testLoopsByStartSortsByStartFraction() {
        let song = makeSong()
        song.loops = [
            Loop(name: "late", start: 0.8, end: 0.9, speed: 1, repeats: 1),
            Loop(name: "early", start: 0.1, end: 0.2, speed: 1, repeats: 1),
            Loop(name: "mid", start: 0.4, end: 0.5, speed: 1, repeats: 1)
        ]
        XCTAssertEqual(song.loopsByStart.map(\.name), ["early", "mid", "late"])
    }

    func testMarkersByTimeSortsBySeconds() {
        let song = makeSong()
        song.markers = [
            Marker(seconds: 30, label: "c"),
            Marker(seconds: 5, label: "a"),
            Marker(seconds: 12, label: "b")
        ]
        XCTAssertEqual(song.markersByTime.map(\.label), ["a", "b", "c"])
    }

    // MARK: - Fraction → seconds mapping

    func testLoopSecondsScaleBySongDuration() {
        let song = makeSong(duration: 200)
        let loop = Loop(name: "L", start: 0.25, end: 0.5, speed: 1, repeats: 1)
        loop.song = song
        XCTAssertEqual(loop.startSeconds, 50, accuracy: 0.0001)
        XCTAssertEqual(loop.endSeconds, 100, accuracy: 0.0001)
    }

    func testLoopSecondsAreZeroWithoutSong() {
        let loop = Loop(name: "L", start: 0.25, end: 0.5, speed: 1, repeats: 1)
        XCTAssertEqual(loop.startSeconds, 0)
        XCTAssertEqual(loop.endSeconds, 0)
    }

    // MARK: - Annotation stats

    func testAnnotationCountIsZeroWithoutLoopsOrMarkers() {
        XCTAssertEqual(makeSong().annotationCount, 0)
    }

    func testAnnotationCountSumsLoopsAndMarkers() {
        let song = makeSong()
        song.loops = [
            Loop(name: "a", start: 0.1, end: 0.2, speed: 1, repeats: 1),
            Loop(name: "b", start: 0.3, end: 0.4, speed: 1, repeats: 1)
        ]
        song.markers = [
            Marker(seconds: 5, label: "x"),
            Marker(seconds: 9, label: "y"),
            Marker(seconds: 12, label: "z")
        ]
        XCTAssertEqual(song.annotationCount, 5)
    }

    // MARK: - Loop automator accessor (ADR 0013)

    func testLoopAutomatorReflectsSpeedAndDefaults() {
        let loop = Loop(name: "L", start: 0.1, end: 0.2, speed: 0.8, repeats: 4)
        XCTAssertEqual(loop.automator.startSpeed, 0.8, accuracy: 1e-9, "start maps to loop.speed")
        XCTAssertFalse(loop.automator.enabled)
        XCTAssertEqual(loop.automator.stepCount, 6)
        XCTAssertEqual(loop.automator.loopsPerStep, 2)
    }

    func testLoopAutomatorSetterWritesThrough() {
        let loop = Loop(name: "L", start: 0.1, end: 0.2, speed: 0.8, repeats: 4)
        loop.automator = AutomatorConfig(startSpeed: 0.6, targetSpeed: 1.2, stepCount: 5,
                                         loopsPerStep: 3, enabled: true)
        XCTAssertEqual(loop.speed, 0.6, accuracy: 1e-9, "start writes back to loop.speed")
        XCTAssertEqual(loop.automatorTargetSpeed, 1.2, accuracy: 1e-9)
        XCTAssertEqual(loop.automatorStepCount, 5)
        XCTAssertEqual(loop.automatorLoopsPerStep, 3)
        XCTAssertTrue(loop.automatorEnabled)
    }

    // MARK: - Loop structured-field defaults (ADR 0036 slice 3)

    func testLoopStructuredFieldsHaveDeclarationDefaults() {
        // Declaration defaults are what SwiftData lightweight migration writes into
        // pre-0036 loops; a freshly-constructed loop exercises the same defaults.
        let loop = Loop(name: "L", start: 0.1, end: 0.2, speed: 1, repeats: 1)
        XCTAssertEqual(loop.mastery, 0)
        XCTAssertEqual(loop.focus, 1)
        XCTAssertEqual(loop.commandTempo, 1.0, accuracy: 1e-9)
        XCTAssertEqual(loop.loopType, .unset)
    }

    // MARK: - Tempo precision (ADR 0024)

    func testTempoBPMIsNilWhenNoTempoKnown() {
        XCTAssertNil(makeSong().tempoBPM)
    }

    func testTempoBPMFallsBackToRoundedBPM() {
        let song = makeSong()
        song.bpm = 120
        XCTAssertEqual(song.tempoBPM ?? 0, 120, accuracy: 1e-9)
    }

    func testTempoBPMPrefersPreciseValueOverRoundedMirror() {
        let song = makeSong()
        song.bpm = 150          // rounded display mirror
        song.preciseBPM = 149.55
        XCTAssertEqual(song.tempoBPM ?? 0, 149.55, accuracy: 1e-9)
    }

    // MARK: - First-launch seed

    func testSampleIsFlaggedAsDemoWithBackReferencedChildren() {
        let song = Song.sample()
        XCTAssertNil(song.ref.bookmark, "sample must be flagged as the generated demo (bookmark == nil)")
        XCTAssertFalse(song.loops.isEmpty)
        XCTAssertFalse(song.markers.isEmpty)
        XCTAssertTrue(song.loops.allSatisfy { $0.song === song }, "loops back-reference the song")
        XCTAssertTrue(song.markers.allSatisfy { $0.song === song }, "markers back-reference the song")
    }

    func testDemoAmplitudesCountAndClampedRange() {
        let amps = Song.demoAmplitudes(count: 120)
        XCTAssertEqual(amps.count, 120)
        XCTAssertTrue(amps.allSatisfy { $0 >= 0.06 && $0 <= 1.0 }, "amplitudes stay within the clamped 0.06...1 band")
    }
}
