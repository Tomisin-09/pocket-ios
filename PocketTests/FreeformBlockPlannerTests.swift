import XCTest
@testable import Pocket

/// ADR 0136 §F5 — the two planner claims about a **freeform** block. Both are the *existing* rules
/// applied rather than new ones, which is exactly why they need tests: neither is expressed by code
/// that mentions `.freeform`, so both would break silently. Goal-invisibility is an **absence** from
/// `SkillFamilyMap` (add a row and it quietly starts claiming skills it can't serve), and
/// due-scoring is a **non-membership** of the warm-up filter (add `.freeform` to that filter and
/// blocks stop resurfacing, with nothing to notice it).
///
/// Slice 2 is mostly this file. The net behaviour: a freeform block can be picked up by a goal-less
/// session and comes back round on time and rating, but never claims to satisfy a stated goal.
final class FreeformBlockPlannerTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func freeform(mastery: Int? = nil, lastPracticed: Date? = nil) -> PlannerExercise {
        PlannerExercise(uid: UUID(), template: .freeform, mastery: mastery,
                        lastPracticed: lastPracticed, estimatedMinutes: 10)
    }

    // MARK: - Goal-invisible (F5, first half)

    func testFreeformServesNoSkillAtAll() {
        // The app knows nothing about the content, so it cannot honestly claim the block serves any
        // skill. Asserted across the *whole* taxonomy rather than a sample, so a future row added to
        // `skillsByTemplate` fails here rather than shipping a silent claim.
        for skill in TechniqueTaxonomy.all {
            XCTAssertFalse(SkillFamilyMap.template(.freeform, serves: skill.id),
                           "freeform must not claim \(skill.id)")
        }
        XCTAssertNil(SkillFamilyMap.skillsByTemplate[.freeform])
    }

    func testNoSkillResolvesToAFreeformBlock() {
        for skill in TechniqueTaxonomy.all {
            XCTAssertFalse(SkillFamilyMap.templates(forSkill: skill.id).contains(.freeform),
                           "\(skill.id) must not resolve to a freeform block")
        }
    }

    func testAGoalDoesNotSurfaceAFreeformBlock() {
        // The behaviour the two claims above add up to: a technique goal whose only library unit is a
        // freeform block gets nothing, rather than a block that merely looks relevant.
        let library = PlannerLibrary(exercises: [freeform()])
        let goal = PlannerGoal(weight: 1.0, skillIDs: ["pick.alternate"],
                               targetSongUID: nil, isMet: false)
        XCTAssertTrue(CandidateDeriver.deriveCandidates(goals: [goal], library: library).isEmpty)
    }

    func testFreeformIsNotOfferedAsALoopSkillTag() {
        // `taggableTemplates` derives from `skillsByTemplate`, so this falls out of the omission —
        // but a loop tagged "Your own practice" would be a skill claim by the back door.
        XCTAssertFalse(SkillFamilyMap.taggableTemplates.contains(.freeform))
        XCTAssertFalse(SkillFamilyMap.suggestedLoopTags.contains(ExerciseTemplate.freeform.displayName))
    }

    // MARK: - Due-scored like any exercise (F5, second half)

    @MainActor
    func testFreeformSurvivesTheLibraryProjection() {
        // The claim that requires *not* extending an exclusion: `PracticePlanner.library` filters
        // warm-ups out of the candidate pool entirely, and `.freeform` must not join that filter.
        let block = Exercise.commandAnchored(name: "Sight-reading", command: 90, template: .freeform,
                                             notes: "Two pages, first time through only.")
        let warmUp = Exercise.commandAnchored(name: "Loosen up", command: 80, template: .warmup)
        let library = PracticePlanner.library(exercises: [block, warmUp])
        XCTAssertEqual(library.exercises.map(\.template), [.freeform],
                       "freeform must survive the pool; warm-up must not")
    }

    func testFreeformIsDueScoredOnTimeAndRating() {
        // `goalWeight × dueness × (1 − mastery/5)` works on it unmodified, which is the whole reason
        // F5 could be "the existing rules applied" rather than new machinery.
        let stale = DueScore.dueness(lastPracticed: now.addingTimeInterval(-30 * 86_400), now: now)
        let fresh = DueScore.dueness(lastPracticed: now, now: now)
        XCTAssertGreaterThan(stale, fresh)

        XCTAssertGreaterThan(DueScore.masteryTerm(1), DueScore.masteryTerm(5),
                             "a low self-rating must bring the block back sooner")
        XCTAssertEqual(DueScore.masteryTerm(nil), 1.0, accuracy: 1e-9,
                       "an unrated block is max-due, so a fresh one resurfaces rather than hiding")
    }

    // MARK: - It is an exercise everywhere else (F1 / F4a / F6)

    func testFreeformIsCreatableAndGroupsUnderItsOwnSection() {
        XCTAssertTrue(ExerciseTemplate.creatable.contains(.freeform))
        XCTAssertTrue(ExerciseTemplate.displayOrder.contains(.freeform))
        // Last in the create picker: it is the answer to "my practice isn't in this list", and
        // putting it first would invite it to become the default for drills that deserve a surface.
        XCTAssertEqual(ExerciseTemplate.creatable.last, .freeform)
    }

    func testFreeformIsNotTheUnknownTemplateFallback() {
        // F1c: `.basic` is what an unrecognised stored template decodes to. If freeform ever became
        // that, "the drill we couldn't parse" and "the drill the player defined" would be one value.
        XCTAssertEqual(ExerciseTemplate(storage: "not-a-template"), .basic)
        XCTAssertEqual(ExerciseTemplate(storage: "freeform"), .freeform)
    }

    func testAuthoringAFreeformBlockIsPro() {
        // F7 — creating one is authoring; running an existing one is free, the line every template
        // sits on.
        XCTAssertEqual(ExerciseTemplate.freeform.authoringTier, .pro)
    }

    func testFreeformCarriesItsInstructionsThroughCreation() {
        // The consequence the ADR flags as the worst possible failure: the instructions *are* the
        // exercise, so anything that builds one and drops them has lost the drill, not a detail.
        let block = Exercise.commandAnchored(name: "Transcribe", command: 90, template: .freeform,
                                             notes: "First eight bars of the solo, by ear only.")
        XCTAssertEqual(block.notes, "First eight bars of the solo, by ear only.")
        XCTAssertEqual(block.template, .freeform)
    }
}

