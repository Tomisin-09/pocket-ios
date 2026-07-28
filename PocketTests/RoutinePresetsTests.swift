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
        let spec = RoutinePresets.Spec(name: "Test", slug: "test",
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
            RoutinePresets.Spec(name: "Morning", slug: "morning", blocks: [.exercise("A")]),
            resolving: ["A": Exercise(name: "A")])
        XCTAssertEqual(routine?.name, "Morning")
    }

    // MARK: - Graceful degradation

    func testMissingExerciseBlockIsSkippedButRoutineStillBuilds() {
        let spec = RoutinePresets.Spec(name: "Test", slug: "test",
                                       blocks: [.exercise("A"), .exercise("gone"), .exercise("B")])
        let lookup = ["A": Exercise(name: "A"), "B": Exercise(name: "B")]
        let routine = RoutinePresets.makeRoutine(spec, resolving: lookup)
        let ordered = routine?.orderedItems ?? []
        XCTAssertEqual(ordered.count, 2, "the missing block is dropped, the rest survive")
        XCTAssertEqual(ordered.compactMap { $0.exercise?.name }, ["A", "B"])
        XCTAssertEqual(ordered.map(\.order), [0, 1], "order stays contiguous after a skip")
    }

    func testRoutineWithNoResolvableExerciseReturnsNil() {
        let spec = RoutinePresets.Spec(name: "Test", slug: "test",
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

    func testShippedRoutineSlugsAreUniqueAndNonEmpty() {
        let slugs = RoutinePresets.specs.map(\.slug)
        XCTAssertFalse(slugs.contains(where: \.isEmpty))
        XCTAssertEqual(Set(slugs).count, slugs.count, "slugs are the provenance key — no duplicates")
    }

    // MARK: - Provenance (ADR 0112)

    func testMakeRoutineStampsThePresetSlug() {
        let spec = RoutinePresets.Spec(name: "Test", slug: "test-slug", blocks: [.exercise("A")])
        let routine = RoutinePresets.makeRoutine(spec, resolving: ["A": Exercise(name: "A")])
        XCTAssertEqual(routine?.presetSlug, "test-slug")
    }

    func testBackfillSlugLookupMatchesByNameOnly() {
        XCTAssertEqual(RoutinePresets.slug(forName: "Morning Warm-up"), RoutinePresets.freeTasteSlug)
        XCTAssertEqual(RoutinePresets.slug(forName: "Picking Builder"), "picking-builder")
        XCTAssertNil(RoutinePresets.slug(forName: "My own routine"))
    }

    // MARK: - The free routine must stay clean

    /// **The invariant that keeps the paywall honest.** A free player may run Morning Warm-up, and the
    /// routine player embeds the *real* `ExerciseRunView` per block with no per-block entitlement
    /// check — so if a Pro-only drill ever lands in this routine, running it becomes a way to reach
    /// Pro content for free. Every exercise block must therefore be free-tier by template **or** one
    /// of the free-taste preset slugs. If this fails, either revert the block or add its slug to
    /// `AccessPolicy.freeTasteSlugs` deliberately.
    func testFreeTasteRoutineContainsOnlyFreelyRunnableExercises() throws {
        let spec = try XCTUnwrap(RoutinePresets.specs.first { $0.slug == RoutinePresets.freeTasteSlug })
        let names: [String] = spec.blocks.compactMap { block in
            if case .exercise(let name) = block { return name }
            return nil
        }
        XCTAssertFalse(names.isEmpty)

        for name in names {
            let preset = try XCTUnwrap(PracticePresets.allSpecs.first { $0.name == name },
                                       "\(name) is not a shipped preset — it can't be verified free")
            XCTAssertTrue(
                AccessPolicy.canRun(preset.template, isPro: false,
                                    isFreeTastePreset: AccessPolicy.isFreeTaste(slug: preset.slug)),
                "\(name) (\(preset.template), slug \(preset.slug)) is Pro — it leaks out of the free routine")
        }
    }

    /// The other two curated routines are the shop window — they are *expected* to contain Pro
    /// content. Pins that expectation so the free/paid contrast isn't lost by accident.
    func testTheOtherCuratedRoutinesDoReachProContent() throws {
        let others = RoutinePresets.specs.filter { $0.slug != RoutinePresets.freeTasteSlug }
        XCTAssertEqual(others.count, 2)
        for spec in others {
            let names: [String] = spec.blocks.compactMap { block in
                if case .exercise(let name) = block { return name }
                return nil
            }
            let reachesPro = names.contains { name in
                guard let preset = PracticePresets.allSpecs.first(where: { $0.name == name })
                else { return false }
                return !AccessPolicy.canRun(preset.template, isPro: false,
                                            isFreeTastePreset: AccessPolicy.isFreeTaste(slug: preset.slug))
            }
            XCTAssertTrue(reachesPro, "\(spec.name) should hold Pro content — it's the shop window")
        }
    }
}
