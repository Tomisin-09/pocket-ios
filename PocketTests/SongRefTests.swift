import XCTest
@testable import Pocket

final class SongRefTests: XCTestCase {

    func testLocalFileEqualityIgnoresBookmark() {
        let a = SongRef(id: "song-1", source: .localFile, bookmark: Data([1, 2, 3]))
        let b = SongRef(id: "song-1", source: .localFile, bookmark: Data([9, 9, 9]))
        // Same imported file, refreshed bookmark — must stay equal so loops/
        // markers don't orphan on relaunch.
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testDifferentSourcesWithSameIdAreNotEqual() {
        let appleMusic = SongRef.appleMusic(id: "shared")
        let local = SongRef(id: "shared", source: .localFile, bookmark: Data())
        XCTAssertNotEqual(appleMusic, local)
    }

    func testLocalFileFactoryAssignsStableId() {
        let ref = SongRef.localFile(bookmark: Data([1]))
        XCTAssertEqual(ref.source, .localFile)
        XCTAssertFalse(ref.id.isEmpty)
        XCTAssertNotNil(ref.bookmark)
    }

    func testCodableRoundTrip() throws {
        let original = SongRef.localFile(bookmark: Data([4, 5, 6]), id: "fixed-id")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SongRef.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.bookmark, Data([4, 5, 6]))
    }

    func testUsableAsDictionaryKey() {
        var data: [SongRef: Int] = [:]
        data[.appleMusic(id: "x")] = 1
        data[SongRef(id: "x", source: .appleMusic, bookmark: nil)] = 2
        XCTAssertEqual(data.count, 1)
        XCTAssertEqual(data[.appleMusic(id: "x")], 2)
    }
}
