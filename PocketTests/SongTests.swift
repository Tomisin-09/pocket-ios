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
