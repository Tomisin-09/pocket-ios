import SwiftData
import XCTest
@testable import Pocket

/// What *Put it together* writes (ADR 0232 D11), in a real in-memory store: the command tempos and the
/// backing switch, the joined loops, and a routine that lands only when the review saves it.
@MainActor
final class SongMapTogetherWriterTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var song: Song!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer(for: Song.self, Loop.self, Routine.self, RoutineItem.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        song = Song(title: "Slow Bend", duration: 64, ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        context.insert(song)
    }

    override func tearDown() async throws {
        song = nil
        context = nil
        container = nil
        try await super.tearDown()
    }

    @discardableResult
    private func loop(_ name: String, _ start: TimeInterval, _ end: TimeInterval, type: LoopType = .riff,
                      speed: Double = 1, command: Double? = nil) -> Loop {
        let loop = Loop(name: name, start: start / 64, end: end / 64, speed: speed, repeats: 4)
        loop.loopType = type
        loop.commandTempo = command
        context.insert(loop)
        loop.song = song
        return loop
    }

    private func inARow(_ loops: [Loop]) -> SongMapTogether.Plan {
        SongMapTogether.plan(.inARow(loops.map(\.uid)), in: SongMapLayout.build(SongMapInput(song: song)),
                             songTitle: song.title, existingNames: song.loops.map(\.name))
    }

    func testTheJoinedLoopRunsFromTheFirstPartToTheLastAtTheSlowestOfThem() throws {
        let first = loop("Verse riff", 8, 12, speed: 0.9, command: 0.8)
        let second = loop("Verse riff 2", 12, 16, type: .lick, speed: 1)
        let joined = SongMapWriter.prepare(inARow([first, second]), commands: [second.uid: 0.7], in: song,
                                           context: context)
        XCTAssertEqual(second.commandTempo, 0.7, "the tempo asked for is saved on the loop")
        let made = try XCTUnwrap(joined.first)
        XCTAssertEqual(joined.count, 1)
        XCTAssertEqual(made.name, "Verse riff to Verse riff 2")
        XCTAssertEqual(made.start, first.start, "from the part's own edge, not one worked back from seconds")
        XCTAssertEqual(made.end, second.end)
        XCTAssertEqual(made.speed, 0.9)
        XCTAssertEqual(made.commandTempo, 0.7)
        XCTAssertEqual(made.loopType, .unset, "a lick and a riff joined are neither")
        XCTAssertNil(made.transcription, "its parts hold the notes, so the tab doesn't write them twice")
        XCTAssertTrue(song.loops.contains { $0.uid == made.uid })
    }

    func testAJoinedStretchOfChordsIsTypedToStayOnTheChordsLane() throws {
        let first = loop("Verse chords", 8, 16, type: .chords, command: 1)
        let second = loop("Verse chords 2", 16, 24, type: .chords, command: 1)
        let made = try XCTUnwrap(SongMapWriter.prepare(inARow([first, second]), commands: [:], in: song,
                                                       context: context).first)
        XCTAssertEqual(made.loopType, .chords)
        let riffs = [loop("Riff", 24, 28, command: 1), loop("Riff 2", 28, 32, command: 1)]
        let joinedRiffs = try XCTUnwrap(SongMapWriter.prepare(inARow(riffs), commands: [:], in: song,
                                                              context: context).first)
        XCTAssertEqual(joinedRiffs.loopType, .riff, "parts of one type keep it")
    }

    func testALineOverItsChordsSwitchesTheBackingOn() {
        let chords = loop("Intro chords", 0, 8, type: .chords)
        let line = loop("Intro lick", 2, 4, type: .lick)
        let plan = SongMapTogether.plan(.lineOverChords(line: line.uid, chords: chords.uid),
                                        in: SongMapLayout.build(SongMapInput(song: song)), songTitle: song.title,
                                        existingNames: [])
        XCTAssertEqual(SongMapWriter.prepare(plan, commands: [line.uid: 0.75], in: song, context: context), [])
        XCTAssertTrue(chords.isBackingTrack)
        XCTAssertTrue(LoopModeAccess.allows(.improvise, chords), "so the backing block can run")
        XCTAssertFalse(line.isBackingTrack)
        XCTAssertEqual(line.commandTempo, 0.75)
        XCTAssertTrue(LoopModeAccess.allows(.trainer, line), "so the Practice block can run")
    }

    func testTheRoutineLandsOnlyWhenTheReviewSavesItAndThenTheJoinedLoopsAreItsBlocks() throws {
        let first = loop("A", 8, 12, command: 1)
        let second = loop("B", 12, 16, command: 1)
        let plan = inARow([first, second])
        let joined = SongMapWriter.prepare(plan, commands: [:], in: song, context: context)
        let uids = Set(joined.map(\.uid))

        let review = ModelContext(container)
        review.autosaveEnabled = false
        let routine = SongMapWriter.routine(named: plan.name,
                                            runs: SongMapTogether.runs(plan, joined: joined.map(\.uid)), in: review)
        XCTAssertEqual(routine.orderedItems.map { $0.loop?.name }, ["A", "B", "A to B"])
        XCTAssertEqual(routine.orderedItems.map(\.kind), [.focused, .focused, .focused])
        XCTAssertEqual(routine.orderedItems.map(\.loopRunMode), [.trainer, .trainer, .trainer])
        XCTAssertEqual(routine.orderedItems.map(\.plannedMinutes), [nil, nil, nil], "each runs at its own length")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Routine>()).count, 0, "nothing lands before Save")
        XCTAssertFalse(SongMapWriter.routineUses(uids, context: context), "so Undo is offered")

        try review.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Routine>()).map(\.name), ["Slow Bend: A to B"])
        XCTAssertTrue(SongMapWriter.routineUses(uids, context: context), "so Undo isn't offered")
    }

    func testTheTempoQuestionStartsWhereTheLoopEditSheetsSetWould() {
        XCTAssertEqual(SongMapCommandSheet.seed(speed: 1), 100)
        XCTAssertEqual(SongMapCommandSheet.seed(speed: 0.83), 85, "to the nearest 5%")
        XCTAssertEqual(SongMapCommandSheet.seed(speed: 0.1), 25)
        XCTAssertEqual(SongMapCommandSheet.seed(speed: 2), 150)
    }

    func testTheBackingRunsAsAnImproviseBlock() throws {
        let chords = loop("Intro chords", 0, 8, type: .chords)
        let line = loop("Intro lick", 2, 4, type: .lick, command: 0.8)
        let runs = [SongMapTogether.Run(uid: line.uid, mode: .trainer),
                    SongMapTogether.Run(uid: chords.uid, mode: .improvise),
                    SongMapTogether.Run(uid: UUID(), mode: .trainer)]
        try context.save()
        let review = ModelContext(container)
        let routine = SongMapWriter.routine(named: "Over", runs: runs, in: review)
        XCTAssertEqual(routine.orderedItems.map { $0.loop?.uid }, [line.uid, chords.uid],
                       "a loop that's gone is left out")
        XCTAssertEqual(routine.orderedItems.map(\.loopRunMode), [.trainer, .improvise])
        XCTAssertEqual(routine.orderedItems.map(\.kind), [.focused, .play])
        XCTAssertEqual(routine.orderedItems.map(\.order), [0, 1])
    }

    // MARK: - The tempo question

    private func lineOverChords(_ line: Loop, _ chords: Loop) -> SongMapTogether.Plan {
        SongMapTogether.plan(.lineOverChords(line: line.uid, chords: chords.uid),
                             in: SongMapLayout.build(SongMapInput(song: song)), songTitle: song.title,
                             existingNames: [])
    }

    private func asking(_ plan: SongMapTogether.Plan) -> SongMapCommandSheet.Answers? {
        SongMapCommandSheet.Answers(asking: plan, loops: song.loops, place: { _ in "" })
    }

    func testTheBackingIsAskedForStartingWithTheLine() throws {
        let chords = loop("Intro chords", 0, 8, type: .chords)
        let line = loop("Intro lick", 2, 4, type: .lick, speed: 0.7)
        let answers = try XCTUnwrap(asking(lineOverChords(line, chords)))
        XCTAssertEqual(answers.rows.map(\.uid), [line.uid])
        XCTAssertEqual(answers.rows.map(\.percent), [70])
        XCTAssertEqual(answers.backing?.uid, chords.uid)
        XCTAssertEqual(answers.backing?.percent, 70, "no faster than the line")
        XCTAssertEqual(answers.follows, line.uid)
    }

    func testTheBackingMovesWithTheLineUntilItsSetOnItsOwn() throws {
        let chords = loop("Intro chords", 0, 8, type: .chords)
        let line = loop("Intro lick", 2, 4, type: .lick)
        var answers = try XCTUnwrap(asking(lineOverChords(line, chords)))
        answers.set(80, for: line.uid)
        XCTAssertEqual(answers.percent(chords.uid), 80)
        answers.set(90, for: chords.uid)
        answers.set(60, for: line.uid)
        XCTAssertEqual(answers.percent(chords.uid), 90, "set on its own, it stays")
        XCTAssertEqual(answers.commands, [line.uid: 0.6, chords.uid: 0.9], "both are saved")
    }

    func testAMeasuredLineStartsTheBackingAtItsCommandTempo() throws {
        let chords = loop("Intro chords", 0, 8, type: .chords)
        let line = loop("Intro lick", 2, 4, type: .lick, speed: 0.6, command: 0.85)
        let answers = try XCTUnwrap(asking(lineOverChords(line, chords)), "the backing is still asked for")
        XCTAssertEqual(answers.rows, [])
        XCTAssertEqual(answers.backing?.percent, 85)
        XCTAssertNil(answers.follows)
    }

    func testOnlyWhatsMissingIsAskedFor() throws {
        let chords = loop("Intro chords", 0, 8, type: .chords, command: 1)
        let line = loop("Intro lick", 2, 4, type: .lick)
        let justTheLine = try XCTUnwrap(asking(lineOverChords(line, chords)))
        XCTAssertEqual(justTheLine.rows.map(\.uid), [line.uid])
        XCTAssertNil(justTheLine.backing, "a backing with a command tempo keeps it")
        line.commandTempo = 0.9
        XCTAssertNil(asking(lineOverChords(line, chords)), "nothing missing, nothing asked")
        let first = loop("A", 8, 12, command: 1)
        let second = loop("B", 12, 16)
        let row = try XCTUnwrap(asking(inARow([first, second])))
        XCTAssertEqual(row.rows.map(\.uid), [second.uid])
        XCTAssertNil(row.backing)
    }
}
