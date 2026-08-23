import XCTest
@testable import Pocket

/// The recorder's own half — merging, capping and persisting. MetricKit itself cannot be driven from
/// a test (no payload can be constructed, and the manager only delivers on a real device roughly
/// daily), so `record` is internal and this drives it directly. Everything the recorder *decides* is
/// in `DiagnosticSummary` and tested there.
@MainActor
final class DiagnosticsRecorderTests: XCTestCase {

    private final class TempContainer: FileManager {
        let root: URL

        init(root: URL) {
            self.root = root
            super.init()
        }

        override func url(for directory: FileManager.SearchPathDirectory,
                          in domain: FileManager.SearchPathDomainMask,
                          appropriateFor url: URL?, create: Bool) throws -> URL {
            guard directory == .applicationSupportDirectory else {
                return try super.url(for: directory, in: domain, appropriateFor: url, create: create)
            }
            return root
        }
    }

    private var root: URL!
    private var files: TempContainer!

    override func setUpWithError() throws {
        root = URL.temporaryDirectory.appending(path: "recorder-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        files = TempContainer(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func recorder(seeded: [DiagnosticEvent]? = nil) -> DiagnosticsRecorder {
        DiagnosticsRecorder(usesSystemMetrics: false, seeded: seeded, files: files)
    }

    private func event(daysAgo: Double, detail: String? = nil) -> DiagnosticEvent {
        DiagnosticEvent(kind: .crash, date: Date.now.addingTimeInterval(-daysAgo * 86_400),
                        detail: detail, appBuild: "4", systemVersion: "18.5")
    }

    func testStartsEmptyWithNothingOnDisk() {
        XCTAssertTrue(recorder().events.isEmpty)
        XCTAssertNil(recorder().supportLine)
    }

    func testRecordedEventsSurviveANewInstance() {
        recorder().record([event(daysAgo: 1, detail: "SIGTRAP")])
        // A second recorder over the same container reads what the first wrote. This is the whole
        // point of persisting: MetricKit delivers once and the app is very likely to be relaunched
        // before anyone opens the screen.
        XCTAssertEqual(recorder().events.map(\.detail), ["SIGTRAP"])
    }

    func testRecordingMergesRatherThanReplaces() {
        let recorder = recorder()
        recorder.record([event(daysAgo: 2, detail: "first")])
        recorder.record([event(daysAgo: 1, detail: "second")])
        XCTAssertEqual(recorder.events.map(\.detail), ["second", "first"],
                       "Newest first, and the earlier delivery still present — a second payload "
                        + "replacing the first would lose the pattern the screen exists to show")
    }

    func testRecordingIsCappedNoMatterHowManyArriveAtOnce() {
        let recorder = recorder()
        recorder.record((1...20).map { event(daysAgo: Double($0)) })
        XCTAssertEqual(recorder.events.count, DiagnosticSummary.retained)
    }

    func testAnEmptyDeliveryChangesNothing() {
        let recorder = recorder(seeded: [event(daysAgo: 1, detail: "kept")])
        recorder.record([])
        XCTAssertEqual(recorder.events.map(\.detail), ["kept"])
    }

    func testClearEmptiesTheScreenAndTheDisk() {
        let recorder = recorder()
        recorder.record([event(daysAgo: 1)])
        recorder.clear()
        XCTAssertTrue(recorder.events.isEmpty)
        XCTAssertTrue(self.recorder().events.isEmpty, "Clear has to reach the file, not just the "
                      + "array — otherwise it comes back on the next launch")
    }

    func testSupportLineIsTheSameOneDiagnosticSummaryRenders() {
        let events = [event(daysAgo: 1, detail: "EXC_BAD_ACCESS"), event(daysAgo: 3)]
        let recorder = recorder(seeded: events)
        XCTAssertEqual(recorder.supportLine, DiagnosticSummary.line(for: recorder.events))
        XCTAssertNotNil(recorder.supportLine)
    }
}
