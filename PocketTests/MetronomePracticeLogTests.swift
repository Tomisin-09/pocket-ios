import XCTest
import SwiftData
@testable import Pocket

/// **Time with the metronome counts as practice** (ADR 0242): the Metronome screen's run clock, the
/// 30-second floor that keeps a tempo check out of the log, the new kind, and the decode rule that
/// keeps one new kind from failing a whole backup.
///
/// The screen itself is two lines of wiring — read `elapsed`, stop, hand both to the writer. What can
/// go wrong is here: a start that a pause moves, a sitting logged twice, a floor that applies to the
/// wrong kind, and an archive that a newer build's rows make unreadable.
@MainActor
final class MetronomePracticeLogTests: XCTestCase {

    private let ten = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // MARK: - The run clock

    /// Only stopped → sounding starts a run. Pause and resume are one sitting, so they leave the start
    /// where it was — which is how the engine's own session clock counts them.
    func testARunStartsWhenTheClickStartsAndAPauseDoesNotMoveIt() {
        var log = MetronomeRunLog()
        log.transportChanged(from: .stopped, to: .playing, at: ten)
        log.transportChanged(from: .playing, to: .paused, at: ten.addingTimeInterval(60))
        log.transportChanged(from: .paused, to: .playing, at: ten.addingTimeInterval(600))

        XCTAssertEqual(log.startedAt, ten)
    }

    /// The length logged is the time the click **sounded**, handed in from the engine — not the wall
    /// clock since Start, which would count the pause.
    func testFinishingLogsFromTheStartForTheTimeTheClickSounded() throws {
        var log = MetronomeRunLog()
        log.transportChanged(from: .stopped, to: .playing, at: ten)

        let run = try XCTUnwrap(log.finish(soundedSeconds: 125))

        XCTAssertEqual(run.start, ten)
        XCTAssertEqual(run.duration, 125)
        XCTAssertNil(log.startedAt, "a finished run is cleared")
    }

    /// Stop, then leave the screen: both are seams, and the second must find nothing to log.
    func testEndingTwiceLogsOnce() {
        var log = MetronomeRunLog()
        log.transportChanged(from: .stopped, to: .playing, at: ten)

        XCTAssertNotNil(log.finish(soundedSeconds: 90))
        XCTAssertNil(log.finish(soundedSeconds: 0), "leaving after Stop logged the sitting again")
    }

    /// Opening the screen and leaving without starting the click is not a run.
    func testLeavingWithoutStartingLogsNothing() {
        var log = MetronomeRunLog()
        XCTAssertNil(log.finish(soundedSeconds: 0))
    }

    /// Stop and Start again is a second run, starting from the second Start.
    func testStartingAgainAfterStopIsANewRun() {
        var log = MetronomeRunLog()
        log.transportChanged(from: .stopped, to: .playing, at: ten)
        _ = log.finish(soundedSeconds: 60)
        log.transportChanged(from: .stopped, to: .playing, at: ten.addingTimeInterval(300))

        XCTAssertEqual(log.startedAt, ten.addingTimeInterval(300))
    }

    // MARK: - The floor

    /// Thirty seconds for the metronome, one for everything else: the floor is keyed by kind, so a
    /// short exercise run is not dropped by a rule written for a tempo check.
    func testTheFloorIsThirtySecondsForTheMetronomeOnly() {
        XCTAssertEqual(PracticeLogWriter.minimumSeconds(for: .metronome), 30)
        for kind in PracticeRunKind.allCases where kind != .metronome {
            XCTAssertEqual(PracticeLogWriter.minimumSeconds(for: kind), PracticeLogWriter.minimumSeconds,
                           "\(kind) picked up the metronome's floor")
        }
    }

