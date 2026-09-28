import XCTest
@testable import Pocket

/// A marker's **Starts a section** (ADR 0232 D6) in a backup: written, absent from a file made before
/// it without failing the file, and landed back on the marker by a restore.
final class SongMapArchiveTests: XCTestCase {

    private func archive(markers: [MarkerRecord]) -> PracticeArchive {
        var archive = PracticeArchive(exportedAt: ArchiveFixture.date, appVersion: "1.3",
                                      includesTakeAudio: false)
        var song = ArchiveFixture.song(sourceID: "song-1", loops: [])
        song.markers = markers
        archive.songs = [song]
        return archive
    }

    func testTheSwitchSurvivesAnEncodeAndDecode() throws {
        let written = archive(markers: [MarkerRecord(uid: UUID(), seconds: 8, label: "Verse", startsSection: true)])
        let read = try ArchiveBuilder.decode(ArchiveBuilder.encode(written))
        XCTAssertEqual(read.songs.first?.markers.first?.startsSection, true)
    }

    func testAFileFromBeforeTheMapStillDecodes() throws {
        // No value, so the encoding has no key at all: a file made before ADR 0232.
        let data = try ArchiveBuilder.encode(archive(markers: [MarkerRecord(uid: UUID(), seconds: 8, label: "M1")]))
        XCTAssertFalse(try XCTUnwrap(String(bytes: data, encoding: .utf8)).contains("startsSection"))
        let marker = try XCTUnwrap(ArchiveBuilder.decode(data).songs.first?.markers.first)
        XCTAssertNil(marker.startsSection)
        XCTAssertEqual(marker.label, "M1", "the missing key took nothing else")
    }

    @MainActor
    func testRestoreLandsTheSwitchAndReadsAMissingOneAsOff() throws {
        let verse = UUID(), pin = UUID()
        let landing = ArchiveRestoreWriter.materialize(
            archive(markers: [MarkerRecord(uid: verse, seconds: 8, label: "Verse", startsSection: true),
                              MarkerRecord(uid: pin, seconds: 20, label: "M2")]),
            existing: RestoreExistingKeys())
        let markers = try XCTUnwrap(landing.songs.first?.markers)
        XCTAssertEqual(markers.first { $0.uid == verse }?.startsSection, true)
        XCTAssertEqual(markers.first { $0.uid == pin }?.startsSection, false)
    }

    @MainActor
    func testAMarkerStartsNoSectionUntilThePlayerSaysSo() {
        XCTAssertFalse(Marker(seconds: 8, label: "Verse").startsSection)
    }
}
