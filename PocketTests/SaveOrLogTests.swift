import SwiftData
import XCTest
@testable import Pocket

/// `ModelContext.saveOrLog()` (ADR 0318): a save that works reports it and reaches the store, and a save
/// that fails reports it without throwing. Then the callers that read the result, and the switch a UI
/// test fails a save with. Models with no relationships, inserted on their own, per the project's
/// test-host trap note.
@MainActor
final class SaveOrLogTests: XCTestCase {

    private func container() throws -> ModelContainer {
        try ModelContainer(for: CustomSkill.self, Routine.self, RoutineItem.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// A save that works returns true, and a second context on the same store sees what was saved.
    func testASaveThatWorksSaysSoAndReachesTheStore() throws {
        let store = try container()
        let context = ModelContext(store)
        context.insert(CustomSkill(name: "Hybrid picking"))
        XCTAssertTrue(context.saveOrLog())
        XCTAssertFalse(context.hasChanges)
        let other = ModelContext(store)
        XCTAssertEqual(try other.fetch(FetchDescriptor<CustomSkill>()).map(\.name), ["Hybrid picking"])
    }

    /// A save that fails returns false and doesn't throw, so a caller that ignores it carries on as
    /// `try?` let it. The change is still pending in the context, as it was after a failed `try?`.
    func testASaveThatFailsSaysSoWithoutThrowing() throws {
        let context = ModelContext(try ReadOnlyStore.container(for: [CustomSkill.self]))
        context.insert(CustomSkill(name: "Sweep picking"))
        XCTAssertFalse(context.saveOrLog())
        XCTAssertTrue(context.hasChanges)
    }

    /// What a restore relies on after its save fails (ADR 0318): `rollback()` leaves nothing pending, so
    /// no later save can write the rows, and nothing was stored. What the same context then *fetches* is
    /// not asserted: after a failed save and a rollback SwiftData's fetch and count disagree there, and
    /// neither is what decides whether a row reaches the store.
    func testARollbackAfterAFailedSaveLeavesNothingToSave() throws {
        let store = try ReadOnlyStore.container(for: [CustomSkill.self])
        let context = ModelContext(store)
        context.insert(CustomSkill(name: "Economy picking"))
        XCTAssertFalse(context.saveOrLog())
        context.rollback()
        XCTAssertFalse(context.hasChanges)
        XCTAssertTrue(context.insertedModelsArray.isEmpty)
        XCTAssertEqual(try ModelContext(store).fetch(FetchDescriptor<CustomSkill>()).count, 0, "nothing stored")
    }

    /// *Save* on a temporary session says when it didn't save, so the screen can say so. In memory it's
    /// a saved routine either way, which is why a retry saves the context rather than calling this again.
    func testSavingATemporarySessionSaysWhenItFailed() throws {
        let saved = ModelContext(try container())
        let session = Routine(name: "Tuesday")
        session.isTemporary = true
        saved.insert(session)
        XCTAssertTrue(session.saveTemporary(in: saved))

        let refused = ModelContext(try ReadOnlyStore.container(for: [Routine.self, RoutineItem.self]))
        let other = Routine(name: "Wednesday")
        other.isTemporary = true
        refused.insert(other)
        XCTAssertFalse(other.saveTemporary(in: refused))
        XCTAssertFalse(other.isTemporary, "saved in memory, so the next save that works keeps it")
    }

    // MARK: - The switch a UI test fails a save with

    /// `-failSaveIn <file>` names a file only under `-uiTesting`, so no other launch fails a save.
    func testTheFailingSaveSwitchNeedsUITestingAndAFile() {
        let file = "Pocket/QuickJournalSheet.swift"
        XCTAssertEqual(UITestRuntime.parseFailSaveIn(in: ["app", "-uiTesting", "-failSaveIn", file]), file)
        XCTAssertNil(UITestRuntime.parseFailSaveIn(in: ["app", "-failSaveIn", file]), "not without -uiTesting")
        XCTAssertNil(UITestRuntime.parseFailSaveIn(in: ["app", "-uiTesting", "-failSaveIn"]), "not without a file")
        XCTAssertNil(UITestRuntime.parseFailSaveIn(in: ["app", "-uiTesting"]))
        XCTAssertNil(UITestRuntime.failingSaveFile, "the unit-test host names no file")
    }
}

/// A store that refuses saves, for a test of what a failed save does. SwiftData won't open an in-memory
/// store read-only, so this writes an empty store to a temporary file and opens it again with
/// `allowsSave: false`. The folder is left to the system's temporary-directory sweep.
enum ReadOnlyStore {
    @MainActor
    static func container(for types: [any PersistentModel.Type]) throws -> ModelContainer {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ReadOnlyStore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("read-only.store")
        let schema = Schema(types)
        do {
            let writable = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            try ModelContext(writable).save()
        }
        return try ModelContainer(for: schema,
                                  configurations: ModelConfiguration(schema: schema, url: url, allowsSave: false))
    }
}
