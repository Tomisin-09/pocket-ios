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

    // MARK: - Same as (D8) and repeats (D14)

    private func archive(loop: LoopRecord, markers: [MarkerRecord] = []) -> PracticeArchive {
        var written = archive(markers: markers)
        written.songs[0].loops = [loop]
        return written
    }

    func testSameAsAndRepeatsSurviveAnEncodeAndDecode() throws {
        let verse = UUID()
        var loop = ArchiveFixture.loop(uid: UUID())
        loop.repeatsToSectionEnd = true
        loop.repeatsTo = "song"
        let written = archive(loop: loop, markers: [
            MarkerRecord(uid: verse, seconds: 8, label: "Verse 1", startsSection: true),
            MarkerRecord(uid: UUID(), seconds: 40, label: "Verse 2", startsSection: true, sameAsUID: verse)
        ])
        let read = try XCTUnwrap(ArchiveBuilder.decode(ArchiveBuilder.encode(written)).songs.first)
        XCTAssertEqual(read.markers.last?.sameAsUID, verse)
        XCTAssertEqual(read.loops.first?.repeatsToSectionEnd, true)
        XCTAssertEqual(read.loops.first?.repeatsTo, "song")
    }

    func testAFileFromBeforeSlice3StillDecodes() throws {
        let data = try ArchiveBuilder.encode(archive(loop: ArchiveFixture.loop(uid: UUID()),
                                                     markers: [MarkerRecord(uid: UUID(), seconds: 8, label: "M1")]))
        let text = try XCTUnwrap(String(bytes: data, encoding: .utf8))
        XCTAssertFalse(text.contains("sameAsUID"))
        XCTAssertFalse(text.contains("repeatsToSectionEnd"))
        XCTAssertFalse(text.contains("\"repeatsTo\""), "nor slice 3b's reach (D15)")
        let song = try XCTUnwrap(ArchiveBuilder.decode(data).songs.first)
        XCTAssertNil(song.markers.first?.sameAsUID)
        XCTAssertNil(song.loops.first?.repeatsToSectionEnd)
        XCTAssertNil(song.loops.first?.repeatsTo)
        XCTAssertEqual(song.loops.first?.name, "Turnaround", "the missing keys took nothing else")
    }

    @MainActor
    func testRestoreLandsSameAsAndRepeatsAndReadsMissingOnesAsNone() throws {
        let verse = UUID(), again = UUID(), repeating = UUID(), plain = UUID()
        var looped = ArchiveFixture.loop(uid: repeating)
        looped.repeatsToSectionEnd = true
        looped.repeatsTo = again.uuidString
        var written = archive(markers: [MarkerRecord(uid: verse, seconds: 8, label: "Verse 1", startsSection: true),
                                        MarkerRecord(uid: again, seconds: 40, label: "Verse 2", startsSection: true,
                                                     sameAsUID: verse)])
        written.songs[0].loops = [looped, ArchiveFixture.loop(uid: plain)]
        let landing = ArchiveRestoreWriter.materialize(written, existing: RestoreExistingKeys())
        let song = try XCTUnwrap(landing.songs.first)
        XCTAssertEqual(song.markers.first { $0.uid == again }?.sameAsUID, verse)
        XCTAssertNil(song.markers.first { $0.uid == verse }?.sameAsUID)
        XCTAssertEqual(song.loops.first { $0.uid == repeating }?.repeatsToSectionEnd, true)
        XCTAssertEqual(song.loops.first { $0.uid == repeating }?.repeatsTo, again.uuidString)
        XCTAssertEqual(song.loops.first { $0.uid == plain }?.repeatsToSectionEnd, false)
        let plainLoop = try XCTUnwrap(song.loops.first { $0.uid == plain })
        XCTAssertNil(plainLoop.repeatsTo)
    }

    @MainActor
    func testALoopRepeatsNoFurtherUntilThePlayerSaysSo() {
        let loop = Loop(name: "Vamp", start: 0, end: 0.1, speed: 1, repeats: 4)
        XCTAssertFalse(loop.repeatsToSectionEnd)
        XCTAssertNil(loop.repeatsTo, "its own section's end, D14's reach")
        XCTAssertNil(Marker(seconds: 8, label: "Verse 2").sameAsUID)
    }
}
