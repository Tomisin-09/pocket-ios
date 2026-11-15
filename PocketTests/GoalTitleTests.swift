import XCTest
@testable import Pocket

/// A goal's name on screen (ADR 0298 D1): two goals made from *Play a specific song* read as their
/// songs, and a name the player typed is never overwritten.
final class GoalTitleTests: XCTestCase {

    func testThePlaceholderReadsAsItsSong() {
        XCTAssertEqual(GoalTitle.display("Play a specific song", songTitle: "Sunday Morning"),
                       "Play Sunday Morning")
        XCTAssertEqual(GoalTitle.display("Play a specific song", songTitle: "Self Control"),
                       "Play Self Control", "two goals from one template no longer share a name")
    }

    func testATypedNameIsShownAsTyped() {
        XCTAssertEqual(GoalTitle.display("Open mic set", songTitle: "Sunday Morning"), "Open mic set")
    }

    func testWithNoSongThePlaceholderStays() {
        XCTAssertEqual(GoalTitle.display("Play a specific song", songTitle: nil), "Play a specific song")
        XCTAssertEqual(GoalTitle.display("Play a specific song", songTitle: "  "), "Play a specific song",
                       "an untitled song gives the name nothing to say")
    }

    func testAnEmptyNameFallsBackToTheSongThenToUntitled() {
        XCTAssertEqual(GoalTitle.display("", songTitle: "Frontin'"), "Play Frontin'")
        XCTAssertEqual(GoalTitle.display(" ", songTitle: nil), "Untitled goal")
    }

    func testThePlaceholderIsTheSongTemplatesTitle() {
        XCTAssertEqual(GoalTitle.placeholder, GoalTemplateLibrary.template("play-song")?.title)
    }

    // MARK: - The editor's field

    func testTheFieldFollowsTheSongWhileTheAppChoseTheName() {
        XCTAssertEqual(GoalTitle.following("Play a specific song", from: nil, to: "Sunday Morning"),
                       "Play Sunday Morning")
        XCTAssertEqual(GoalTitle.following("Play Sunday Morning", from: "Sunday Morning", to: "Self Control"),
                       "Play Self Control", "the name it gave the last song follows the next")
        XCTAssertEqual(GoalTitle.following("", from: nil, to: "Sunday Morning"), "Play Sunday Morning")
    }

    func testTheFieldLeavesATypedNameAlone() {
        XCTAssertEqual(GoalTitle.following("Open mic set", from: "Sunday Morning", to: "Self Control"),
                       "Open mic set")
        XCTAssertEqual(GoalTitle.following("Play Sunday Morning", from: nil, to: "Self Control"),
                       "Play Sunday Morning",
                       "opening a saved goal: a name matching no previous song is the player's")
    }

    func testClearingTheSongPutsThePlaceholderBack() {
        XCTAssertEqual(GoalTitle.following("Play Sunday Morning", from: "Sunday Morning", to: nil),
                       "Play a specific song")
        XCTAssertEqual(GoalTitle.following("", from: nil, to: nil), "",
                       "an empty field stays empty; saving supplies the template's name")
    }
}
