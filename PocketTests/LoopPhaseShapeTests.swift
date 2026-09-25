import XCTest
@testable import Pocket

/// A loop's run shaped phase by phase (ADR 0221 D8): the reps-per-step fold, which must leave every
/// stored loop playing exactly what it played; the switches and holds in passes; the words and the
/// length line in % and passes; and the shape on the wire. `Loop` is built **uninserted** — inserting
/// in the test host SIGTRAPs, and stored-property logic reads fine off a bare `@Model`.
final class LoopPhaseShapeTests: XCTestCase {

    /// A measured loop over a 12-second region: floor 70%, command 85%, auto reach 90%.
    private func makeLoop() -> Loop {
        let loop = Loop(name: "Chorus lick", start: 0.1, end: 0.2, speed: 0.70, repeats: 3)
        loop.song = Song(title: "Test", duration: 120,
                         ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        loop.commandTempo = 0.85
        return loop
    }

    /// A loop as a build before ADR 0221 left it: three passes a step, a dwell of four such steps,
    /// one intermediate stop on every phase.
    private func legacyLoop() -> Loop {
        let loop = makeLoop()
        loop.rampRepsPerStep = 3
        loop.rampDwellIntervals = 4
        loop.rampWarmupSteps = 1
        loop.rampReachSteps = 1
        loop.rampBackoffSteps = 1
        return loop
    }

    /// The staircase that loop played before ADR 0221: every plateau held in intervals of
    /// `repsPerStep` passes. Built the way the old `LoopCommandRamp.make(loop:)` built it.
    private func rampAsItPlayedBefore(_ loop: Loop) -> CommandRamp {
        CommandRamp(working: LoopCommandRamp.percent(loop.rampFloor),
                    command: LoopCommandRamp.percent(loop.command),
                    target: LoopCommandRamp.percent(loop.targetSpeed),
                    warmupSteps: loop.rampWarmupSteps, intervalCount: loop.rampRepsPerStep, unit: .bars,
                    dwellIntervals: loop.rampDwellIntervals, includeBackoff: loop.includeBackoff,
                    reachSteps: loop.rampReachSteps, backoffSteps: loop.rampBackoffSteps)
    }

    /// The tempo at every pass of a ramp, through one pass past its end.
    private func tempoByPass(_ ramp: CommandRamp) -> [Int] {
        let passes = ramp.completionInterval ?? 0
        return (0...passes).map { ramp.bpm(elapsedBars: $0, elapsedSeconds: 0) }
    }

    // MARK: - D8: the fold

    /// Before its first save, the loop's shape reads its holds multiplied out into passes.
    func testTheFoldReadsHoldsInPasses() {
        let shape = legacyLoop().runShape
        XCTAssertEqual([shape.warmupHold, shape.dwell, shape.reachHold, shape.backoffHold], [3, 12, 3, 3])
        XCTAssertEqual([shape.warmupSteps, shape.reachSteps, shape.backoffSteps], [1, 1, 1])
    }

    /// The whole point of D8: no stored loop changes what it plays, before or after the fold writes.
    func testAFoldedLoopPlaysExactlyWhatItPlayedBefore() {
        let loop = legacyLoop()
        let before = tempoByPass(rampAsItPlayedBefore(loop))
        XCTAssertEqual(tempoByPass(loop.ramp), before, "read through the fold")
        loop.applyRunShape(loop.runShape)
        XCTAssertEqual(tempoByPass(loop.ramp), before, "after the first save")
        XCTAssertEqual(loop.ramp.completionInterval, 3 * (2 + 4 + 2 + 2), "the same passes in total")
    }

    /// The first save writes the holds in passes and retires the multiplier, so the shape reads the
    /// same afterwards and nothing multiplies it again.
    func testTheFirstSaveRetiresRepsPerStep() {
        let loop = legacyLoop()
        let shape = loop.runShape
        loop.applyRunShape(shape)
        XCTAssertEqual(loop.rampRepsPerStep, 1)
        XCTAssertEqual(loop.rampDwellIntervals, 12)
        XCTAssertEqual([loop.rampWarmupHold, loop.rampReachHold, loop.rampBackoffHold], [3, 3, 3])
        XCTAssertEqual(loop.runShape, shape)
        loop.applyRunShape(loop.runShape)
        XCTAssertEqual(loop.runShape, shape, "a second save doesn't fold twice")
    }

    /// A loop at one pass a step — every loop's default — reads exactly as stored.
    func testALoopAtOnePassAStepReadsAsStored() {
        let loop = makeLoop()
        loop.rampDwellIntervals = 6
        XCTAssertEqual(loop.runShape.dwell, 6)
        XCTAssertEqual(loop.runShape.warmupHold, 1)
    }

    // MARK: - D3: a hold above the shared range

    /// Folding can land a hold above 12 passes (4 reps × a dwell of 4). A tap mustn't snap it to 12:
    /// down walks it down, up does nothing, and once it is inside the range the range holds.
    func testAHoldAboveTheRangeWalksDownAndNeverSnaps() {
        var shape = RunShape(dwell: 16)
        shape.setHold(.command, 17)
        XCTAssertEqual(shape.dwell, 16, "up does nothing above the ceiling")
        shape.setHold(.command, 15)
        XCTAssertEqual(shape.dwell, 15, "down walks it down one")
        shape.dwell = 12
        shape.setHold(.command, 13)
        XCTAssertEqual(shape.dwell, 12, "inside the range, the range holds")
        shape.setHold(.warmup, 0)
        XCTAssertEqual(shape.warmupHold, 1)
    }

    // MARK: - D2 / D6: switches and the summit

    func testALoopWithEveryOptionalPhaseOffIsCommandAlone() {
        let loop = makeLoop()
        loop.applyRunShape(RunShape(includeWarmup: false, includeReach: false, includeBackoff: false,
                                    dwell: 6))
        XCTAssertEqual(loop.ramp.plateaus, [CommandRamp.Plateau(bpm: 85, intervals: 6)])
    }

    /// With Reach off the run summits at command, so the completion offer has nothing to raise to.
    func testTheSummitIsCommandWhenReachIsOff() {
        let loop = makeLoop()
        XCTAssertEqual(loop.summitSpeed, loop.targetSpeed, accuracy: 0.0001)
        loop.includeReach = false
        XCTAssertEqual(loop.summitSpeed, loop.command, accuracy: 0.0001)
        let anchors = CommandOffer.Anchors(
            command: 85, floor: 25, ceiling: 150,
            raiseTarget: CommandOffer.raisedCommand(reach: LoopCommandRamp.percent(loop.summitSpeed),
                                                    ceiling: 150),
            settleTarget: loop.backoffPercent)
        XCTAssertFalse(CommandOffer.canRaise(anchors))
    }

    /// A switched-off phase keeps its tempo: the pinned back off returns with the phase (D2).
    func testSwitchingAPhaseOffKeepsItsPin() {
        let loop = makeLoop()
        loop.backoffSpeedOverride = 0.76
        loop.includeBackoff = false
        XCTAssertEqual(loop.ramp.plateaus.last?.bpm, LoopCommandRamp.percent(loop.targetSpeed),
                       "off: the run ends at the reach")
        loop.includeBackoff = true
        XCTAssertEqual(loop.ramp.plateaus.last?.bpm, 76)
    }

    // MARK: - D10: the length line, in passes

    func testTheLengthLineCountsPassesAtEachPlateausSpeed() {
        // One plateau at 100% of a 12s region, held 4 passes: 48 s, stated to the nearest 5.
        let ramp = LoopCommandRamp.make(working: 1.0, command: 1.0, target: 1.0,
                                        shape: RunShape(includeBackoff: false, dwell: 4))
        XCTAssertEqual(RunLength.loop(ramp, regionSeconds: 12), "≈ 50 s · 4 passes")
        let one = LoopCommandRamp.make(working: 1.0, command: 1.0, target: 1.0,
                                       shape: RunShape(includeBackoff: false, dwell: 1))
        XCTAssertEqual(RunLength.loop(one, regionSeconds: 12), "≈ 10 s · 1 pass")
    }

    /// A loop whose song hasn't resolved has no region: it says the passes, not a made-up `≈ 5 s`.
    func testTheLengthLineWithNoRegionStatesThePassesAlone() {
        let ramp = LoopCommandRamp.make(working: 1.0, command: 1.0, target: 1.0,
                                        shape: RunShape(includeBackoff: false, dwell: 4))
        XCTAssertEqual(RunLength.loop(ramp, regionSeconds: 0), "4 passes")
    }

    // MARK: - D5: the words, in % and passes

    private func summary(_ shape: RunShape) -> RampSummary {
        RampSummary(tempos: RampTempos(working: 70, command: 85, reach: 91, backoff: 79), shape: shape,
                    reachIsAuto: true, backoffIsAuto: true, tempoUnit: .percent, holdUnit: .passes,
                    unitsPerInterval: LoopCommandRamp.passesPerInterval)
    }

    func testTheHeaderReadsInPercent() {
        XCTAssertEqual(summary(RunShape()).header, "70% → 85% · reach 91% · back to 79%")
        let alone = RunShape(includeWarmup: false, includeReach: false, includeBackoff: false, dwell: 6)
        XCTAssertEqual(summary(alone).header, "85%, steady · 6 passes")
    }

    func testTheRowsCountPasses() {
        let words = summary(RunShape(warmupSteps: 1, warmupHold: 2, dwell: 1))
        XCTAssertEqual(words.row(.command), "85% · 1 pass")
        XCTAssertEqual(words.row(.warmup), "70% → 85% · 2 steps · 2 passes each")
        XCTAssertEqual(words.row(.reach), "91% (auto) · 1 step · 1 pass each")
        XCTAssertEqual(words.pinCaption(.reach), "auto · +6%")
        XCTAssertEqual(words.pinCaption(.backoff), "auto · −6%")
        XCTAssertEqual(words.stepsCaption(.warmup), "about +8% a rung")
    }

    // MARK: - On the wire

    private func shapedLoopRecord() -> LoopRecord {
        var record = ArchiveFixture.loop(uid: UUID())
        record.rampRepsPerStep = 1
        record.includeWarmup = false
        record.includeReach = false
        record.rampWarmupHold = 3
        record.rampReachHold = 2
        record.rampBackoffHold = 4
        return record
    }

    private func archive(_ loops: [LoopRecord]) -> PracticeArchive {
        var archive = PracticeArchive(exportedAt: ArchiveFixture.date, appVersion: "1.3",
                                      includesTakeAudio: false)
        archive.songs = [ArchiveFixture.song(sourceID: "song-1", loops: loops)]
        return archive
    }

    func testTheShapeSurvivesAnEncodeAndDecode() throws {
        let written = archive([shapedLoopRecord()])
        let read = try ArchiveBuilder.decode(ArchiveBuilder.encode(written))
        XCTAssertEqual(read.songs, written.songs)
    }

    @MainActor
    func testABuilderWritesTheLoopsShape() {
        let loop = makeLoop()
        loop.applyRunShape(RunShape(includeWarmup: false, includeReach: true, includeBackoff: true,
                                    warmupHold: 2, dwell: 9, reachHold: 5, backoffHold: 6))
        let record = ArchiveBuilder.loopRecord(loop)
        XCTAssertEqual(record.includeWarmup, false)
        XCTAssertEqual(record.includeReach, true)
        XCTAssertEqual(record.rampRepsPerStep, 1)
        XCTAssertEqual(record.rampDwellIntervals, 9)
        XCTAssertEqual([record.rampWarmupHold, record.rampReachHold, record.rampBackoffHold], [2, 5, 6])
    }

    /// A backup from before step 2 has none of the new loop keys. It must decode — one missing
    /// non-optional key fails the whole file.
    func testAnArchiveWrittenBeforeLoopPhaseShapesStillDecodes() throws {
        let data = try ArchiveBuilder.encode(archive([shapedLoopRecord()]))
        let read = try ArchiveBuilder.decode(strippingLoopPhaseKeys(from: data))
        let loop = try XCTUnwrap(read.songs.first?.loops.first)
        XCTAssertNil(loop.includeWarmup)
        XCTAssertNil(loop.includeReach)
        XCTAssertNil(loop.rampWarmupHold)
        XCTAssertEqual(loop.name, ArchiveFixture.loop(uid: UUID()).name, "one missing key took nothing else")
    }

    /// An older backup restores as the shape it had, folded as the phone that wrote it would fold it:
    /// the fixture's three passes a step and a dwell of two read as 3-pass rungs and a 6-pass dwell.
    @MainActor
    func testAnOldBackupRestoresTheShapeItHad() throws {
        let landing = ArchiveRestoreWriter.materialize(archive([ArchiveFixture.loop(uid: UUID())]),
                                                       existing: RestoreExistingKeys())
        let loop = try XCTUnwrap(landing.songs.first?.loops.first)
        let shape = loop.runShape
        XCTAssertTrue(shape.includeWarmup && shape.includeReach && shape.includeBackoff)
        XCTAssertEqual([shape.warmupHold, shape.dwell, shape.reachHold, shape.backoffHold], [3, 6, 3, 3])
    }

    @MainActor
    func testRestoreLandsTheShape() throws {
        let landing = ArchiveRestoreWriter.materialize(archive([shapedLoopRecord()]),
                                                       existing: RestoreExistingKeys())
        let loop = try XCTUnwrap(landing.songs.first?.loops.first)
        XCTAssertEqual(loop.includeWarmup, false)
        XCTAssertEqual(loop.includeReach, false)
        XCTAssertEqual([loop.rampWarmupHold, loop.rampReachHold, loop.rampBackoffHold], [3, 2, 4])
    }

    // MARK: - Helpers

    private static let loopPhaseKeys: Set<String> = ["includeWarmup", "includeReach", "rampWarmupHold",
                                                      "rampReachHold", "rampBackoffHold"]

    /// Removes step 2's keys from every **loop** in encoded JSON.
    private func strippingLoopPhaseKeys(from data: Data) throws -> Data {
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let songs = json["songs"] as? [[String: Any]]
        else { return data }
        json["songs"] = songs.map { song in
            var song = song
            if let loops = song["loops"] as? [[String: Any]] {
                song["loops"] = loops.map { $0.filter { !Self.loopPhaseKeys.contains($0.key) } }
            }
            return song
        }
        return try JSONSerialization.data(withJSONObject: json)
    }
}
