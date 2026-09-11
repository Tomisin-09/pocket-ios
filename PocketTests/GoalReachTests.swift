import XCTest
@testable import Pocket

/// ADR 0216 D4 — what each of a goal's skills actually pulls from the library. Pure values only (no
/// `@Model` inserts), which is why the reach is computed over `PlannerLibrary`.
final class GoalReachTests: XCTestCase {

    private func exercise(_ template: ExerciseTemplate) -> PlannerExercise {
        PlannerExercise(uid: UUID(), template: template, mastery: nil, lastPracticed: nil, estimatedMinutes: 10)
    }

    private func loop(tags templates: [ExerciseTemplate] = [], song: UUID? = nil,
                      audible: Bool = false) -> PlannerLoop {
        PlannerLoop(uid: UUID(), songUID: song, mastery: nil, lastPracticed: nil, estimatedMinutes: 4,
                    templates: templates,
                    modeFacts: LoopModeAccess.Facts(hasCommandTempo: false, audioResolves: audible))
    }

    func testCountsWhatEachSkillPulls() {
        let library = PlannerLibrary(exercises: [exercise(.picking), exercise(.picking), exercise(.scales)],
                                     loops: [loop(tags: [.picking])])
        let reach = GoalReach.reach(skillIDs: ["pick.alternate", "scale.pentatonic"], targetSongUID: nil,
                                    library: library)
        XCTAssertEqual(reach.map(\.skillID), ["pick.alternate", "scale.pentatonic"])
        XCTAssertEqual(reach.map(\.exercises), [2, 1])
        XCTAssertEqual(reach.map(\.loops), [1, 0])
        XCTAssertEqual(reach.map(\.songRun), [false, false])
    }

    func testASkillNothingServesReadsEmpty() {
        let library = PlannerLibrary(exercises: [exercise(.chords)])
        let reach = GoalReach.reach(skillIDs: ["fret.vibrato"], targetSongUID: nil, library: library)
        XCTAssertEqual(reach.first?.isEmpty, true)
        XCTAssertEqual(reach.first.map(GoalReach.summary), "Nothing in your library yet")
    }

    func testASharedDrillCountsForEverySkillItServes() {
        // Derived one skill at a time. Deriving the whole goal at once would keep only the strongest
        // claim on the drill, and the other skill would read "nothing" while it plainly has one.
        let library = PlannerLibrary(exercises: [exercise(.picking)])
        let reach = GoalReach.reach(skillIDs: ["pick.alternate", "pick.economy"], targetSongUID: nil,
                                    library: library)
        XCTAssertEqual(reach.map(\.exercises), [1, 1])
    }

    func testARepertoireSkillCountsTheTargetSongsLoopsAndItsRun() {
        let songUID = UUID()
        let library = PlannerLibrary(loops: [loop(song: songUID), loop(song: songUID), loop(song: UUID())],
                                     songs: [PlannerSong(uid: songUID, lastPracticed: nil, estimatedMinutes: 4)])
        let reach = GoalReach.reach(skillIDs: ["rep.learn-song"], targetSongUID: songUID, library: library)
        XCTAssertEqual(reach.first?.loops, 2)
        XCTAssertEqual(reach.first?.songRun, true)
        XCTAssertEqual(reach.first.map(GoalReach.summary), "2 loops · the song itself")
    }

    func testARepertoireSkillWithoutASongReachesNothing() {
        let library = PlannerLibrary(loops: [loop(song: UUID())])
        let reach = GoalReach.reach(skillIDs: ["rep.learn-song"], targetSongUID: nil, library: library)
        XCTAssertEqual(reach.first?.isEmpty, true)
    }

    func testAnEarSkillReachesAnyLoopYouCanHear() {
        // The capability route (ADR 0139 O2) — no tag, no template. The route a hand-rolled walk
        // would forget, and the reason the reach asks the deriver.
        let library = PlannerLibrary(loops: [loop(audible: true), loop(audible: false)])
        let reach = GoalReach.reach(skillIDs: ["ear.relative-pitch"], targetSongUID: nil, library: library)
        XCTAssertEqual(reach.first?.loops, 1)
    }

    func testReachAgreesWithTheDeriver() {
        let library = PlannerLibrary(exercises: [exercise(.picking), exercise(.arpeggios)],
                                     loops: [loop(tags: [.arpeggios]), loop(audible: true)])
        for skill in ["pick.sweep", "pick.economy", "pick.alternate", "ear.transcribe", "fret.vibrato"] {
            let probe = PlannerGoal(weight: 1.0, skillIDs: [skill], targetSongUID: nil, isMet: false)
            let derived = CandidateDeriver.deriveCandidates(goals: [probe], library: library)
            let reach = GoalReach.reach(skillIDs: [skill], targetSongUID: nil, library: library)[0]
            XCTAssertEqual(reach.exercises + reach.loops + (reach.songRun ? 1 : 0), derived.count, skill)
        }
    }

    func testSummaryPluralisesAndJoins() {
        XCTAssertEqual(GoalReach.summary(SkillReach(skillID: "pick.alternate", exercises: 1, loops: 0,
                                                    songRun: false)), "1 exercise")
        XCTAssertEqual(GoalReach.summary(SkillReach(skillID: "pick.alternate", exercises: 2, loops: 1,
                                                    songRun: false)), "2 exercises · 1 loop")
    }
}
