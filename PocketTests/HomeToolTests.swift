import XCTest
@testable import Pocket

/// The tile beside Toolkit (ADR 0235 D6): what it opens when nothing's been chosen, when a stored value is
/// one this build doesn't know, its *Hold to change* caption, and the reset UI tests launch with.
final class HomeToolTests: XCTestCase {

    func testItOpensMyTabsUntilChanged() {
        XCTAssertEqual(AppSettings.homeToolDefault, .myTabs)
        XCTAssertEqual(AppSettings.resolvedHomeTool(storedValue: nil), .myTabs)
    }

    func testAChoiceIsKeptAndAnUnknownOneOpensMyTabs() {
        XCTAssertEqual(AppSettings.resolvedHomeTool(storedValue: "tuner"), .tuner)
        XCTAssertEqual(AppSettings.resolvedHomeTool(storedValue: "help"), .help)
        XCTAssertEqual(AppSettings.resolvedHomeTool(storedValue: "metronome"), .myTabs,
                       "a value a later build wrote opens something real, not nothing")
        XCTAssertEqual(AppSettings.resolvedHomeTool(storedValue: ""), .myTabs)
    }

    func testTheCaptionGoesOnceTheTileHasBeenChanged() {
        XCTAssertEqual(AppSettings.homeToolCaption(chosen: false), "Hold to change")
        XCTAssertNil(AppSettings.homeToolCaption(chosen: true))
    }

    func testTheResetClearsTheChoiceAndTheCaptionsMemory() throws {
        let store = try XCTUnwrap(UserDefaults(suiteName: #function))
        store.removePersistentDomain(forName: #function)
        store.set("glossary", forKey: AppSettings.Key.homeTool)
        store.set(true, forKey: AppSettings.Key.homeToolChosen)
        AppSettings.resetHomeTool(store: store)
        XCTAssertNil(store.string(forKey: AppSettings.Key.homeTool))
        XCTAssertNil(store.object(forKey: AppSettings.Key.homeToolChosen))
        store.removePersistentDomain(forName: #function)
    }

    func testTheTwoKeysAreTheirOwn() {
        let keys = [AppSettings.Key.homeTool, AppSettings.Key.homeToolChosen, AppSettings.Key.jumpBackIn]
        XCTAssertEqual(Set(keys).count, keys.count)
    }
}
