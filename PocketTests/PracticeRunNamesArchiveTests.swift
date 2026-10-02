import XCTest
@testable import Pocket

/// The two fields ADR 0241 added to a logged run — the song (`songSourceID`) and the name it was shown
/// under (`unitLabel`) — through an export and a restore. Both are `Optional` so that an archive
/// written before them still opens: one missing non-optional key fails the **whole** file.
final class PracticeRunNamesArchiveTests: XCTestCase {

    private let date = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func record() -> SessionRecord {
        SessionRecord(startedAt: date, durationSeconds: 600, kind: .song, routineUID: UUID(),
                      songSourceID: "slow-bend-source", unitLabel: "Slow Bend")
    }

    private func archive(_ runs: [SessionRecord]) -> PracticeArchive {
        PracticeArchive(exportedAt: date, appVersion: "1.3", includesTakeAudio: false, practiceRuns: runs)
    }

    func testARunsSongAndNameSurviveAnExport() throws {
        let read = try ArchiveBuilder.decode(ArchiveBuilder.encode(archive([record()])))
        let run = try XCTUnwrap(read.practiceRuns.first)
        XCTAssertEqual(run.songSourceID, "slow-bend-source")
        XCTAssertEqual(run.unitLabel, "Slow Bend")
    }

    /// Encoded for real and then stripped, rather than a hand-written fixture: a fixture has to name
    /// every required key and goes stale as the format grows.
    func testAnArchiveWrittenBeforeTheFieldsStillDecodes() throws {
        let data = try ArchiveBuilder.encode(archive([record()]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let runs = try XCTUnwrap(object["practiceRuns"] as? [[String: Any]])
        object["practiceRuns"] = runs.map { run in
            var run = run
            run.removeValue(forKey: "songSourceID")
            run.removeValue(forKey: "unitLabel")
            return run
        }
        let read = try ArchiveBuilder.decode(JSONSerialization.data(withJSONObject: object))
        let run = try XCTUnwrap(read.practiceRuns.first)
        XCTAssertNil(run.songSourceID)
        XCTAssertNil(run.unitLabel)
        XCTAssertEqual(run.durationSeconds, 600, "the rest of the row is untouched")
        XCTAssertEqual(run.kind, .song)
    }

    @MainActor
    func testARestoreLandsBothFields() throws {
        let landing = ArchiveRestoreWriter.materialize(archive([record()]), existing: RestoreExistingKeys())
        let run = try XCTUnwrap(landing.runs.first)
        XCTAssertEqual(run.songSourceID, "slow-bend-source")
        XCTAssertEqual(run.unitLabel, "Slow Bend")
        XCTAssertEqual(run.record.songSourceID, "slow-bend-source", "and the row hands them to the stats layer")
    }
}
