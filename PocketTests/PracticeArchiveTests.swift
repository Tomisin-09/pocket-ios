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

    // MARK: - Pins (ADR 0190)

    /// A pin is small and its loss is **invisible**: a restored library comes back looking complete,
    /// and the player only finds out the next time they reach for the two entries that mattered.
    /// That is the whole reason it travels.
    func testAPinCrossesIntoTheArchiveOnBothKindsOfRow() {
        let entry = JournalEntry.forExercise(text: "Locked it.", kind: .breakthrough,
                                             commandBpmAtEntry: 96)
        entry.isPinned = true
        let take = Recording(fileName: "take-3.m4a", duration: 8)
        take.isPinned = true

        let result = archive(ArchiveSource(journal: [entry], recordings: [take]))

        XCTAssertEqual(result.journal.first?.isPinned, true)
        XCTAssertEqual(result.takes.first?.isPinned, true)
    }

    func testAnUnpinnedRowExportsAsUnpinnedRatherThanAsUnknown() {
        let entry = JournalEntry.forExercise(text: "Fine.", kind: .note, commandBpmAtEntry: 90)
        let result = archive(ArchiveSource(journal: [entry]))

        XCTAssertEqual(result.journal.first?.isPinned, false,
                       "The model column is a non-optional Bool, so `false` is a recorded fact")
    }

    // MARK: - ADR 0205, the marks and the span history

    /// A snag nests under the **song**, which is where the store puts it: it is cascade-owned by the
    /// song and only tagged with a loop, so 2:01 is 2:01 whether or not that loop still exists.
    func testSnagsAreCarriedUnderTheirSongWithTheLoopTheyWereTaggedWith() throws {
        let song = makeSong()
        let loop = Loop(name: "Verse riff", start: 0.1, end: 0.3, speed: 0.8, repeats: 4)
        loop.song = song
        let tagged = Snag(markedAt: Date(timeIntervalSince1970: 1_700_000_000.5),
                          seconds: 42, speed: 0.7, loopUID: loop.uid)
        tagged.song = song
        // Made with no loop armed. Nesting snags under loops would have dropped this one entirely.
        let loose = Snag(seconds: 12, speed: nil, loopUID: nil)
        loose.song = song

        let record = try XCTUnwrap(archive(ArchiveSource(songs: [song])).songs.first)

        XCTAssertEqual(record.snags.map(\.seconds), [12, 42], "Song order, `uid` breaking the tie")
        XCTAssertEqual(record.snags.last?.loopUID, loop.uid)
        XCTAssertNil(record.snags.first?.loopUID)
    }

    /// The narrowing is the most informative thing a player does with a loop (ADR 0199), and an archive
    /// that lost it would restore a library whose ladder back down had been cut.
    func testALoopCarriesItsRecordedSpanHistoryOldestFirst() throws {
        let song = makeSong()
        let loop = Loop(name: "Verse riff", start: 0.1, end: 0.3, speed: 0.8, repeats: 4)
        loop.song = song
        for (index, pair) in [(0.15, 0.35), (0.1, 0.3)].enumerated() {
            let change = LoopSpanChange(changedAt: Date(timeIntervalSince1970: Double(2 - index) * 86_400),
                                        start: pair.0, end: pair.1,
                                        previousStart: 0.05, previousEnd: 0.45,
                                        speed: 0.7, songDuration: 200)
            change.loop = loop
        }

        let record = try XCTUnwrap(archive(ArchiveSource(songs: [song])).songs.first?.loops.first)

        XCTAssertEqual(record.spanChanges.map(\.start), [0.1, 0.15], "Oldest first")
        XCTAssertEqual(record.spanChanges.first?.songDuration, 200,
                       "The duration at write time must survive — it is what lets a span read back in seconds")
    }

    /// Both are additive, so an archive written before them still decodes — and the format version does
    /// not move, because no field changed meaning.
    ///
    /// **Built by deleting the keys from a real archive** rather than by hand-writing a fixture. A
    /// hand-written one has to name every key the format requires, so it goes stale the moment the
    /// format grows and it fails for the wrong reason — which it did, on `exercises`, before this was
    /// rewritten. Deleting from the real thing tests exactly the claim: *this key, absent*.
    ///
    /// A declaration default does **not** buy this on its own: Swift's synthesized `Decodable` calls
    /// `decode(_:forKey:)` and throws `keyNotFound`. The `KeyedDecodingContainer` overloads in
    /// `ArchiveCoding.swift` are what makes it true, and this is the test that says so (ADR 0205 D5).
    func testAnArchiveWrittenBeforeSnagsAndSpanHistoriesStillDecodes() throws {
        let song = makeSong()
        let loop = Loop(name: "Verse riff", start: 0.1, end: 0.3, speed: 0.8, repeats: 4)
        loop.song = song
        let snag = Snag(seconds: 42, speed: 0.7, loopUID: loop.uid)
        snag.song = song

        let full = try encodedJSON(archive(ArchiveSource(songs: [song])))
        // Positive control: the keys have to be there for removing them to mean anything.
        XCTAssertTrue(full.contains("\"snags\""))
        XCTAssertTrue(full.contains("\"spanChanges\""))

        // Renamed rather than excised, so the JSON stays well-formed. An unknown key is ignored by
        // the decoder, which is the same thing as the old key being absent.
        let older = full
            .replacingOccurrences(of: #""snags""#, with: #""snagsWasNotAKeyYet""#)
            .replacingOccurrences(of: #""spanChanges""#, with: #""spanChangesWasNotAKeyYet""#)
        let decoded = try ArchiveBuilder.decode(Data(older.utf8))

        XCTAssertEqual(decoded.schemaVersion, PracticeArchive.currentSchemaVersion)
        XCTAssertEqual(decoded.songs.first?.snags, [])
        XCTAssertEqual(decoded.songs.first?.loops.first?.spanChanges, [])
    }
}
