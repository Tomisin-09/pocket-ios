import XCTest
@testable import Pocket

final class SongImporterTests: XCTestCase {

    func testTitleDropsPathAndExtension() {
        let url = URL(fileURLWithPath: "/Music/Imports/Little Wing.m4a")
        XCTAssertEqual(SongImporter.title(for: url), "Little Wing")
    }

    func testTitleHandlesNoExtension() {
        let url = URL(fileURLWithPath: "/Music/take 3")
        XCTAssertEqual(SongImporter.title(for: url), "take 3")
    }

    func testTitleFallsBackWhenNameIsEmpty() {
        // A path that reduces to an empty last component shouldn't yield "".
        let url = URL(fileURLWithPath: "/")
        XCTAssertEqual(SongImporter.title(for: url), "Untitled song")
    }
}
