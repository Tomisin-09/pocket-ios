import XCTest
@testable import Pocket

/// A drill's phase shape (ADR 0221) **on the wire**: what a backup carries, what one written before
/// 0221 does, and what a restore, a received file, a share and a duplicate keep. Every new record
/// field is `Optional` because a Codable default does not survive a missing key — see
/// `FolderArchiveTests` for the long version.
final class PhaseShapeArchiveTests: XCTestCase {

    private static let phaseKeys: Set<String> = ["includeWarmup", "includeReach", "rampWarmupSteps",
                                                  "rampWarmupHold", "rampReachHold", "rampBackoffHold"]

    /// A drill with every phase field away from its default.
    private func shapedRecord() -> ExerciseRecord {
        var record = ArchiveFixture.exercise(uid: UUID())
        record.includeWarmup = false
        record.includeReach = false
        record.rampWarmupSteps = 2
        record.rampWarmupHold = 3
        record.rampReachHold = 2
        record.rampBackoffHold = 4
        return record
    }

    private func archive(_ record: ExerciseRecord) -> PracticeArchive {
        PracticeArchive(exportedAt: ArchiveFixture.date, appVersion: "1.3", includesTakeAudio: false,
                        exercises: [record])
    }

    private func assertShaped(_ drill: Exercise?, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(drill?.includeWarmup, false, file: file, line: line)
        XCTAssertEqual(drill?.includeReach, false, file: file, line: line)
        XCTAssertEqual(drill?.rampWarmupSteps, 2, file: file, line: line)
        XCTAssertEqual(drill?.rampWarmupHold, 3, file: file, line: line)
        XCTAssertEqual(drill?.rampReachHold, 2, file: file, line: line)
        XCTAssertEqual(drill?.rampBackoffHold, 4, file: file, line: line)
    }

    // MARK: - The file

    func testTheShapeSurvivesAnEncodeAndDecode() throws {
        let written = archive(shapedRecord())
        let read = try ArchiveBuilder.decode(ArchiveBuilder.encode(written))
        XCTAssertEqual(read.exercises, written.exercises)
    }

    @MainActor
    func testABuilderWritesTheModelsShape() {
        let drill = Exercise(currentTempo: 70, commandTempo: 100)
        drill.applyRunShape(RunShape(includeWarmup: false, includeReach: true, includeBackoff: true,
                                     warmupSteps: 3, warmupHold: 2, reachHold: 5, backoffHold: 6))
        let record = ArchiveBuilder.exerciseRecord(drill)
        XCTAssertEqual(record.includeWarmup, false)
        XCTAssertEqual(record.includeReach, true)
        XCTAssertEqual(record.rampWarmupSteps, 3)
        XCTAssertEqual([record.rampWarmupHold, record.rampReachHold, record.rampBackoffHold], [2, 5, 6])
    }

    /// A backup from before 0221 has none of these keys. It must decode — one missing non-optional
    /// key fails the whole file — and the loops' own long-standing `rampWarmupSteps` is untouched.
    func testAnArchiveWrittenBeforePhaseShapesStillDecodes() throws {
        var written = archive(shapedRecord())
        written.songs = [ArchiveFixture.song(sourceID: "song-1", loops: [ArchiveFixture.loop(uid: UUID())])]
        let read = try ArchiveBuilder.decode(strippingPhaseKeys(from: ArchiveBuilder.encode(written)))
        let drill = try XCTUnwrap(read.exercises.first)
        XCTAssertNil(drill.includeWarmup)
        XCTAssertNil(drill.includeReach)
        XCTAssertNil(drill.rampWarmupSteps)
        XCTAssertNil(drill.rampWarmupHold)
        XCTAssertEqual(drill.name, "Spider walk", "one missing key took nothing else with it")
        XCTAssertEqual(read.songs.first?.loops.first?.rampWarmupSteps, 1, "a loop's count predates 0221")
    }

    // MARK: - Restore and receive

    /// An older backup restores as today's shape: every phase on, one interval a rung, and the
    /// warm-up count derived from the stride the file does carry.
    @MainActor
    func testAnOldBackupRestoresTodaysShape() throws {
        // The fixture sets none of the 0221 fields, so it is a record from before them.
        let record = ArchiveFixture.exercise(uid: UUID())
        let landing = ArchiveRestoreWriter.materialize(archive(record), existing: RestoreExistingKeys())
        let drill = try XCTUnwrap(landing.exercises.first)
        let shape = drill.runShape
        XCTAssertTrue(shape.includeWarmup && shape.includeReach && shape.includeBackoff)
        XCTAssertEqual([shape.warmupHold, shape.reachHold, shape.backoffHold], [1, 1, 1])
        XCTAssertNil(drill.rampWarmupSteps)
        // 97 → 104 at the fixture's 4-BPM stride ⇒ round(7 / 4) − 1 = 1 intermediate stop.
        XCTAssertEqual(drill.warmupSteps, 1)
    }

    @MainActor
    func testRestoreLandsTheShape() {
        let landing = ArchiveRestoreWriter.materialize(archive(shapedRecord()), existing: RestoreExistingKeys())
        assertShaped(landing.exercises.first)
    }

    @MainActor
    func testAReceivedDrillKeepsItsShape() {
        assertShaped(ReceivedRoutineBuilder.exercise(from: shapedRecord()))
    }

    @MainActor
    func testASharedDrillCarriesItsShape() {
        let drill = ReceivedRoutineBuilder.exercise(from: shapedRecord())
        let shared = SharedPracticeBuilder.shareable(drill)
        XCTAssertEqual(shared.includeReach, false)
        XCTAssertEqual(shared.rampWarmupSteps, 2)
        XCTAssertEqual(shared.rampBackoffHold, 4)
    }

    func testADuplicateKeepsTheShape() {
        let drill = Exercise(name: "Spider walk", currentTempo: 70, commandTempo: 100)
        drill.applyRunShape(RunShape(includeWarmup: false, includeReach: false, warmupSteps: 2,
                                     warmupHold: 3, reachHold: 2, backoffHold: 4))
        XCTAssertEqual(drill.duplicated(named: "Spider walk copy").runShape, drill.runShape)
    }

    // MARK: - Helpers

    /// Removes the 0221 keys from every **exercise** in encoded JSON, and nowhere else — a loop has
    /// carried `rampWarmupSteps` since long before.
    private func strippingPhaseKeys(from data: Data) throws -> Data {
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exercises = json["exercises"] as? [[String: Any]]
        else { return data }
        json["exercises"] = exercises.map { $0.filter { !Self.phaseKeys.contains($0.key) } }
        return try JSONSerialization.data(withJSONObject: json)
    }
}
