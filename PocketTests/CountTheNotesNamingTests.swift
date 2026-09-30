import SwiftData
import XCTest
@testable import Pocket

/// Name the notes and the count (ADR 0231, 0234): only a saved piece is named, it takes the taps the sheet
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

    /// Save first, then name (ADR 0234 D1): a pass has nothing to name until it's saved, and it's saved with
    /// no names and so no tuning. Naming then opens on the saved piece, bounded by the loop's region.
    func testAPassIsSavedUnnamedAndNamingOpensOnlyOnTheSavedPiece() throws {
        let loop = makeLoop()
        let model = CountTheNotesModel(loop: loop)
        model.loopStarted()
        for elapsed in [0.5, 1.0] {
            model.tap(clock: LoopClockReading(elapsed: elapsed, regionStart: 10, passLength: 10, rate: 1,
                                              outputLatency: 0))
        }
        model.nameSaved()
        XCTAssertNil(model.naming, "nothing is saved yet, so there is nothing to name")
        model.save(context: try makeContext())
        let piece = try XCTUnwrap(loop.transcription)
        XCTAssertEqual(piece.taps.map(\.seconds), [10.5, 11])
        XCTAssertTrue(piece.labels.allSatisfy { $0 == nil }, "saved with nothing named")
        XCTAssertNil(piece.openMidi, "no frets, so no tuning recorded")
        model.nameSaved()
        let request = try XCTUnwrap(model.naming)
        XCTAssertEqual(request.taps, piece.taps)
        XCTAssertEqual(request.region, 10...20, "the loop's region, which bounds the stretch")
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