/// ADR 0139 §O6 — a freeform block that **declares itself** instrument-free, and what that does to a
/// constrained pool. Separate from the block's own planner rules above because this is the seam
/// between two ADRs: 0136 supplies the container, 0139 supplies the one thing the player may say
/// about it. The whole point is that it is a *statement*, so the tests are mostly about what happens
/// when nobody made one.
final class FreeformOffInstrumentTests: XCTestCase {

    private func exercise(_ template: ExerciseTemplate, declared: Bool) -> PlannerExercise {
        PlannerExercise(uid: UUID(), template: template, mastery: nil, lastPracticed: nil,
                        estimatedMinutes: 10, awayFromInstrument: declared)
    }

    private func candidate(for projected: PlannerExercise) -> PlannerCandidate {
        PlannerCandidate(unit: PlannerUnitRef(projected.uid, .exercise), mastery: projected.mastery,
                         lastPracticed: projected.lastPracticed,
                         estimatedMinutes: projected.estimatedMinutes)
    }

    func testADeclaredFreeformBlockSurvivesTheOffGuitarConstraint() {
        // The slice's whole payoff: an off-guitar session can now be more than three ear blocks.
        let block = exercise(.freeform, declared: true)
        let library = PlannerLibrary(exercises: [block])
        let kept = CandidateDeriver.constrained([candidate(for: block)], to: .offGuitar,
                                                library: library)
        XCTAssertEqual(kept.map(\.unit.uid), [block.uid])
    }

    func testAnUndeclaredFreeformBlockIsDropped() {
        // Nothing is inferred from the prose (ADR 0136 F8). Silence means "I don't know", and the
        // honest answer to "I don't know" is to leave it out of a session built for a train.
        let block = exercise(.freeform, declared: false)
        let library = PlannerLibrary(exercises: [block])
        XCTAssertTrue(CandidateDeriver.constrained([candidate(for: block)], to: .offGuitar,
                                                   library: library).isEmpty)
    }

    func testAnOrdinaryExerciseIsStillDroppedEvenIfTheFlagIsSomehowSet() {
        // `declaresAwayFromInstrument` gates on the template, so a stray flag on a modelled drill
        // can't leak in. This guards the projection: only a freeform block should ever project true.
        let picking = exercise(.picking, declared: false)
        let library = PlannerLibrary(exercises: [picking])
        XCTAssertTrue(CandidateDeriver.constrained([candidate(for: picking)], to: .offGuitar,
                                                   library: library).isEmpty)
    }

