import XCTest
@testable import Pocket

/// Whether a `.redmoonpractice` file is opened at all (ADR 0188 S2) — the version gate, the four ways
/// a file is refused, and the summary shown before anything is written.
///
/// What a file *becomes* once accepted is `ReceivedRoutineHydrationTests`. The split is the door's own:
/// this half decides, that half builds, and neither needs a picker, a document type or a simulator.
/// Fixtures are shared through `ReceivedRoutineFixture`.
@MainActor
final class ReceivedRoutineBuilderTests: XCTestCase {

    private typealias Fixture = ReceivedRoutineFixture

    // MARK: - The version gate (D2)

    func testTheVersionGateBranchesThreeWays() {
        XCTAssertEqual(SchemaVersionGate.evaluate(fileVersion: 4, currentVersion: 4), .proceed)
        XCTAssertEqual(SchemaVersionGate.evaluate(fileVersion: 3, currentVersion: 4),
                       .migrate(from: 3),
                       "An older file migrates — the branch exists before there is anything to do in it")
        XCTAssertEqual(SchemaVersionGate.evaluate(fileVersion: 5, currentVersion: 4),
                       .refuse(message: SchemaVersionGate.refusalMessage))
    }

    /// The refusal has to be a sentence the player can act on, not a decode failure — D2's one
    /// entirely predictable error case.
    func testARefusalNamesTheCauseAndWhatToDo() {
        XCTAssertTrue(SchemaVersionGate.refusalMessage.contains("newer version"))
        XCTAssertTrue(SchemaVersionGate.refusalMessage.contains("Update the app"))
        XCTAssertTrue(SchemaVersionGate.refusalMessage.contains("Red Moon"),
                      "User-facing copy names the app the player sees, never the target")
    }

    /// A version this app could not have written is refused rather than treated as an ancient archive
    /// with a migration owed to it.
    func testAnImpossibleVersionIsRefusedRatherThanMigrated() {
        XCTAssertEqual(SchemaVersionGate.evaluate(fileVersion: 0, currentVersion: 4),
                       .refuse(message: SchemaVersionGate.refusalMessage))
        XCTAssertEqual(SchemaVersionGate.evaluate(fileVersion: -1, currentVersion: 4),
                       .refuse(message: SchemaVersionGate.refusalMessage))
    }

    // MARK: - The four refusals

    func testANonPracticeFileIsReportedAsCorrupt() throws {
        XCTAssertEqual(try Fixture.failure(of: Data("not json at all".utf8)), .corrupt)
        XCTAssertEqual(try Fixture.failure(of: Data(#"{"nope": 1}"#.utf8)), .corrupt)
    }

    func testAFileFromTheFutureIsRefusedWithTheGatesSentence() throws {
        var payload = Fixture.shared(Fixture.routine().routine)
        payload.schemaVersion = SharedPractice.currentSchemaVersion + 1

        XCTAssertEqual(try Fixture.failure(of: try Fixture.encoded(payload)),
                       .futureVersion(message: SchemaVersionGate.refusalMessage))
    }

    /// `kindRaw` is a `String` so that a payload this build has never heard of can be *reported*. If
    /// it were the enum the whole file would fail to decode and the player would be told it was
    /// corrupt, which would be false.
    func testAnUnknownPayloadKindIsReportedRatherThanReadAsCorrupt() throws {
        var payload = Fixture.shared(Fixture.routine().routine)
        payload.kindRaw = "exercise"

        XCTAssertEqual(try Fixture.failure(of: try Fixture.encoded(payload)), .unsupportedKind)
    }

    func testAFileThatNamesARoutineAndCarriesNoneIsReportedAsIncomplete() throws {
        var payload = Fixture.shared(Fixture.routine().routine)
        payload.routine = nil

        XCTAssertEqual(try Fixture.failure(of: try Fixture.encoded(payload)), .incomplete)
    }

    /// Every refusal says something specific. A shared or empty sentence would mean an alert with a
    /// title and no body, which is what this enum exists to prevent.
    func testEveryRefusalCarriesItsOwnSentence() {
        let messages = [ReceiveFailure.corrupt,
                        .futureVersion(message: SchemaVersionGate.refusalMessage),
                        .unsupportedKind,
                        .incomplete].map(\.message)

        XCTAssertEqual(Set(messages).count, messages.count, "Two refusals read the same")
        XCTAssertFalse(messages.contains(where: \.isEmpty))
    }

    // MARK: - The preview (D9)

    func testThePreviewCountsWhatWillLand() throws {
        let value = try Fixture.received(Fixture.shared(Fixture.routine().routine))

        XCTAssertEqual(value.displayName, "Morning warm-up")
        XCTAssertEqual(value.blockCount, 3, "The unresolvable block is counted — it still arrives")
        XCTAssertEqual(value.exerciseCount, 1)
        XCTAssertEqual(value.placeholderLabels, ["Chorus — Slow Bend"])
        XCTAssertEqual(value.appVersion, "1.2 (7)")
        XCTAssertEqual(value.exportedAt, Fixture.fixedDate)
    }

    /// A routine can legitimately be saved unnamed, and an empty heading reads as a broken file.
    func testAnUnnamedRoutinePreviewsUnderAFallbackName() throws {
        let routine = Routine(name: "   ", dateAdded: Fixture.fixedDate)
        routine.items = [RoutineItem.item(Fixture.exercise(), order: 0)]

        XCTAssertEqual(try Fixture.received(Fixture.shared(routine)).displayName, "Practice routine")
    }

    /// A routine of pure exercise and rest blocks crosses whole, and the preview then has nothing to
    /// warn about — the reason the sheet's "Won't come across" section is conditional.
    func testARoutineWithNothingUnresolvableHasNoPlaceholders() throws {
        let routine = Routine(name: "All drills", dateAdded: Fixture.fixedDate)
        routine.items = [RoutineItem.item(Fixture.exercise(), order: 0), RoutineItem.rest(order: 1)]

        let value = try Fixture.received(Fixture.shared(routine))

        XCTAssertTrue(value.placeholderLabels.isEmpty)
        XCTAssertEqual(value.blockCount, 2)
    }
}
