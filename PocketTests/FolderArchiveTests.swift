import XCTest
@testable import Pocket

/// Folders on the wire (ADR 0210 D8): what an archive carries, and — the part that matters far more
/// — what happens to an archive written **before** the field existed.
final class FolderArchiveTests: XCTestCase {

    private let uid = UUID()

    private func archive(exerciseFolders: [String]?,
                         routineFolders: [String]?,
                         markers: [String]?) -> PracticeArchive {
        var drill = ArchiveFixture.exercise(uid: uid)
        drill.folders = exerciseFolders
        var routine = ArchiveFixture.routine(uid: UUID())
        routine.folders = routineFolders
        return PracticeArchive(exportedAt: ArchiveFixture.date,
                               appVersion: "1.2",
                               includesTakeAudio: false,
                               exercises: [drill],
                               routines: [routine],
                               folderMarkers: markers)
    }

    // MARK: - Round trip

    func testFoldersSurviveAnEncodeAndDecode() throws {
        let written = archive(exerciseFolders: ["Beginner/Warm-ups", "Technique"],
                              routineFolders: ["Beginner"],
                              markers: ["Grade 4"])
        let read = try ArchiveBuilder.decode(ArchiveBuilder.encode(written))
        XCTAssertEqual(read.exercises.first?.folders, ["Beginner/Warm-ups", "Technique"])
        XCTAssertEqual(read.routines.first?.folders, ["Beginner"])
        XCTAssertEqual(read.folderMarkers, ["Grade 4"])
    }

    /// **The reason the field is `Optional`.** Swift's synthesized `Decodable` calls
    /// `decode(_:forKey:)` and throws `keyNotFound` for a missing key — a declaration default does
    /// not save it — so a non-optional `folders` would make every archive written before this ADR
    /// fail to decode *entirely*, not merely arrive without folders.
    ///
    /// Encoded and then stripped rather than hand-written, because a hand-written fixture of a
    /// forty-field record goes stale the first time an unrelated field is added.
    func testAnArchiveWithNoFoldersKeyAtAllStillDecodes() throws {
        let written = archive(exerciseFolders: ["Beginner"], routineFolders: ["Beginner"],
                              markers: ["Grade 4"])
        let stripped = try strippingKeys(["folders", "folderMarkers"],
                                         from: ArchiveBuilder.encode(written))

        let read = try ArchiveBuilder.decode(stripped)
        XCTAssertNil(read.exercises.first?.folders)
        XCTAssertNil(read.routines.first?.folders)
        XCTAssertNil(read.folderMarkers)
        // And the rest of the record is intact — the point being that one missing key took nothing
        // else with it.
        XCTAssertEqual(read.exercises.first?.name, "Spider walk")
        XCTAssertEqual(read.exercises.first?.uid, uid)
    }

    /// Removes every occurrence of the named keys, at any depth, from encoded JSON.
    private func strippingKeys(_ keys: Set<String>, from data: Data) throws -> Data {
        func strip(_ value: Any) -> Any {
            if let object = value as? [String: Any] {
                return object
                    .filter { !keys.contains($0.key) }
                    .mapValues(strip)
            }
            if let array = value as? [Any] { return array.map(strip) }
            return value
        }
        let json = try JSONSerialization.jsonObject(with: data)
        return try JSONSerialization.data(withJSONObject: strip(json))
    }

    // MARK: - Restore

    @MainActor
    func testRestoreLandsFoldersAndSkipsMarkersTheLibraryAlreadyHas() {
        let written = archive(exerciseFolders: ["Beginner/Warm-ups"],
                              routineFolders: ["Beginner"],
                              markers: ["Grade 4", "grade 4", "Grade 5"])
        var existing = RestoreExistingKeys()
        existing.folderPaths = ["grade 5"]

        let landing = ArchiveRestoreWriter.materialize(written, existing: existing)

        XCTAssertEqual(landing.exercises.first?.folders, ["Beginner/Warm-ups"])
        XCTAssertEqual(landing.routines.first?.routine.folders, ["Beginner"])
        // "grade 4" is the same folder as "Grade 4"; "Grade 5" is already there.
        XCTAssertEqual(landing.folders.map(\.path), ["Grade 4"])
    }

    @MainActor
    func testAnArchiveWithoutFoldersRestoresAnUnfiledLibrary() {
        let written = archive(exerciseFolders: nil, routineFolders: nil, markers: nil)
        let landing = ArchiveRestoreWriter.materialize(written, existing: RestoreExistingKeys())
        XCTAssertEqual(landing.exercises.first?.folders, [])
        XCTAssertEqual(landing.routines.first?.routine.folders, [])
        XCTAssertTrue(landing.folders.isEmpty)
    }

    /// Markers are not library items, so they must not move the number the restore preview promised.
    @MainActor
    func testMarkersDoNotCountAsRestoredRows() {
        let withMarkers = ArchiveRestoreWriter.materialize(
            archive(exerciseFolders: nil, routineFolders: nil, markers: ["Grade 4", "Grade 5"]),
            existing: RestoreExistingKeys())
        let without = ArchiveRestoreWriter.materialize(
            archive(exerciseFolders: nil, routineFolders: nil, markers: nil),
            existing: RestoreExistingKeys())
        XCTAssertEqual(withMarkers.rowCount, without.rowCount)
    }

    // MARK: - Sharing one drill

    /// A drill handed over on its own arrives **unfiled** (D8): its paths are positions in the
    /// sender's tree, and reproducing them would hand over a filing cabinet with the drill.
    @MainActor
    func testASharedDrillCarriesLeafNamesAsTagsAndNoFolders() {
        let exercise = Exercise(name: "Alternating picking")
        exercise.folders = ["Students/2026/Beginner", "Technique/Alternate picking"]
        exercise.tags = ["old-tag"]

        let record = SharedPracticeBuilder.shareable(exercise)

        XCTAssertNil(record.folders, "The sender's tree must not cross on a single-drill share")
        XCTAssertEqual(record.tags, ["Alternate picking", "Beginner", "old-tag"],
                       "Leaf names are added to the tags, not substituted for them")
    }
}