    @MainActor
    func testOnlyAFreeformBlockCanDeclareItself() {
        let block = Exercise.commandAnchored(name: "Note names", command: 90, template: .freeform,
                                             notes: "Name every note on the E string, out loud.")
        block.awayFromInstrument = true
        XCTAssertTrue(block.declaresAwayFromInstrument)

        // The same flag on a modelled drill means nothing: the app knows that content, and all of it
        // wants the instrument in your hands.
        let picking = Exercise.commandAnchored(name: "Alternate picking", command: 120,
                                               template: .picking)
        picking.awayFromInstrument = true
        XCTAssertFalse(picking.declaresAwayFromInstrument)
    }

    @MainActor
    func testTheProjectionCarriesTheDeclaration() {
        // The seam that would break silently: `PracticePlanner.library` is the only writer of
        // `PlannerExercise.awayFromInstrument`, and a dropped field here empties every off-guitar
        // session of its freeform blocks with nothing to notice.
        let declared = Exercise.commandAnchored(name: "Transcribe", command: 90, template: .freeform,
                                                notes: "Eight bars, by ear.")
        declared.awayFromInstrument = true
        let quiet = Exercise.commandAnchored(name: "Sight-read", command: 90, template: .freeform,
                                             notes: "Two pages.")
        let library = PracticePlanner.library(exercises: [declared, quiet])
        XCTAssertEqual(library.exercises.first { $0.uid == declared.uid }?.awayFromInstrument, true)
        XCTAssertEqual(library.exercises.first { $0.uid == quiet.uid }?.awayFromInstrument, false)
    }

    func testAnUnconstrainedPoolIsUntouched() {
        // Every existing caller passes `.none`, and the fast path must stay byte-for-byte the session
        // it was — a freeform block is an ordinary exercise there.
        let block = exercise(.freeform, declared: false)
        let library = PlannerLibrary(exercises: [block])
        XCTAssertEqual(CandidateDeriver.constrained([candidate(for: block)], to: .none,
                                                    library: library).count, 1)
    }
}

/// The **optional click** on a freeform block (ADR 0136 F3's parked follow-up, pulled in 2026-08-04).
/// The tests that matter here are all one claim from different angles: a click tempo is **not** a
/// command tempo. Command tempo is an achievement that anchors a ramp, drives the promote offer and
/// feeds the planner; this is only how fast the click ticks. If those two ever merge, a freeform block
/// starts claiming it was practised *at* a speed — which is exactly what F3 and F4a rule out.
@MainActor
final class FreeformClickTests: XCTestCase {

    private func block(name: String = "Sight-reading") -> Exercise {
        Exercise.commandAnchored(name: name, command: 90, template: .freeform,
                                 notes: "Two pages, first time through only.")
    }

    func testAFreeformBlockStartsWithNoClick() {
        // Off by default: most freeform practice — reading, transcribing, working a piece by hand —
        // has no pulse at all, which is why F3 gave the template no tempo in the first place.
        XCTAssertFalse(block().clickEnabled)
        XCTAssertFalse(block().playsFreeformClick)
    }

    func testOnlyAFreeformBlockPlaysTheFreeformClick() {
        // Same template gate as `declaresAwayFromInstrument`: every other template drives its click
        // from the ramp, and must never pick up this one instead.
        let freeform = block()
        freeform.clickEnabled = true
        XCTAssertTrue(freeform.playsFreeformClick)

        let picking = Exercise.commandAnchored(name: "Alternate picking", command: 120,
                                               template: .picking)
        picking.clickEnabled = true
        XCTAssertFalse(picking.playsFreeformClick)
    }

    func testTheClickTempoIsIndependentOfTheCommandTempo() {
        // The load-bearing separation. Setting a click must not touch the tempo fields the ramp and
        // the planner read — nor the other way round.
        let freeform = block()
        let command = freeform.commandTempo
        let target = freeform.targetTempo
        freeform.clickEnabled = true
        freeform.clickBPM = 132
        XCTAssertEqual(freeform.commandTempo, command)
        XCTAssertEqual(freeform.targetTempo, target)
        XCTAssertEqual(freeform.clickBPM, 132)
    }

