#if DEBUG
import Foundation
import SwiftData

/// The two things a player **authors** that `PracticeHistorySeed` did not write — long-term goals
/// and routines beyond the seeded one (ADR 0165, Phase 5).
///
/// Split from `PracticeHistorySeed` because that file is at the 400-line cap, not because these are
/// a different kind of thing: they are the same argument one step further on. That seed exists
/// because `PracticeRun` and `JournalEntry` only ever appear once someone has used the app, so the
/// screens that read them photograph empty on a fresh install. A `LongTermGoal` is in exactly that
/// position — ADR 0171 shipped the screen and the marker for it (`reference/long-term-goals`, "two
/// goals ranked") and nothing in either seed writes one, so the figure would have come back showing
/// *Nothing here yet*: a clean photograph of the empty state, filed under a page describing the
/// full one, with nothing in the run objecting.
///
/// That is the same failure ADR 0173 caught one ADR earlier, when the routine history section would
/// have been photographed empty in every figure of the routine detail screen. The pattern is worth
/// naming: **a feature that ships a screen ships a seed for it**, or the shoot documents its empty
/// state by default.
///
/// Deterministic, like everything in the parent seed — fixed titles, fixed order, fixed day offsets
/// — so two shoots produce identical figures.
extension PracticeHistorySeed {

    // MARK: - Long-term goals

