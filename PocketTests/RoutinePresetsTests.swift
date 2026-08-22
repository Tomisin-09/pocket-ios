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
        XCTAssertEqual(RoutinePresets.specs.count, 1, "one curated routine ships: the demo")
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

    // MARK: - Description (ADR 0177)

    func testMakeRoutineSeedsTheSpecDescription() {
        let spec = RoutinePresets.Spec(name: "Test", slug: "test-slug",
                                       notes: "What this session is for.", blocks: [.exercise("A")])
        let routine = RoutinePresets.makeRoutine(spec, resolving: ["A": Exercise(name: "A")])
        XCTAssertEqual(routine?.notes, "What this session is for.")
    }

    /// A spec that states no description seeds an empty one, not the string `"nil"` or a
    /// placeholder — the routine simply arrives without prose, as a hand-built one does.
    func testASpecWithoutADescriptionSeedsAnEmptyOne() {
        let spec = RoutinePresets.Spec(name: "Test", slug: "test-slug", blocks: [.exercise("A")])
        let routine = RoutinePresets.makeRoutine(spec, resolving: ["A": Exercise(name: "A")])
        XCTAssertEqual(routine?.notes, "")
    }

    /// The starter routine is the demo shown whole, so it must actually demonstrate the field.
    func testEveryShippedRoutineCarriesADescription() {
        for spec in RoutinePresets.specs {
            XCTAssertFalse(spec.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "\(spec.name) ships with no description")
        }
    }

    func testBackfillSlugLookupMatchesByNameOnly() {
        XCTAssertEqual(RoutinePresets.slug(forName: "Morning Routine"), RoutinePresets.freeTasteSlug)
        XCTAssertNil(RoutinePresets.slug(forName: "My own routine"))
        // A retired curated routine is no longer recognised — an existing player's copy stays
        // unslugged and therefore Pro, which is right: only the demo is free.
        XCTAssertNil(RoutinePresets.slug(forName: "Picking Builder"))
    }

    /// The rename trap: an install seeded before "Morning Warm-up" became "Morning Routine" still
    /// holds the old name, and the backfill matches by name. Without the legacy table it would never
    /// be stamped and the demo would **Pro-lock on every existing install**.
    func testBackfillStillRecognisesTheOldNameAfterARename() {
        XCTAssertEqual(RoutinePresets.slug(forName: "Morning Warm-up"), RoutinePresets.freeTasteSlug)
    }

    /// Every legacy name must map to a slug some shipped spec actually uses — otherwise the table has
    /// drifted and is stamping provenance nothing recognises.
    func testEveryLegacyNameMapsToALiveSlug() {
        let live = Set(RoutinePresets.specs.map(\.slug))
        for (name, slug) in RoutinePresets.legacyNameSlugs {
            XCTAssertTrue(live.contains(slug), "legacy name \(name) maps to dead slug \(slug)")
        }
    }

    /// The slug is frozen across the rename — that's the whole point of having one.
    func testFreeTasteSlugIsUnchangedByTheRename() {
        XCTAssertEqual(RoutinePresets.freeTasteSlug, "morning-warm-up")
        XCTAssertEqual(RoutinePresets.specs.first?.name, "Morning Routine")
    }

    // MARK: - The routine-bypass invariant (ADR 0144)

    /// **Retired as a bypass, kept as a seam guard.** Under ADR 0112 this test carried real weight:
    /// a free player could run Morning Routine, and the routine player embeds the *real*
    /// `ExerciseRunView` per block with no per-block entitlement check — so a Pro drill landing in
    /// that routine became a way to reach Pro content for free.
    ///
    /// ADR 0144 closed the bypass by closing the door it went through: **no routine runs without
    /// Pro**, so there is nothing left to leak out of. What's pinned now is the other half — the
    /// starter routine's blocks are all shipped presets (so they resolve at seed time), and running
    /// it requires Pro like everything else. Re-open a free routine allowance and the
    /// `canRun`-per-block loop is what has to come back with it.
    func testStarterRoutineBlocksAreShippedPresetsAndNeedPro() throws {
        let spec = try XCTUnwrap(RoutinePresets.specs.first { $0.slug == RoutinePresets.freeTasteSlug })
        let names: [String] = spec.blocks.compactMap { block in
            if case .exercise(let name) = block { return name }
            return nil
        }
        XCTAssertFalse(names.isEmpty)

        XCTAssertFalse(AccessPolicy.canRunRoutine(
            isPro: false,
            isFreeTasteRoutine: AccessPolicy.isFreeTasteRoutine(slug: spec.slug)),
            "The starter routine is trial content (ADR 0144 D8), not a free taste")

        for name in names {
            let preset = try XCTUnwrap(PracticePresets.allSpecs.first { $0.name == name },
                                       "\(name) is not a shipped preset — it would never resolve")
            XCTAssertFalse(
                AccessPolicy.canRun(preset.template, isPro: false,
                                    isFreeTastePreset: AccessPolicy.isFreeTaste(slug: preset.slug)),
                "\(name) (\(preset.template)) must not run without Pro")
        }
    }

    /// Every block in the shipped routine must name an exercise a **fresh install actually seeds**.
    /// Blocks resolve by name at seed time, so a drill missing from `firstRunSlugs` doesn't error —
    /// it's silently skipped, and the demo arrives with holes in it. This is the guard for that.
    func testEveryRoutineBlockIsSeededOnAFreshInstall() throws {
        let firstRunNames = Set(PracticePresets.firstRunSpecs.map(\.name))
        for spec in RoutinePresets.specs {
            for block in spec.blocks {
                guard case .exercise(let name) = block else { continue }
                XCTAssertTrue(firstRunNames.contains(name),
                              "\(spec.name) block \"\(name)\" is not in the first-run seed set — "
                              + "it would be skipped, leaving the routine short a block")
            }
        }
    }
}
