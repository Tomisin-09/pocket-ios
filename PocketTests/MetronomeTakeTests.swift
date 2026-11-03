import XCTest
@testable import Pocket

/// **A take recorded at the metronome records the click** (ADR 0287) — the take-shaped twin of the
/// metronome note (ADR 0160), so it walks into the same two traps and is held to the same answers.
///
/// The schema trap: the click goes down as raw columns, never a `TimeSignature`, `Subdivision` or
/// `ClickWithdrawal`, because a custom type on a `@Model` crashes a migration on device only. The
/// discriminator trap: a take with no owner relationship is an orphan unless a stored flag says
/// otherwise, so the flag is what makes it a metronome take, and it never doubles as standalone.
///
/// Every `Recording` here is **uninserted**: the owner logic reads properties only, and an insert
/// in the test host is its own trap (`docs/swiftdata-gotchas.md`).
final class MetronomeTakeTests: XCTestCase {

    private func sitting(bpm: Int = 96, signature: TimeSignature = .standard,
                         subdivision: Subdivision = .eighths,
                         withdrawal: ClickWithdrawal = .gentle) -> MetronomeJournalContext {
        MetronomeJournalContext(bpm: bpm, timeSignature: signature, subdivision: subdivision,
                                withdrawal: withdrawal)
    }

    private func metronomeTake(_ context: MetronomeJournalContext) -> Recording {
        let take = Recording(fileName: "t.m4a", duration: 30)
        RecordingOwner.metronome(context).attach(to: take)
        return take
    }

    // MARK: - The model

    /// The whole click goes down as raw values and comes back as the same sitting.
    func testTheClickRoundTripsThroughRawColumns() throws {
        let take = metronomeTake(sitting(bpm: 132, signature: TimeSignature.presets[3],
                                         subdivision: .triplets, withdrawal: .deep))
        XCTAssertEqual(take.metronomeBpmAtTake, 132)
        XCTAssertEqual(take.metronomeBeatsAtTake, 6)
        XCTAssertEqual(take.metronomeNoteValueAtTake, 8)
        XCTAssertEqual(take.metronomeSubdivisionRaw, "triplets")
        XCTAssertEqual(take.metronomeWithdrawalRaw, "deep")

        let restored = try XCTUnwrap(take.metronomeContext)
        XCTAssertEqual(restored, sitting(bpm: 132, signature: TimeSignature.presets[3],
                                         subdivision: .triplets, withdrawal: .deep))
    }

    /// Its own kind, and not standalone: the flags partition.
    func testAMetronomeTakeIsItsOwnKindAndNotStandalone() {
        let take = metronomeTake(sitting())
        XCTAssertEqual(take.ownerKind, .metronome)
        XCTAssertEqual(take.isMetronome, true)
        XCTAssertNil(take.isStandalone, "the flags partition — a metronome take is not standalone")
        XCTAssertNil(take.loop)
        XCTAssertNil(take.exercise)
        XCTAssertNil(take.song)
    }

    /// Every take recorded before this has `nil` in the new columns, and must read exactly as it did.
    func testAnEarlierTakeIsUnchanged() {
        let orphan = Recording(fileName: "t.m4a", duration: 30)
        XCTAssertEqual(orphan.ownerKind, Recording.OwnerKind.none)
        XCTAssertNil(orphan.metronomeContext)

        let standalone = Recording(fileName: "t.m4a", duration: 30)
        RecordingOwner.standalone.attach(to: standalone)
        XCTAssertEqual(standalone.ownerKind, .standalone)
        XCTAssertNil(standalone.isMetronome)
        XCTAssertNil(standalone.ownerLabelAtTake, "a standalone take still has no caption")
    }

    // MARK: - The Journal

    /// The caption is written at capture, so every fallback that reads `ownerLabelAtTake` (the take
    /// screen, the export file name) says "Metronome" with no branch of its own.
    func testTheCaptionIsWrittenAtCaptureAndTheFeedReadsIt() {
        let take = metronomeTake(sitting())
        XCTAssertEqual(take.ownerLabelAtTake, "Metronome")
        XCTAssertEqual(JournalTimeline.ownerLabel(for: .take(take)), "Metronome")
    }

    /// The Journal's Metronome filter brings the takes recorded there along with the notes.
    func testTheMetronomeFilterBringsTheTake() {
        let take = metronomeTake(sitting())
        XCTAssertEqual(JournalTimeline.OwnerFilter.bucket(for: .take(take)), .metronome)
    }

    /// There is no unit behind the click, so the caption is plain text, never a link.
    func testTheCaptionLeadsNowhere() {
        XCTAssertNil(JournalOwnerRoute.route(for: .take(metronomeTake(sitting()))))
    }

    /// Nor does it join a thread (ADR 0286): the count is per exercise or loop, and the click is neither.
    func testAMetronomeTakeBelongsToNoThread() {
        let take = metronomeTake(sitting())
        XCTAssertNil(JournalTimeline.unit(for: .take(take)))
        XCTAssertTrue(JournalTimeline.unitCounts([.take(take), .take(metronomeTake(sitting()))]).isEmpty)
    }

    // MARK: - The archive

    /// The six columns travel out through the builder and back through the restore writer.
    @MainActor
    func testTheClickSurvivesTheArchive() throws {
        let take = metronomeTake(sitting(bpm: 72, subdivision: .none, withdrawal: .off))
        let record = ArchiveBuilder.recordingRecord(take)
        XCTAssertEqual(record.isMetronome, true)
        XCTAssertEqual(record.metronomeBpmAtTake, 72)
        XCTAssertEqual(record.metronomeSubdivisionRaw, "", "no subdivision is a recorded empty string")

        var landing = RestoredLibrary()
        ArchiveRestoreWriter.addTakes([record], existing: RestoreExistingKeys(), into: &landing,
                                      resolver: RestoreResolver())
        let restored = try XCTUnwrap(landing.takes.first?.0)
        XCTAssertEqual(restored.ownerKind, .metronome)
        XCTAssertEqual(restored.metronomeContext, take.metronomeContext)
        XCTAssertEqual(restored.ownerLabelAtTake, "Metronome")
    }

    /// The TakesSheet's query keeps only metronome takes; this is the filter it applies in memory
    /// (no `#Predicate` on an optional — `docs/swiftdata-gotchas.md`).
    func testOnlyMetronomeTakesAreListedAtTheMetronome() {
        let click = metronomeTake(sitting())
        let other = Recording(fileName: "o.m4a", duration: 30)
        RecordingOwner.standalone.attach(to: other)
        XCTAssertEqual(Recording.metronomeTakes(in: [click, other]).map(\.uid), [click.uid])
    }
}