    /// Two ranked goals, one of each shape the tier supports (ADR 0171).
    ///
    /// **Path A and Path B, in that order.** A goal carrying only skills and a goal pointing at a
    /// song read differently on the row — the second carries its song after the skill count — and a
    /// figure showing two of the same shape cannot show that. Rank 1 is the skills-only one so the
    /// list does not open on its own special case.
    ///
    /// `order` is 0 and 1 rather than anything sparser: `LongTermGoalStore.move` renumbers
    /// contiguously, so a seed leaving gaps would be a store shape the app never produces.
    ///
    /// Skill ids are checked against `TechniqueTaxonomy` at insert rather than trusted. A typo'd id is
    /// not a crash — it is a goal that derives no candidates and a row whose skill count is one
    /// short — which is precisely the kind of wrong a photograph records without complaint.
    @MainActor
    static func seedLongTermGoals(songs: [Song], into context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<LongTermGoal>())) ?? 0
        guard existing == 0 else { return }

        // Pinned by title, like `seedReferences`' exercise: an unsorted fetch returns store order,
        // and a figure whose subject can move goes wrong without anything failing.
        let demoSong = songs.first { $0.title == "Slow Bend" }

        let specs = [
            GoalSpec(title: "Improvise over a blues without thinking about it",
                     skillIDs: ["scale.pentatonic", "scale.blues", "improv.vocabulary"],
                     targetSong: nil),
            GoalSpec(title: "Play Slow Bend end to end",
                     skillIDs: ["rep.learn-song", "fret.slide", "rhythm.chord-changes"],
                     targetSong: demoSong)
        ]

        for (index, spec) in specs.enumerated() {
            let known = spec.skillIDs.filter { TechniqueTaxonomy.info($0) != nil }
            assert(known.count == spec.skillIDs.count,
                   "seeded long-term goal '\(spec.title)' names a skill id the taxonomy does not have")
            let goal = LongTermGoal(title: spec.title,
                                    skillIDs: known,
                                    order: index,
                                    targetSong: spec.targetSong)
            // Older than the practice history, so the goals read as standing intent rather than
            // something set up this morning. Nothing computes lateness from this (ADR 0171 D1) —
            // it is a record, and the list does not show it at all.
            goal.dateAdded = dayBefore(daysAgo: 48) ?? .now
            context.insert(goal)
        }
    }

    // MARK: - Routines

    /// Two hand-built routines beside the seeded **Morning Routine**.
    ///
    /// `routines/library` asks for "several routines saved" and a fresh install arrives with exactly
    /// one (ADR 0112), so the figure would have shown a one-row list under a page describing a
    /// library. One row also hides the thing the row is *for*: Morning Routine carries a history
    /// line and these two do not, and a reader cannot tell that the line is conditional from a
    /// screenshot of the only routine that has one.
    ///
    /// **No practice-log rows are written for these**, deliberately. `routineDayOffsets` in the
    /// parent seed picks out Morning Routine's sittings, and giving all three a history would make
    /// the second line look unconditional — the opposite of the state the marker asks for.
    ///
    /// **Blocks resolve by `presetSlug`, against `PracticePresets.firstRunSlugs`, and assert.** The
    /// first version matched on display name and skipped what it could not find, which is how the
    /// first shoot filed a `Blues, week three` reading `1 block`: it asked for "Scale Runs", a spec
    /// that is in `allSpecs` but **not** in the six a fresh install seeds, so the exercise silently
    /// no-matched, the rest that follows it was never appended, and the routine went in holding the
    /// loop alone. Nothing failed — a `continue` is invisible, and the row it produced looked like a
    /// short routine rather than a broken one.
    ///
    /// Slugs are the frozen ids (ADR 0112) and names are not, so this cannot drift the same way
    /// again; the assert is there because the seed's whole output is photographs, and the difference
    /// between "this routine has two blocks" and "this routine has one" is invisible to every check
    /// the shoot runs.
    @MainActor
    static func seedRoutines(exercises: [Exercise], loops: [Loop], into context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        // Guarded on *these two* rather than on the count, so a store already holding the preset
        // routine is still topped up — the parent seed's guard is the run count, and this runs
        // beside it rather than under it.
        let names = Set(existing.map(\.name))
        let specs = [
            RoutineSpec(name: "Evening technique",
                        slugs: ["spider-walk", "alternate-picking"], loops: 0),
            RoutineSpec(name: "Blues, week three", slugs: ["a-minor-pentatonic"], loops: 1)
        ]

        for (index, spec) in specs.enumerated() {
            guard !names.contains(spec.name) else { continue }

            let routine = Routine(name: spec.name)
            routine.dateAdded = dayBefore(daysAgo: index + 2) ?? .now

            var items: [RoutineItem] = []
            for slug in spec.slugs {
                assert(PracticePresets.firstRunSlugs.contains(slug),
                       "seeded routine '\(spec.name)' names '\(slug)', which a fresh install does "
                       + "not seed — the block would be dropped and the figure would be wrong")
                guard let exercise = exercises.first(where: { $0.presetSlug == slug }) else { continue }
                items.append(.item(exercise, order: items.count))
            }
            // A rest between the drills and the loop — the shape the page describes, and the one
            // that makes the row's "· 1 rest" half of the summary non-zero on at least one routine
            // that is not the preset.
            if !items.isEmpty && spec.loops > 0 {
                items.append(RoutineItem(kind: .rest, order: items.count))
            }
            for loop in loops.prefix(spec.loops) {
                items.append(.item(loop, order: items.count))
            }

            guard items.contains(where: { $0.kind.carriesUnit }) else { continue }
            // Each item inserted explicitly, as `RoutinePresets.seedIfNeeded` does. Cascade from
            // the routine's insert does carry them in — that was verified on a real store — so this
            // is the house pattern rather than a fix for anything.
            routine.items = items
            context.insert(routine)
            for item in items {
                item.routine = routine
                context.insert(item)
            }
        }
    }

    // MARK: - Specs

    /// One seeded long-term goal. A named type rather than a tuple because the third member is a
    /// `Song?` and `spec.2` at the call site says nothing about which of the two shapes it is.
    private struct GoalSpec {
        let title: String
        let skillIDs: [String]
        let targetSong: Song?
    }

    /// One seeded routine. Exercises are named by **frozen preset slug**, never by display name: a
    /// name is copy and moves, a slug is an id and does not (ADR 0112).
    private struct RoutineSpec {
        let name: String
        let slugs: [String]
        let loops: Int
    }

    // MARK: - Dates

    /// Midnight, `daysAgo` days back — the parent seed's `calendarDay` is `private` and Swift has no
    /// cross-file-private, so this is its twin rather than a second definition of the rule: both
    /// anchor to the start of a day so a shoot running at 23:55 doesn't drop a date into tomorrow.
    static func dayBefore(daysAgo: Int) -> Date? {
        let today = Calendar.current.startOfDay(for: .now)
        return Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)
    }
}
#endif
