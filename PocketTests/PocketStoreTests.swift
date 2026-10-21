import SwiftData
import XCTest
@testable import Pocket

/// **The store stays where it has always been** (`PocketStore`). Since ADR 0264 the app has an App
/// Group, and SwiftData's default configuration moves the store into it: on the simulator the first
/// launch copied the whole library into the group container and ran from the copy. No in-memory test
/// can see that, so this pins the configuration itself.
///
/// It bites where the test host carries the group entitlement (a local simulator run). CI builds
/// unsigned, with no group, where both configurations resolve to the same place.
final class PocketStoreTests: XCTestCase {

    func testTheStoreIsInTheAppsOwnApplicationSupport() {
        let url = PocketStore.configuration.url
        XCTAssertEqual(url.standardizedFileURL,
                       URL.applicationSupportDirectory.appending(path: "default.store").standardizedFileURL)
        XCTAssertFalse(url.path.contains("/AppGroup/"), "the store must never be in a group container: \(url.path)")
    }

    func testTheStoreHoldsEveryModelTheAppDeclares() {
        let names = Set(PocketStore.models.map { String(describing: $0) })
        XCTAssertEqual(names.count, PocketStore.models.count, "no model listed twice")
        for model in ["Song", "Loop", "Exercise", "Routine", "ReferenceLink", "PracticeRun", "WrittenTab"] {
            XCTAssertTrue(names.contains(model), "\(model) is in the store")
        }
    }
}
