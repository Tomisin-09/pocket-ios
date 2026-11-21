import XCTest
@testable import Pocket

/// **Which goals a new drill would serve** (`DrillServes`, ADR 0309 D4): the line under *Works on* on the
/// create form. A goal reaches a drill through a shared skill, a met goal brings nothing into a session,
/// and the line says nothing at all rather than *serves no goals*.
final class DrillServesTests: XCTestCase {

    private let openMic = DrillServes.Goal(title: "Play at the open mic", skillIDs: ["repertoire.song"],
                                           isMet: false)
    private let looping = DrillServes.Goal(title: "Loop live", skillIDs: ["custom:looper", "timing.metronome"],
                                           isMet: false)
    private let finished = DrillServes.Goal(title: "Learn the solo", skillIDs: ["custom:looper"], isMet: true)

    // MARK: - Which goals

    func testAGoalOnAnyOfTheDrillsSkillsIsServed() {
        XCTAssertEqual(DrillServes.goals(for: ["timing.metronome"], among: [openMic, looping]), ["Loop live"])
    }

    func testAGoalSharingNoSkillIsNot() {
        XCTAssertEqual(DrillServes.goals(for: ["scale.pentatonic"], among: [openMic, looping]), [])
    }

    func testAMetGoalIsLeftOut() {
        XCTAssertEqual(DrillServes.goals(for: ["custom:looper"], among: [looping, finished]), ["Loop live"])
    }

    func testNoSkillsServeNothing() {
        XCTAssertEqual(DrillServes.goals(for: [], among: [openMic, looping]), [])
    }

    func testGoalsKeepTheOrderGivenAndAppearOnce() {
        // The form passes long-term goals in their rank, then the short-term ones; a name on both tiers
        // reads once.
        let again = DrillServes.Goal(title: "Loop live", skillIDs: ["repertoire.song"], isMet: false)
        XCTAssertEqual(DrillServes.goals(for: ["repertoire.song", "custom:looper"], among: [looping, openMic, again]),
                       ["Loop live", "Play at the open mic"])
    }

    // MARK: - The line

    func testTheLineNamesOneGoal() {
        XCTAssertEqual(DrillServes.line(["Play at the open mic"]), "Serves your goal Play at the open mic.")
    }

    func testTheLineJoinsTwoOrMore() {
        XCTAssertEqual(DrillServes.line(["A", "B"]), "Serves your goals A and B.")
        XCTAssertEqual(DrillServes.line(["A", "B", "C"]), "Serves your goals A, B and C.")
    }

    func testNoGoalsSayNothing() {
        XCTAssertNil(DrillServes.line([]))
    }
}
