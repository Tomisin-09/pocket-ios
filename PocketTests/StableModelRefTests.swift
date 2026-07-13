import XCTest
@testable import Pocket

/// The loop/marker edit sheets present through a `uid`-keyed `StableRef` so a SwiftData autosave
/// promoting a freshly-inserted model's `persistentModelID` can't read as an identity change and
/// dismiss the sheet mid-edit. These lock the one invariant that fix rests on: the ref's `id` is the
/// model's stable `uid`, and never its (mutable) `persistentModelID`. Uses uninserted `@Model`
/// objects (property-logic only — no `ModelContext`, which traps in the test host).
final class StableModelRefTests: XCTestCase {

    func testLoopRefIDIsTheLoopUID() {
        let loop = Loop(name: "riff", start: 0.1, end: 0.2, speed: 1, repeats: 1)
        XCTAssertEqual(StableRef(value: loop).id, loop.uid)
    }

    func testMarkerRefIDIsTheMarkerUID() {
        let marker = Marker(seconds: 12, label: "chorus")
        XCTAssertEqual(StableRef(value: marker).id, marker.uid)
    }

    func testDistinctLoopsGetDistinctRefIDs() {
        let first = Loop(name: "a", start: 0.1, end: 0.2, speed: 1, repeats: 1)
        let second = Loop(name: "b", start: 0.3, end: 0.4, speed: 1, repeats: 1)
        XCTAssertNotEqual(StableRef(value: first).id, StableRef(value: second).id)
    }
}
