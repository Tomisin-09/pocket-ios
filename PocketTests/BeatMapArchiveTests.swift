import XCTest
@testable import Pocket

/// A song's beat map (ADR 0281) through an export, a restore and a shared song. The field is
/// `Optional` in the record so that an archive written before it still opens: one missing
/// non-optional key fails the **whole** file (ADR 0212).
final class BeatMapArchiveTests: XCTestCase {

    private let map: [TimeInterval] = [1.25, 1.9, 2.52, 3.11, 3.68, 4.24]
    private let date = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func record(beatTimes: [TimeInterval]?) -> SongRecord {
        var record = ArchiveFixture.song(sourceID: "binta")
        record.beatTimes = beatTimes
        return record
    }

    private func archive(_ songs: [SongRecord]) -> PracticeArchive {
        PracticeArchive(exportedAt: date, appVersion: "1.4", includesTakeAudio: false, songs: songs)
    }

    func testAMapSurvivesAnExport() throws {
        let read = try ArchiveBuilder.decode(ArchiveBuilder.encode(archive([record(beatTimes: map)])))
        XCTAssertEqual(read.songs.first?.beatTimes, map)
    }

    /// Written `nil` rather than `[]`, so a song without a map exports exactly as it did before.
    @MainActor
    func testASongWithoutAMapWritesNoKey() throws {
        let song = Song(title: "Binta", duration: 200, ref: SongRef(id: "binta", source: .localFile, bookmark: nil))
        XCTAssertNil(ArchiveBuilder.songRecord(song).beatTimes)
        song.beatTimes = map
        XCTAssertEqual(ArchiveBuilder.songRecord(song).beatTimes, map)

        let data = try ArchiveBuilder.encode(archive([record(beatTimes: nil)]))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let songs = try XCTUnwrap(object["songs"] as? [[String: Any]])
        XCTAssertNil(songs.first?["beatTimes"])
    }

    /// Encoded for real and then stripped, rather than a hand-written fixture: a fixture has to name
    /// every required key and goes stale as the format grows.
    func testAnArchiveWrittenBeforeTheFieldStillDecodes() throws {
        let data = try ArchiveBuilder.encode(archive([record(beatTimes: map)]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let songs = try XCTUnwrap(object["songs"] as? [[String: Any]])
        object["songs"] = songs.map { song in
            var song = song
            song.removeValue(forKey: "beatTimes")
            return song
        }
        let read = try ArchiveBuilder.decode(JSONSerialization.data(withJSONObject: object))
        let song = try XCTUnwrap(read.songs.first)
        XCTAssertNil(song.beatTimes)
        XCTAssertEqual(song.preciseBPM, 92.4, "the rest of the row is untouched")
    }

    @MainActor
    func testARestoreLandsTheMap() throws {
        let landing = ArchiveRestoreWriter.materialize(archive([record(beatTimes: map)]),
                                                       existing: RestoreExistingKeys())
        XCTAssertEqual(landing.songs.first?.beatTimes, map)
    }

    @MainActor
    func testARestoreWithoutTheFieldLandsNoMap() throws {
        let landing = ArchiveRestoreWriter.materialize(archive([record(beatTimes: nil)]),
                                                       existing: RestoreExistingKeys())
        XCTAssertEqual(landing.songs.first?.beatTimes, [])
    }

    @MainActor
    func testASharedSongArrivesWithItsMap() {
        let song = Song(title: "Binta", duration: 200, ref: SongRef(id: "copy", source: .localFile, bookmark: nil))
        ReceivedSongBuilder.apply(record(beatTimes: map), to: song)
        XCTAssertEqual(song.beatTimes, map)
        XCTAssertTrue(song.hasBeatMap)
    }
}
