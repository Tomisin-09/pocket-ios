import XCTest
@testable import Pocket

/// The archive's promises about what crosses into an export and what does not (ADR 0181).
///
/// Every model here is built and left **uninserted** — no `ModelContainer`, no `ModelContext`. That is
/// the house rule for model tests in this host (inserting traps), and it is also what the builder is
/// designed for: it reads plain models and returns a plain value, so the mapping rules are testable
/// without a store at all.
@MainActor
final class PracticeArchiveTests: XCTestCase {

    // MARK: - Fixtures

    private func makeSong(title: String = "Sample",
                          sourceID: String = "song-1",
                          bookmark: Data? = Data([0x01, 0x02, 0x03]),
                          amplitudes: [Double] = Array(repeating: 0.5, count: 512)) -> Song {
        Song(title: title,
             artist: "Jack Trader",
             duration: 200,
             amplitudes: amplitudes,
             ref: SongRef(id: sourceID, source: .localFile, bookmark: bookmark),
             audioFileName: "\(sourceID).wav")
    }

    /// The encoded archive as text, for the assertions that are about what does or does not appear in
    /// the file itself rather than in the value tree.
    private func encodedJSON(_ archive: PracticeArchive) throws -> String {
        try XCTUnwrap(String(bytes: ArchiveBuilder.encode(archive), encoding: .utf8))
    }

