import SwiftData
import XCTest
@testable import Pocket

/// The long-term goal model, its ordering store, and the read-only Progress echo (ADR 0171).
///
/// `LongTermGoal` is a `@Model`, but every object here is **uninserted** — the XCTest host's
/// container has its own traps (`docs/swiftdata-gotchas.md`) and none of this behaviour needs a
/// store: `order` is a plain attribute and the store helpers are pure list arithmetic.
final class LongTermGoalTests: XCTestCase {

    private func goal(_ title: String, order: Int, skills: [String] = ["pick.alternate"],
                      isMet: Bool = false) -> LongTermGoal {
        LongTermGoal(title: title, skillIDs: skills, order: order, isMet: isMet)
    }

    // MARK: - The absent field

    /// The decision this tier turns on (ADR 0171 D1): **there is no date to be late against.** A
    /// reflective property is only structural if the column doesn't exist, so this pins the shape of
    /// the model rather than a behaviour — if someone adds a deadline, this is what says no.
    func testTheModelCarriesNoHorizonOfAnyKind() {
        let mirror = Mirror(reflecting: goal("Play a song", order: 0))
        let dateFields = mirror.children.compactMap(\.label).filter { label in
            ["deadline", "targetDate", "dueDate", "horizon", "byWhen", "endDate"].contains(label)
        }
        XCTAssertTrue(dateFields.isEmpty, "a long-term goal must have no horizon: found \(dateFields)")
    }

    // MARK: - Projection

    func testProjectionTakesItsWeightFromRankNotFromAStoredField() {
        XCTAssertEqual(goal("Top", order: 0).plannerProjection.weight,
                       LongTermRank.weight(forOrder: 0), accuracy: 0.0001)
        XCTAssertEqual(goal("Third", order: 2).plannerProjection.weight,
                       LongTermRank.weight(forOrder: 2), accuracy: 0.0001)
    }

    /// The projection carries the goal's own `uid`, because `SessionBuilder.roundRobin` deals on it
    /// — two goals sharing a uid would collapse into one and silently lose a share of the session.
    func testProjectionCarriesTheGoalsOwnIdentity() {
        let one = goal("One", order: 0), two = goal("Two", order: 1)
        XCTAssertEqual(one.plannerProjection.uid, one.uid)
        XCTAssertNotEqual(one.plannerProjection.uid, two.plannerProjection.uid)
    }

    func testProjectionCarriesMetSoTheDeriverCanSkipIt() {
        XCTAssertTrue(goal("Done", order: 0, isMet: true).plannerProjection.isMet)
    }

    // MARK: - Ordering

    func testRankOrderSortsByOrderRegardlessOfInsertionOrder() {
        let third = goal("Third", order: 2), first = goal("First", order: 0), second = goal("Second", order: 1)
        XCTAssertEqual(LongTermGoalStore.inRankOrder([third, first, second]).map(\.title),
                       ["First", "Second", "Third"])
    }

    func testMovingRenumbersContiguouslyFromZero() {
        let goals = (0..<4).map { goal("G\($0)", order: $0) }
        LongTermGoalStore.move(from: IndexSet(integer: 3), to: 0, in: goals)
        XCTAssertEqual(LongTermGoalStore.inRankOrder(goals).map(\.title), ["G3", "G0", "G1", "G2"])
        XCTAssertEqual(LongTermGoalStore.inRankOrder(goals).map(\.order), [0, 1, 2, 3])
    }

    /// A gap in `order` is not cosmetic: `LongTermRank` steps per position, so a hole would make two
    /// adjacent goals pull as if a rank apart when they aren't.
    func testRenumberClosesGapsLeftByADelete() {
        let survivors = [goal("A", order: 0), goal("C", order: 2), goal("D", order: 5)]
        LongTermGoalStore.renumber(survivors)
        XCTAssertEqual(survivors.map(\.order), [0, 1, 2])
    }

    func testRankingOmitsMetGoals() {
        let live = goal("Live", order: 0)
        let done = goal("Done", order: 1, isMet: true)
        let alsoLive = goal("Also live", order: 2)
        XCTAssertEqual(LongTermGoalStore.ranking([live, done, alsoLive]), [live.uid, alsoLive.uid])
    }

    // MARK: - The Progress echo

    private func library(lastPracticed: Date?) -> PlannerLibrary {
        PlannerLibrary(exercises: [PlannerExercise(uid: UUID(), template: .picking, mastery: 2,
                                                   lastPracticed: lastPracticed, estimatedMinutes: 10)])
    }

    func testEchoReportsWhenSomethingServingTheGoalWasLastPractised() {
        let served = Date(timeIntervalSince1970: 1_700_000_000)
        let projection = goal("Build speed", order: 0, skills: ["pick.alternate"]).plannerProjection
        let readings = LongTermGoalEcho.readings(for: [projection],
                                                 library: library(lastPracticed: served))
        XCTAssertEqual(readings.count, 1)
        XCTAssertEqual(readings[0].lastServed, served)
        XCTAssertEqual(readings[0].skillCount, 1)
    }

    func testEchoReportsNotYetWhenNothingServingTheGoalHasBeenPractised() {
        let projection = goal("Build speed", order: 0, skills: ["pick.alternate"]).plannerProjection
        let readings = LongTermGoalEcho.readings(for: [projection], library: library(lastPracticed: nil))
        XCTAssertNil(readings[0].lastServed, "never practised reads as 'not yet', not as a zero")
    }

    /// The reason goals are derived one at a time. `deriveCandidates` keeps only the strongest claim
    /// on a unit, so deriving the list in one pass would let the top-ranked goal take sole credit for
    /// shared material — and the echo would say "not yet" about a goal the player served this morning.
    func testTwoGoalsSharingMaterialAreBothCredited() {
        let served = Date(timeIntervalSince1970: 1_700_000_000)
        let projections = [goal("First", order: 0, skills: ["pick.alternate"]).plannerProjection,
                           goal("Second", order: 1, skills: ["pick.economy"]).plannerProjection]
        let readings = LongTermGoalEcho.readings(for: projections,
                                                 library: library(lastPracticed: served))
        XCTAssertEqual(readings.map(\.lastServed), [served, served])
    }

    /// The echo must never gain a denominator (ADR 0171 D7) — a skill **count** is a fact about the
    /// goal; a count over a total would state a target, and a target is habit-pressure.
    func testEchoCarriesNoTotalToDivideBy() {
        let projection = goal("Broad", order: 0,
                              skills: ["pick.alternate", "pick.economy", "fret.legato"]).plannerProjection
        let reading = LongTermGoalEcho.readings(for: [projection], library: library(lastPracticed: nil))[0]
        XCTAssertEqual(reading.skillCount, 3)
        let fields = Mirror(reflecting: reading).children.compactMap(\.label)
        XCTAssertEqual(Set(fields), ["goalUID", "skillCount", "lastServed"],
                       "no covered/total/percentage may appear on a reading")
    }
}