    /// The writer applies it: 29 seconds at the click is a tempo check and writes nothing; 30 is
    /// practice and writes one row with no unit and no tempo. A 5-second exercise still logs.
    func testTheWriterDropsAShortMetronomeRunAndKeepsAShortExercise() throws {
        let context = ModelContext(try ModelContainer(
            for: PracticeRun.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))

        XCTAssertFalse(PracticeLogWriter.log(kind: .metronome, startedAt: ten,
                                             endedAt: ten.addingTimeInterval(29), unitUID: nil,
                                             into: context))
        XCTAssertTrue(PracticeLogWriter.log(kind: .metronome, startedAt: ten,
                                            endedAt: ten.addingTimeInterval(30), unitUID: nil,
                                            into: context))
        XCTAssertTrue(PracticeLogWriter.log(kind: .exercise, startedAt: ten,
                                            endedAt: ten.addingTimeInterval(5), unitUID: UUID(),
                                            into: context))

        let runs = try context.fetch(FetchDescriptor<PracticeRun>())
        let metronome = runs.filter { $0.kind == .metronome }
        XCTAssertEqual(metronome.count, 1)
        XCTAssertEqual(metronome.first?.kindRaw, "metronome")
        XCTAssertEqual(metronome.first?.durationSeconds, 30)
        XCTAssertNil(metronome.first?.unitUID)
        XCTAssertNil(metronome.first?.tempoBPM)
        XCTAssertEqual(runs.count, 2)
    }

    // MARK: - The kind

    /// A raw `String` on the model, so no schema change. `metronome` reads back as itself here; a build
    /// from before ADR 0242 reads it as `.other` through the same accessor and still counts it.
    func testTheKindIsStoredAsItsRawString() {
        let run = PracticeRun(startedAt: ten, durationSeconds: 60, kind: .metronome)
        XCTAssertEqual(run.kindRaw, "metronome")
        XCTAssertEqual(run.kind, .metronome)
        XCTAssertEqual(run.record.kind, .metronome)
        XCTAssertEqual(PracticeRunKind.metronome.label, "Metronome")
        XCTAssertEqual(PracticeRunKind.metronome.groupLabel, "Metronome")
    }

    // MARK: - Decoding a kind this build doesn't know

    /// The synthesised decoder threw on an unknown raw value. Now it reads as `.other`, and the known
    /// ones — the new one included — still read as themselves.
    func testAnUnknownKindDecodesAsOther() throws {
        let decoded = try JSONDecoder().decode([PracticeRunKind].self,
                                               from: Data(#"["metronome","exercise","fromTheFuture"]"#.utf8))
        XCTAssertEqual(decoded, [.metronome, .exercise, .other])
    }

    /// Encoding is untouched: the raw value, so a decode of what this build writes is exact.
    func testEveryKindRoundTrips() throws {
        let all = PracticeRunKind.allCases
        XCTAssertEqual(try JSONDecoder().decode([PracticeRunKind].self, from: JSONEncoder().encode(all)), all)
    }

    /// **The reason for the rule.** One row of a kind this build has never heard of used to fail the
    /// whole backup as corrupt. Built by renaming a kind in a real archive, for the reason
    /// `PracticeArchiveTests` gives: a hand-written fixture names every key and goes stale.
    func testABackupHoldingAKindFromANewerBuildStillRestores() throws {
        var source = ArchiveSource()
        source.runs = [PracticeRun(startedAt: ten, durationSeconds: 600, kind: .metronome),
                       PracticeRun(startedAt: ten.addingTimeInterval(3600), durationSeconds: 300,
                                   kind: .exercise, unitUID: UUID())]
        let archive = ArchiveBuilder.snapshot(from: source, appVersion: "1.4 (1)",
                                              includesTakeAudio: false,
                                              exportedAt: Date(timeIntervalSince1970: 0))
        let full = try XCTUnwrap(String(bytes: ArchiveBuilder.encode(archive), encoding: .utf8))
        // Positive control: the kind has to be written for renaming it to mean anything.
        XCTAssertTrue(full.contains(#""kind" : "metronome""#))

        let newer = full.replacingOccurrences(of: #""kind" : "metronome""#,
                                              with: #""kind" : "aKindFromTheFuture""#)
        let decoded = try ArchiveBuilder.decode(Data(newer.utf8))

        XCTAssertEqual(decoded.practiceRuns.count, 2, "one unknown row must not cost the whole backup")
        XCTAssertEqual(decoded.practiceRuns.map(\.kind).sorted { $0.rawValue < $1.rawValue },
                       [.exercise, .other])
        XCTAssertEqual(decoded.practiceRuns.map(\.durationSeconds).reduce(0, +), 900,
                       "the unknown row's minutes still count")
    }
}