    func testTurningTheClickOnDoesNotMakeTheBlockGoalResolvable() {
        // A block with a tempo still isn't a drill: it must stay invisible to goals (F5) whether or
        // not it ticks, or the click would quietly buy it planner standing it hasn't earned.
        for skill in TechniqueTaxonomy.all {
            XCTAssertFalse(SkillFamilyMap.template(.freeform, serves: skill.id))
        }
    }

    func testTheClickDoesNotSurviveDuplicationAsATempoClaim() {
        // `duplicated(named:)` carries the click settings like any other authored value — what it
        // must not do is turn them into history. A copy is unrated and unpractised either way.
        let freeform = block()
        freeform.clickEnabled = true
        freeform.clickBPM = 108
        freeform.mastery = 4
        let copy = freeform.duplicated(named: "Sight-reading 2")
        XCTAssertNil(copy.mastery)
        XCTAssertNil(copy.lastPracticed)
    }
}

/// A freeform block has no command tempo and no ramp (ADR 0136 F3) — and the two places that
/// forgot it. One was visible on the device (rows printing "Command 75 → 80 BPM" for a drill with
/// neither), the other was not: the planner was **pricing** the block by a staircase it never climbs,
/// derived from a command tempo the player never set.
///
/// Both come from the same root: `commandAnchored` fills the tempo fields for every template, so a
/// freeform block *has* the values, and any code that reads them without asking gets a plausible
/// number rather than an error.
@MainActor
final class FreeformHasNoTempoTests: XCTestCase {

    private func block() -> Exercise {
        Exercise.commandAnchored(name: "Sight-reading", command: 90, template: .freeform,
                                 notes: "Two pages, first time through only.")
    }

    func testAFreeformBlockNeverStatesACommandTempo() {
        // The visible half. The label is the one string every unit row, the routine editor and the
        // player's "Up next" all read, so fixing it there fixes all four surfaces.
        XCTAssertFalse(block().commandProgressLabel.contains("Command"))
        XCTAssertFalse(block().commandProgressLabel.contains("BPM"))
    }

    func testAFreeformBlockWithAClickStatesTheClickInstead() {
        // Not blank for the sake of it: if the block has a pulse, saying so is both true and useful —
        // and "Metronome" can't be misread as the command tempo it deliberately isn't.
        let freeform = block()
        freeform.clickEnabled = true
        freeform.clickBPM = 96
        XCTAssertEqual(freeform.commandProgressLabel, "Metronome 96 BPM · 4/4")
    }

    func testAnOrdinaryExerciseStillStatesItsCommandTempo() {
        // The guard must be template-scoped: every other template's row is unchanged.
        XCTAssertTrue(Exercise.commandAnchored(name: "Picking", command: 120, template: .picking)
            .commandProgressLabel.contains("Command"))
    }

    func testAFreeformBlockIsNotPricedByItsPhantomRamp() {
        // The invisible half, and the one that would have silently misbuilt sessions. Its estimate
        // must not move with the tempo fields, because it doesn't run them.
        let slow = Exercise.commandAnchored(name: "Read", command: 40, template: .freeform)
        let fast = Exercise.commandAnchored(name: "Read", command: 200, template: .freeform)
        XCTAssertEqual(PracticePlanner.estimatedMinutes(for: slow),
                       PracticePlanner.estimatedMinutes(for: fast))
        XCTAssertEqual(PracticePlanner.estimatedMinutes(for: slow),
                       PracticePlanner.freeformDefaultMinutes)
    }

    func testInABlockAFreeformUnitIsPricedAtItsPlannedLength() {
        // ADR 0141's rule for a ramp-less block, applied to the exercise side: it runs for the time it
        // was given. Mirrors the loop side's `mode != .trainer` guard.
        XCTAssertEqual(PracticePlanner.estimatedMinutes(for: block(), plannedMinutes: 7), 7)
        XCTAssertEqual(PracticePlanner.estimatedMinutes(for: block(), plannedMinutes: nil),
                       PracticePlanner.freeformDefaultMinutes)
    }

    func testAnOrdinaryExerciseIsStillFittedToItsBlock() {
        // The guard must not have disabled ADR 0129's fit for everything else.
        let picking = Exercise.commandAnchored(name: "Picking", command: 120, template: .picking)
        XCTAssertEqual(PracticePlanner.estimatedMinutes(for: picking, plannedMinutes: 6),
                       SessionEstimate.effectiveMinutes(forRamp: picking.ramp, plannedMinutes: 6,
                                                        beatsPerBar: picking.beatsPerBar))
    }
}
