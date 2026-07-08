import XCTest
@testable import Pocket

/// `RoutinePresets.makeRoutine` — the pure recipe→routine builder (ADR 0071). Exercised on plain
/// uninserted `@Model` objects (no store), per the "pure logic stays pure / stepping must be tested"
/// rule and to avoid the XCTest-host insert trap. Covers by-name resolution, order, rest inclusion,
/// graceful skipping of missing exercises, and the no-exercise → nil rule.
final class RoutinePresetsTests: XCTestCase {

    /// A lookup mapping every shipped preset name to a fresh uninserted exercise — the fresh-install
    /// case where all blocks resolve.
    private func fullLookup() -> [String: Exercise] {
        let names = Set(RoutinePresets.specs.flatMap { spec in
            spec.blocks.compactMap { block -> String? in
                if case .exercise(let name) = block { return name }
                return nil
            }
        })
        return Dictionary(uniqueKeysWithValues: names.map { ($0, Exercise(name: $0)) })
    }

    // MARK: - Full resolution (fresh install)

    func testEveryShippedRoutineBuildsWhenAllExercisesResolve() {
        let lookup = fullLookup()
        for spec in RoutinePresets.specs {
            XCTAssertNotNil(RoutinePresets.makeRoutine(spec, resolving: lookup),
                            "\(spec.name) should build when all its exercises resolve")
        }
    }

    func testBuiltRoutinePreservesBlockOrderAndContiguousOrder() {
        let spec = RoutinePresets.Spec(name: "Test",
                                       blocks: [.exercise("A"), .rest, .exercise("B")])
        let lookup = ["A": Exercise(name: "A"), "B": Exercise(name: "B")]
        guard let routine = RoutinePresets.makeRoutine(spec, resolving: lookup) else {
            return XCTFail("routine should build")
        }
        let ordered = routine.orderedItems
        XCTAssertEqual(ordered.count, 3)
        XCTAssertEqual(ordered.map(\.order), [0, 1, 2])
        XCTAssertEqual(ordered[0].exercise?.name, "A")
        XCTAssertEqual(ordered[1].kind, .rest)
        XCTAssertEqual(ordered[2].exercise?.name, "B")
    }

    func testBuiltRoutineNameMatchesSpec() {
        let routine = RoutinePresets.makeRoutine(
            RoutinePresets.Spec(name: "Morning", blocks: [.exercise("A")]),
            resolving: ["A": Exercise(name: "A")])
        XCTAssertEqual(routine?.name, "Morning")
    }

    // MARK: - Graceful degradation

    func testMissingExerciseBlockIsSkippedButRoutineStillBuilds() {
        let spec = RoutinePresets.Spec(name: "Test",
                                       blocks: [.exercise("A"), .exercise("gone"), .exercise("B")])
        let lookup = ["A": Exercise(name: "A"), "B": Exercise(name: "B")]
        let routine = RoutinePresets.makeRoutine(spec, resolving: lookup)
        let ordered = routine?.orderedItems ?? []
        XCTAssertEqual(ordered.count, 2, "the missing block is dropped, the rest survive")
        XCTAssertEqual(ordered.compactMap { $0.exercise?.name }, ["A", "B"])
        XCTAssertEqual(ordered.map(\.order), [0, 1], "order stays contiguous after a skip")
    }

    func testRoutineWithNoResolvableExerciseReturnsNil() {
        let spec = RoutinePresets.Spec(name: "Test",
                                       blocks: [.exercise("gone"), .rest, .exercise("also-gone")])
        XCTAssertNil(RoutinePresets.makeRoutine(spec, resolving: [:]),
                     "a routine that resolves no exercise (rests only) is not built")
    }

    // MARK: - Shipped set integrity

    func testShippedRoutinesAreNamedAndNonEmpty() {
        XCTAssertEqual(RoutinePresets.specs.count, 3)
        for spec in RoutinePresets.specs {
            XCTAssertFalse(spec.name.isEmpty)
            XCTAssertFalse(spec.blocks.isEmpty)
        }
    }
}
