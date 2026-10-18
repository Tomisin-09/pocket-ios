import XCTest
@testable import Pocket

/// The detail sheets' derived text (ADR 0258): song details' facts line and the category rows' values.
final class DetailSheetTextTests: XCTestCase {

    func testFactsJoinsWhatIsKnown() {
        XCTAssertEqual(DetailSheetText.facts(key: "F# Minor", tempo: "83 BPM", length: "3:24"),
                       "F# Minor · 83 BPM · 3:24")
    }

    func testFactsLeavesOutWhatIsNot() {
        XCTAssertEqual(DetailSheetText.facts(key: nil, tempo: "83 BPM", length: "3:24"), "83 BPM · 3:24")
        XCTAssertEqual(DetailSheetText.facts(key: "A Minor", tempo: nil, length: "0:41"), "A Minor · 0:41")
        XCTAssertEqual(DetailSheetText.facts(key: "", tempo: nil, length: "0:41"), "0:41")
    }

    func testFactsIsEmptyWhenNothingIsKnown() {
        XCTAssertEqual(DetailSheetText.facts(key: nil, tempo: nil, length: nil), "")
    }

    func testLoopsCountsAndSaysNone() {
        XCTAssertEqual(DetailSheetText.loops(0), "No loops")
        XCTAssertEqual(DetailSheetText.loops(1), "1 loop")
        XCTAssertEqual(DetailSheetText.loops(4), "4 loops")
    }

    func testReferencesCountsLinksAndFilesApart() {
        XCTAssertEqual(DetailSheetText.references(links: 0, files: 0), "None")
        XCTAssertEqual(DetailSheetText.references(links: 1, files: 0), "1 link")
        XCTAssertEqual(DetailSheetText.references(links: 2, files: 0), "2 links")
        XCTAssertEqual(DetailSheetText.references(links: 0, files: 1), "1 file")
        XCTAssertEqual(DetailSheetText.references(links: 1, files: 3), "1 link · 3 files")
    }

    func testWorksOnCountsSkillsAndTagsApart() {
        XCTAssertEqual(DetailSheetText.worksOn(skills: 0, tags: 0), "None")
        XCTAssertEqual(DetailSheetText.worksOn(skills: 2, tags: 0), "2 skills")
        XCTAssertEqual(DetailSheetText.worksOn(skills: 0, tags: 1), "1 tag")
        XCTAssertEqual(DetailSheetText.worksOn(skills: 1, tags: 2), "1 skill · 2 tags")
    }
}
