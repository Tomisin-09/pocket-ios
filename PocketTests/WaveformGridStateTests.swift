import SwiftData
import XCTest
@testable import Pocket

/// What the "Loop controls" row offers in the Grid slot, which is a function of how much of the
/// tempo is known. The beat grid needs **both** a tempo and a downbeat — the BPM fixes the spacing,
/// the 1 fixes the phase, and `commitTempo` deliberately won't guess the phase (ADR 0022/0051). The
/// half-set state (BPM, no 1) used to draw nothing at all, which read on device as a broken grid;
/// `needsDownbeat` is what turns that silence into a **Set the 1** prompt. `@Model`s are used
/// uninserted (à la `WaveformSeekSnapTests`), never saved.
@MainActor
final class WaveformGridStateTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self,
            configurations: .init(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    private func makeModel(bpm: Double?, downbeat: TimeInterval?) throws -> WaveformPracticeModel {
        let song = Song.sample()
        song.preciseBPM = bpm
        song.bpm = bpm.map { Int($0.rounded()) }
        song.downbeatSeconds = downbeat
        return WaveformPracticeModel(song: song, context: try makeContext())
    }

    /// Tempo + the 1: the grid exists, so the slot is the Grid toggle and nothing prompts.
    func testTempoAndDownbeatMakeTheGridAvailable() throws {
        let model = try makeModel(bpm: 120, downbeat: 0)
        XCTAssertTrue(model.gridAvailable)
        XCTAssertFalse(model.needsDownbeat)
    }

    /// The reported state: a BPM was committed, the 1 never placed. No grid — and the prompt.
    func testTempoWithoutDownbeatPromptsForTheOne() throws {
        let model = try makeModel(bpm: 120, downbeat: nil)
        XCTAssertFalse(model.gridAvailable)
        XCTAssertTrue(model.needsDownbeat)
    }

    /// Nothing known yet: neither control belongs on the row — Set BPM is the next step, elsewhere.
    func testNoTempoOffersNeither() throws {
        let model = try makeModel(bpm: nil, downbeat: nil)
        XCTAssertFalse(model.gridAvailable)
        XCTAssertFalse(model.needsDownbeat)
    }

    /// A downbeat alone can't anchor a pulse with no tempo to space it — still no grid, and the
    /// prompt stays away because placing the 1 isn't what's missing.
    func testDownbeatWithoutTempoOffersNeither() throws {
        let model = try makeModel(bpm: nil, downbeat: 4)
        XCTAssertFalse(model.gridAvailable)
        XCTAssertFalse(model.needsDownbeat)
    }
}
