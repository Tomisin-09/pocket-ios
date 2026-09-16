import XCTest
@testable import Pocket

/// **Saved progressions on the wire** (ADR 0218 D10): what an export carries, what an archive written
/// before 0218 does, and what a restore lands — on the saved chords' rules (ADR 0188 D1, D6).
final class SavedProgressionArchiveTests: XCTestCase {

    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func record(uid: UUID = UUID(), name: String = "Verse changes",
                        steps: [ProgressionStep] = [ProgressionStep(9, .minor), ProgressionStep(5, bars: 2)],
                        tonic: Int? = 2) -> SavedProgressionRecord {
        let payload = SavedProgressionPayload(steps: steps, tonic: tonic)
        return SavedProgressionRecord(uid: uid, name: name, createdAt: date,
                                      payload: JSONValue.decoding(payload.encoded))
    }

    private func archive(_ progressions: [SavedProgressionRecord]?) -> PracticeArchive {
        PracticeArchive(exportedAt: date, appVersion: "1.3", includesTakeAudio: false,
                        savedProgressions: progressions)
    }

    // MARK: - Export

    @MainActor
    func testAnExportCarriesTheStepsAndTheKeyExactlyAsStored() throws {
        let saved = SavedProgression(ProgressionDraft(name: "Chorus", tonic: 9,
                                                      steps: [ProgressionStep(0, .minor), ProgressionStep(10)]))
        var source = ArchiveSource()
        source.savedProgressions = [saved]
        let written = ArchiveBuilder.snapshot(from: source, appVersion: "1.3", includesTakeAudio: false,
                                              exportedAt: date)
        let exported = try XCTUnwrap(written.savedProgressions?.first)
        XCTAssertEqual(exported.uid, saved.uid)
        XCTAssertEqual(exported.name, "Chorus")
        let payload = try JSONDecoder().decode(SavedProgressionPayload.self,
                                               from: JSONEncoder().encode(XCTUnwrap(exported.payload)))
        XCTAssertEqual(payload.steps, saved.steps)
        XCTAssertEqual(payload.tonic, 9)
    }

    func testSavedProgressionsSurviveAnEncodeAndDecode() throws {
        let written = archive([record()])
        let read = try ArchiveBuilder.decode(ArchiveBuilder.encode(written))
        XCTAssertEqual(read.savedProgressions, written.savedProgressions)
    }

    /// **Why the field is `Optional`**: an archive from before 0218 has no such key, and one missing
    /// non-optional key fails the whole file.
    func testAnArchiveWrittenBeforeSavedProgressionsStillDecodes() throws {
        let data = try ArchiveBuilder.encode(archive([record()]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "savedProgressions")
        let read = try ArchiveBuilder.decode(JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(read.savedProgressions)
    }

    // MARK: - Restore

    @MainActor
    func testARestoreLandsTheProgressionWithItsUIDStepsAndKey() throws {
        let original = record()
        let landing = ArchiveRestoreWriter.materialize(archive([original]), existing: RestoreExistingKeys())
        let landed = try XCTUnwrap(landing.savedProgressions.first)
        XCTAssertEqual(landed.uid, original.uid, "preserved, like every restored row's uid")
        XCTAssertEqual(landed.name, "Verse changes")
        XCTAssertEqual(landed.steps, [ProgressionStep(9, .minor), ProgressionStep(5, bars: 2)])
        XCTAssertEqual(landed.payload.tonic, 2)
        XCTAssertEqual(landing.rowCount, 1, "a saved progression is a library item the preview counts")
    }

    @MainActor
    func testOneTheLibraryAlreadyHasIsLeftAloneAndCountedAsPresent() {
        let original = record()
        var existing = RestoreExistingKeys()
        existing.savedProgressionUIDs = [original.uid]

        let landing = ArchiveRestoreWriter.materialize(archive([original]), existing: existing)
        XCTAssertTrue(landing.savedProgressions.isEmpty, "nothing is overwritten (ADR 0188 D6)")

        let plan = RestorePlan.make(for: archive([original, record()]), existing: existing, takeAudio: [])
        let line = plan.lines.first { $0.kind == .savedProgressions }
        XCTAssertEqual(line?.landing, 1)
        XCTAssertEqual(line?.alreadyPresent, 1)
        XCTAssertEqual(RestorePlan.Kind.savedProgressions.label, "Saved progressions")
    }

    @MainActor
    func testARowWithNoStepsToReadIsSkippedAndARepeatIsCountedOnce() {
        let uid = UUID()
        let unreadable = SavedProgressionRecord(uid: UUID(), name: "Empty", createdAt: date, payload: nil)
        let landing = ArchiveRestoreWriter.materialize(archive([record(uid: uid), record(uid: uid), unreadable]),
                                                       existing: RestoreExistingKeys())
        XCTAssertEqual(landing.savedProgressions.map(\.uid), [uid],
                       "a progression is its steps; a row without them has nothing to insert")
    }

    func testAnArchiveWithoutProgressionsHasNoSummaryLineForThem() {
        let plan = RestorePlan.make(for: archive(nil), existing: RestoreExistingKeys(), takeAudio: [])
        XCTAssertFalse(plan.lines.contains { $0.kind == .savedProgressions })
    }
}
