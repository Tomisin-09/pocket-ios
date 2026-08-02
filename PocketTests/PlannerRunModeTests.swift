import SwiftData
import XCTest
@testable import Pocket

/// **A planned loop keeps the mode it was planned for** — ADR 0135 Slice 3 (backing tracks reach the
/// planner) and ADR 0139 Slice 1 (the away-from-your-instrument session), built adjacently because
/// they share one structural change: `LoopRunMode` surviving the trip candidate → block →
/// `RoutineItem`.
///
/// Everything here fails **silently** without a test. A dropped mode doesn't crash: it materialises a
/// trainer block, which hands the player a ramp built from a command tempo a backing track was never
/// required to have. A missing resolution doesn't crash either — it produces a goal that still looks
/// like it works, because its other skills resolve. Both holes this closes were live in shipped code
/// for exactly that reason.
final class PlannerRunModeTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// A projected loop, described by what it can be *run as* rather than by what it is — the same
    /// facts `LoopModeAccess` gates the run screens on.
    private func loop(uid: UUID = UUID(), songUID: UUID? = nil, mastery: Int? = nil,
                      lastPracticed: Date? = nil, tempo: Bool = true, audio: Bool = true,
                      backing: Bool = false, templates: [ExerciseTemplate] = []) -> PlannerLoop {
        PlannerLoop(uid: uid, songUID: songUID, mastery: mastery, lastPracticed: lastPracticed,
                    estimatedMinutes: 4, templates: templates,
                    modeFacts: .init(hasCommandTempo: tempo, audioResolves: audio,
                                     isBackingTrack: backing))
    }

    private func goal(weight: Double = 1.0, skills: [String], song: UUID? = nil) -> PlannerGoal {
        PlannerGoal(weight: weight, skillIDs: skills, targetSongUID: song)
    }

    private func mode(of candidates: [PlannerCandidate], _ uid: UUID) -> LoopRunMode? {
        candidates.first { $0.unit.uid == uid }?.runMode
    }

    // MARK: - ADR 0135 B6 — the improv goal stops resolving to nothing

    func testImprovVocabularyResolvesToBackingLoopsWhenTheGoalNamesNoSong() {
        // The hole in the ADR's Context: `improv.vocabulary` is classed `.repertoire`, and the
        // "Improvise in a style" template sets `requiresTargetSong: false`, so Path B's opening
        // `guard let songUID` returned an empty array — permanently, for every player.
        let bed = loop(backing: true)
        let library = PlannerLibrary(loops: [bed, loop(backing: false)])
        let candidates = CandidateDeriver.deriveCandidates(goals: [goal(skills: ["improv.vocabulary"])],
                                                           library: library)
        XCTAssertEqual(candidates.map(\.unit.uid), [bed.uid])
        XCTAssertEqual(candidates.first?.runMode, .improvise)
    }

    func testAFlaggedLoopWithNoPlayableAudioIsNotAJamCandidate() {
        // The flag is a claim about *suitability*; a claim over audio that won't resolve leaves
        // nothing to solo over (ADR 0135 build notes, and `LoopModeAccess` is the single predicate
        // that decides it — the planner must not answer this question its own way).
        let library = PlannerLibrary(loops: [loop(audio: false, backing: true)])
        XCTAssertTrue(CandidateDeriver.deriveCandidates(goals: [goal(skills: ["improv.vocabulary"])],
                                                        library: library).isEmpty)
    }

    func testAnImprovGoalWithATargetSongStillResolvesThroughPathB() {
        // B6 is explicitly the *narrowest* change: where Path B already worked, it is untouched. The
        // song's own loops resolve as trainer work even though one of them is flagged as a bed.
        let songUID = UUID()
        let songLoop = loop(songUID: songUID, backing: true)
        let library = PlannerLibrary(loops: [songLoop, loop(backing: true)],
                                     songs: [PlannerSong(uid: songUID, lastPracticed: nil,
                                                         estimatedMinutes: 4)])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(skills: ["improv.vocabulary"], song: songUID)], library: library)
        XCTAssertEqual(Set(candidates.map(\.unit.uid)), [songLoop.uid, songUID])
        XCTAssertEqual(mode(of: candidates, songLoop.uid), .trainer)
    }

    // MARK: - ADR 0135 B6a — a jam is a play block, and it costs no focus slot

    func testAJamTrailsAsAPlayBlockAndNeverAsAFocusOne() {
        let bed = PlannerCandidate(unit: PlannerUnitRef(UUID(), .loop), estimatedMinutes: 4,
                                   runMode: .improvise)
        let drill = PlannerCandidate(unit: PlannerUnitRef(UUID(), .exercise), estimatedMinutes: 10)
        let blocks = SessionBuilder.buildSession(length: .focused, candidates: [bed, drill], now: now)

        XCTAssertEqual(blocks.last?.kind, .play)
        XCTAssertEqual(blocks.last?.unit, bed.unit)
        XCTAssertEqual(blocks.last?.loopRunMode, .improvise)
        XCTAssertFalse(blocks.contains { $0.kind == .focused && $0.unit == bed.unit })
    }

    func testAJamDoesNotConsumeOneOfThePresetsFocusItems() {
        // Partitioning happens *before* selection: a jam charged against the focused budget would
        // cost the player a drill to schedule something ADR 0129 never sized (ADR 0014 R1).
        let drills = (0..<6).map { _ in
            PlannerCandidate(unit: PlannerUnitRef(UUID(), .exercise), estimatedMinutes: 10)
        }
        let bed = PlannerCandidate(unit: PlannerUnitRef(UUID(), .loop), estimatedMinutes: 4,
                                   runMode: .improvise)
        let blocks = SessionBuilder.buildSession(length: .focused, candidates: drills + [bed],
                                                 now: now)
        XCTAssertEqual(blocks.filter { $0.kind == .focused }.count, SessionLength.focused.items)
    }

    func testAJamTakesItsLengthFromTheRampLessDefaultNotItsRegionEstimate() {
        // A play block carries no `plannedMinutes`, so ADR 0141's mode default is what it will
        // actually run for. Showing `region × repeats` on the review screen would promise a length
        // the player won't get.
        let bed = PlannerCandidate(unit: PlannerUnitRef(UUID(), .loop), estimatedMinutes: 4,
                                   runMode: .improvise)
        let blocks = SessionBuilder.buildSession(length: .focused, candidates: [bed], now: now)
        XCTAssertEqual(blocks.last?.minutes, RampLessBlockLength.improviseMinutes)
    }

    func testAQuickSittingSchedulesNoJam() {
        // Same rule the target-song play-through already follows (ADR 0129 sub-decision 2): a
        // ten-minute jam on top of a fifteen-minute preset would make the short option the long one.
        let bed = PlannerCandidate(unit: PlannerUnitRef(UUID(), .loop), estimatedMinutes: 4,
                                   runMode: .improvise)
        let blocks = SessionBuilder.buildSession(length: .quick, candidates: [bed], now: now)
        XCTAssertTrue(blocks.isEmpty)
    }

    // MARK: - ADR 0139 O2 — an ear skill resolves at last

    func testEarSkillsResolveToAudibleLoopsWithNoTag() {
        // `SkillFamilyMap` maps the three `ear.*` skills to `ExerciseTemplate.earTraining`, which is
        // not in `creatable` — pulled when ear training shipped as a loop mode instead (ADR 0104).
        // Until this, all three resolved to zero candidates for every player, permanently.
        let audible = loop(tempo: false)
        let library = PlannerLibrary(loops: [audible, loop(audio: false)])
        for skill in ["ear.relative-pitch", "ear.transcribe", "ear.active-listening"] {
            let candidates = CandidateDeriver.deriveCandidates(goals: [goal(skills: [skill])],
                                                               library: library)
            XCTAssertEqual(candidates.map(\.unit.uid), [audible.uid], "\(skill) should resolve")
            XCTAssertEqual(candidates.first?.runMode, .ear, "\(skill) should resolve as ear work")
        }
    }

    func testAnEarCandidateNeedsNoCommandTempo() {
        // The precondition ADR 0138 moved onto the mode: measuring a passage requires playing it on
        // your instrument, which is precisely what the off-guitar session doesn't have.
        let library = PlannerLibrary(loops: [loop(tempo: false)])
        XCTAssertFalse(CandidateDeriver.deriveCandidates(goals: [goal(skills: ["ear.transcribe"])],
                                                         library: library).isEmpty)
    }

    // MARK: - ADR 0139 O2b — a unit appears once, not once per mode

    func testALoopClaimedByTwoGoalsAppearsOnceWithTheStrongerClaimsMode() {
        // Deduplication is keyed on the unit, never unit-plus-mode: otherwise the same four bars
        // turn up twice in one session, once to train and once to sing back.
        let songUID = UUID()
        let shared = loop(songUID: songUID)
        let library = PlannerLibrary(loops: [shared],
                                     songs: [PlannerSong(uid: songUID, lastPracticed: nil,
                                                         estimatedMinutes: 4)])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(weight: 1.0, skills: ["ear.transcribe"]),
                    goal(weight: 3.0, skills: ["rep.learn-song"], song: songUID)],
            library: library)

        XCTAssertEqual(candidates.filter { $0.unit.uid == shared.uid }.count, 1)
        XCTAssertEqual(mode(of: candidates, shared.uid), .trainer)   // the heavier goal's claim wins
    }

    // MARK: - ADR 0139 O3 — the constraint is a smaller pool, not a second planner

    func testTheConstrainedPoolDropsEverythingThatNeedsTheInstrument() {
        let songUID = UUID()
        let library = PlannerLibrary(
            exercises: [PlannerExercise(uid: UUID(), template: .picking, mastery: nil,
                                        lastPracticed: nil, estimatedMinutes: 10)],
            loops: [loop(songUID: songUID)],
            songs: [PlannerSong(uid: songUID, lastPracticed: nil, estimatedMinutes: 200)])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(skills: ["pick.alternate", "rep.learn-song"], song: songUID)],
            library: library, constraint: .offGuitar)

        XCTAssertEqual(candidates.map(\.unit.kind), [.loop])
    }

    func testTheConstraintPinsSurvivingLoopsToEarRatherThanDroppingThem() {
        // Pinning, not filtering. A "learn this song" goal's loops arrive as trainer work with a ramp
        // you can't run on a train; they leave as ear work on the same material. Filtering instead
        // would make the session reachable only by players who happen to hold an ear goal.
        let songUID = UUID()
        let songLoop = loop(songUID: songUID)
        let library = PlannerLibrary(loops: [songLoop],
                                     songs: [PlannerSong(uid: songUID, lastPracticed: nil,
                                                         estimatedMinutes: 200)])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(skills: ["rep.learn-song"], song: songUID)],
            library: library, constraint: .offGuitar)
        XCTAssertEqual(mode(of: candidates, songLoop.uid), .ear)
    }

    func testTheConstraintDropsAJamBecauseImprovisingNeedsTheInstrument() {
        // O1's whole point: off-guitar is a property of the mode. Improvise is the mode that most
        // obviously needs the instrument, so a backing loop is *not* off-guitar material — but the
        // same loop, sung back, is, which is why it survives pinned to `.ear` rather than dropping.
        let bed = loop(backing: true)
        let library = PlannerLibrary(loops: [bed])
        let candidates = CandidateDeriver.deriveCandidates(goals: [goal(skills: ["improv.vocabulary"])],
                                                           library: library, constraint: .offGuitar)
        XCTAssertEqual(mode(of: candidates, bed.uid), .ear)
        XCTAssertFalse(SessionConstraint.offGuitar.allows(.improvise))
    }

    func testASilentLoopSurvivesNoConstrainedPool() {
        let library = PlannerLibrary(loops: [loop(audio: false)])
        XCTAssertTrue(CandidateDeriver.deriveCandidates(goals: [goal(skills: ["ear.transcribe"])],
                                                        library: library,
                                                        constraint: .offGuitar).isEmpty)
    }

    func testAnUnconstrainedPoolIsReturnedUntouched() {
        let library = PlannerLibrary(loops: [loop(backing: true)])
        let candidates = CandidateDeriver.deriveCandidates(goals: [goal(skills: ["improv.vocabulary"])],
                                                           library: library, constraint: .none)
        XCTAssertEqual(mode(of: candidates, library.loops[0].uid), .improvise)
    }

    // MARK: - The goal-less path (the headline case: fifteen minutes and no guitar)

    @MainActor
    func testAnOffGuitarQuickSessionIsEarBlocksAndNoWarmUp() {
        // A player with no goals still has the situation. A warm-up is dropped rather than kept:
        // the warm-up pool is `template == .warmup` exercises, and every one of them wants the
        // instrument in your hands.
        let warm = Exercise(name: "Loosen up", template: .warmup)
        let audible = Loop(name: "Chorus", start: 0.1, end: 0.2, speed: 1, repeats: 4)
        audible.song = Song(title: "Chorus", duration: 180,
                            ref: SongRef(id: "chorus.m4a", source: .localFile))

        let blocks = PracticePlanner.planQuickSession(length: .quick, exercises: [warm],
                                                      loops: [audible], constraint: .offGuitar,
                                                      now: now)
        XCTAssertFalse(blocks.isEmpty)
        XCTAssertFalse(blocks.contains { $0.kind == .warmup })
        XCTAssertTrue(blocks.allSatisfy { $0.loopRunMode == .ear })
    }

    @MainActor
    func testAnUnconstrainedQuickSessionIgnoresLoopsEntirely() {
        // The ordinary path is untouched by the new parameters — loops are projected only when the
        // constraint asks for them.
        let drill = Exercise(name: "Spider", template: .picking)
        let audible = Loop(name: "Chorus", start: 0.1, end: 0.2, speed: 1, repeats: 4)
        audible.song = Song(title: "Chorus", duration: 180,
                            ref: SongRef(id: "chorus.m4a", source: .localFile))

        let blocks = PracticePlanner.planQuickSession(length: .quick, exercises: [drill],
                                                      loops: [audible], now: now)
        XCTAssertEqual(blocks.compactMap(\.unit).map(\.kind), [.exercise])
    }

    // MARK: - The last leg: the mode reaches the persisted block

    func testMaterialisationCarriesTheRunModeOntoTheRoutineItem() throws {
        // The silent failure this whole change exists to prevent: without it a planned ear or
        // improvise block persists as `.trainer` and the player is handed a staircase.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, configurations: config)
        let context = ModelContext(container)
        let bed = Loop(name: "Outro vamp", start: 0.6, end: 0.9, speed: 1, repeats: 4)
        context.insert(bed)
        try context.save()

        let blocks: [SessionBlock] = [
            .focus(PlannerUnitRef(bed.uid, .loop), minutes: 5, microRestEvery: 2, mode: .ear),
            .play(PlannerUnitRef(bed.uid, .loop), minutes: 10, mode: .improvise)
        ]
        let routine = PracticePlanner.materialise(blocks, name: "Session", exercises: [],
                                                  loops: try context.fetch(FetchDescriptor<Loop>()),
                                                  songs: [], into: context)

        XCTAssertEqual(routine.orderedItems.map(\.loopRunMode), [.ear, .improvise])
        // ADR 0141: the focused ear block runs its allotment, the unbudgeted jam its mode default.
        XCTAssertEqual(routine.orderedItems.map(\.resolvedBlockMinutes),
                       [5, RampLessBlockLength.improviseMinutes])
    }
}