    private func archive(_ source: ArchiveSource, takeAudio: Bool = true) -> PracticeArchive {
        ArchiveBuilder.snapshot(from: source,
                                appVersion: "1.2 (5)",
                                includesTakeAudio: takeAudio,
                                exportedAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - The two exclusions

    /// A security-scoped bookmark is meaningless outside the installation that minted it — exporting one
    /// would ship a value guaranteed to be dead wherever it is read.
    func testTheArchiveNeverCarriesASecurityScopedBookmark() throws {
        let source = ArchiveSource(songs: [makeSong()])
        let json = try encodedJSON(archive(source))

        // Positive control first. Without it an empty or malformed encode would sail through the real
        // assertion below — a privacy check that passes because it read nothing is worse than none.
        XCTAssertTrue(json.contains("\"sourceID\""), "The song did not encode; the check below is vacuous")

        XCTAssertFalse(json.contains("bookmark"),
                       "A bookmark reached the archive — it is installation-scoped and must never leave")
    }

    /// 512 doubles per song of derived waveform data, re-extractable in a second, would dominate a file
    /// whose point is the writing.
    func testTheArchiveNeverCarriesTheWaveformEnvelope() throws {
        let source = ArchiveSource(songs: [makeSong()])
        let data = try ArchiveBuilder.encode(archive(source))
        let json = try XCTUnwrap(String(bytes: data, encoding: .utf8))

        XCTAssertFalse(json.contains("amplitudes"), "The waveform envelope reached the archive")
        XCTAssertLessThan(data.count, 4_000,
                          "One song encoded large enough to suggest the envelope is still in there")
    }

    // MARK: - Identity

    /// `Song` is the one model with no `uid`, so the archive keys it on the identity its audio file is
    /// named for.
    func testASongIsKeyedOnItsSourceID() {
        let result = archive(ArchiveSource(songs: [makeSong(sourceID: "abc-123")]))

        XCTAssertEqual(result.songs.map(\.sourceID), ["abc-123"])
        XCTAssertEqual(result.songs.first?.audioFileName, "abc-123.wav")
    }

    // MARK: - The opaque JSON columns

    /// `templatePayload` is `Data` holding JSON. Emitted as base64 it would be unreadable in exactly the
    /// place a person looks; nested, it reads as itself.
    func testAnExerciseTemplateIsNestedAsJSONRatherThanBase64() throws {
        let exercise = Exercise()
        exercise.name = "Spider"
        exercise.templatePayload = Data(#"{"slots":[1,2],"name":"down-up"}"#.utf8)

        let result = archive(ArchiveSource(exercises: [exercise]))
        let json = try encodedJSON(result)

        XCTAssertEqual(result.exercises.first?.template,
                       .object(["slots": .array([.integer(1), .integer(2)]),
                                "name": .string("down-up")]))
        XCTAssertTrue(json.contains("\"down-up\""), "The payload did not survive as readable JSON")
    }

    /// A blob this build cannot parse costs the archive that one field, not the export.
    func testAnUnreadableTemplateDegradesToNilRatherThanFailing() {
        let exercise = Exercise()
        exercise.templatePayload = Data([0xFF, 0xFE, 0xFD])

        let result = archive(ArchiveSource(exercises: [exercise]))

        XCTAssertEqual(result.exercises.count, 1, "The exercise itself should still be exported")
        XCTAssertNil(result.exercises.first?.template)
    }

    // MARK: - Derivations stay out

    /// `canRecordTake` is derived from the block's unit. Writing it down would freeze today's rule into a
    /// file that outlives it.
    func testABlocksDerivedRecordabilityIsNotExportedButItsAuthoredFlagIs() throws {
        let routine = Routine()
        routine.name = "Morning"
        let item = RoutineItem()
        item.recordsTake = true
        routine.items = [item]

        let result = archive(ArchiveSource(routines: [routine]))
        let json = try encodedJSON(result)

        XCTAssertEqual(result.routines.first?.items.first?.recordsTake, true)
        XCTAssertFalse(json.contains("canRecordTake"), "A derived rule reached the archive")
    }

    // MARK: - Round trip

    /// The encoder is only trustworthy if something proves it comes back. Nothing imports an archive yet,
    /// so this is the only thing standing between the format and a silent asymmetry.
    func testAnArchiveSurvivesAnEncodeDecodeRoundTrip() throws {
        let song = makeSong()
        let loop = Loop(name: "Verse riff", start: 0.1, end: 0.3, speed: 0.8, repeats: 4)
        song.loops = [loop]

        let recording = Recording(fileName: "take-1.m4a",
                                  duration: 12,
                                  createdAt: Date(timeIntervalSince1970: 1_700_000_000.5))
        recording.note = "Cleaner, but rushing the turnaround"

        let original = archive(ArchiveSource(songs: [song], recordings: [recording]))
        let decoded = try ArchiveBuilder.decode(ArchiveBuilder.encode(original))

        XCTAssertEqual(decoded, original)
    }

    /// Regression guard for the format's one real trap. Foundation's stock `.iso8601` strategy truncates
    /// to the second, so every timestamp in an archive came back up to a second adrift — and because the
    /// two values *print* identically, the failure reads as a baffling "x is not equal to x".
    func testATimestampKeepsItsSubSecondPrecision() throws {
        let stamped = Date(timeIntervalSince1970: 1_700_000_000.25)
        let recording = Recording(fileName: "take-3.m4a", duration: 5, createdAt: stamped)

        let decoded = try ArchiveBuilder.decode(
            ArchiveBuilder.encode(archive(ArchiveSource(recordings: [recording]))))

        XCTAssertEqual(decoded.takes.first?.createdAt, stamped)
    }

    /// Two exports of an unchanged library must be byte-identical, or a player cannot diff two archives
    /// to see what changed between them.
    func testTwoExportsOfTheSameLibraryAreByteIdentical() throws {
        let source = ArchiveSource(songs: [makeSong(title: "Zebra", sourceID: "z"),
                                           makeSong(title: "Apple", sourceID: "a")])

        let first = try ArchiveBuilder.encode(archive(source))
        let second = try ArchiveBuilder.encode(archive(source))

        XCTAssertEqual(first, second)
        XCTAssertEqual(archive(source).songs.map(\.title), ["Apple", "Zebra"], "Not sorted stably")
    }

    /// The flag says whether audio was a choice or a loss. It must not quietly drop the takes themselves:
    /// an archive without audio still carries every word written about every take.
    func testExcludingAudioStillCarriesEveryTakesWriting() {
        let recording = Recording(fileName: "take-2.m4a", duration: 8)
        recording.note = "Worth keeping"
        let moment = TakeNote(time: 3.5, text: "here")
        recording.moments = [moment]

        let result = archive(ArchiveSource(recordings: [recording]), takeAudio: false)

        XCTAssertFalse(result.includesTakeAudio)
        XCTAssertEqual(result.takes.first?.note, "Worth keeping")
        XCTAssertEqual(result.takes.first?.moments.map(\.text), ["here"])
        XCTAssertEqual(result.takes.first?.fileName, "take-2.m4a",
                       "The name of the absent file is what a reader needs to know what is missing")
    }
}
