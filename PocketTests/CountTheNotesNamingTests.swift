import SwiftData
import XCTest
@testable import Pocket

/// Name the notes' Done, back in the count (ADR 0231): a pass, or the saved piece, takes the taps the sheet
/// hands back, a note added or taken out included, and the request carries the loop's region.
@MainActor
final class CountTheNotesNamingTests: XCTestCase {

    private func makeLoop() -> Loop {
        let loop = Loop(name: "Lick", start: 0.1, end: 0.2, speed: 1, repeats: 1)
        loop.song = Song(title: "Slow Bend", duration: 100, ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        return loop
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Song.self, Loop.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    func testAPassTakesTheTapsTheSheetHandsBack() throws {
        let model = CountTheNotesModel(loop: makeLoop())
        model.loopStarted()
        for elapsed in [0.5, 1.0] {
            model.tap(clock: LoopClockReading(elapsed: elapsed, regionStart: 10, passLength: 10, rate: 1,
                                              outputLatency: 0))
        }
        model.nameTarget()
        let request = try XCTUnwrap(model.naming)
        XCTAssertEqual(request.region, 10...20, "the loop's region, which bounds the stretch")
        let added = PassCorrection.adding(10.75, to: request.taps).taps
        model.finishNaming(request, result: NamingResult(taps: added, openMidi: [], tuningLabel: ""),
                           context: try makeContext())
        XCTAssertEqual(model.targetPass?.taps.map(\.seconds), [10.5, 10.75, 11], "the note tapped in is kept")
    }

    func testASavedPieceTakesTheTapsAndIsRedated() throws {
        let loop = makeLoop()
        loop.transcription = PieceTranscription(taps: [.init(seconds: 10.5, label: .pitchClass(9)),
                                                       .init(seconds: 10.6), .init(seconds: 11)])
        let model = CountTheNotesModel(loop: loop)
        model.nameSaved()
        let request = try XCTUnwrap(model.naming)
        let removed = try XCTUnwrap(PassCorrection.removing(at: 1, from: request.taps))
        model.finishNaming(request, result: NamingResult(taps: removed, openMidi: [], tuningLabel: ""),
                           context: try makeContext())
        XCTAssertEqual(loop.transcription?.taps.map(\.seconds), [10.5, 11], "the tap taken out is gone")
        XCTAssertEqual(loop.transcription?.taps.first?.label, .pitchClass(9), "the names stay")
        XCTAssertNotNil(loop.transcription?.changedAt, "dated to the day it changed")
    }
}
