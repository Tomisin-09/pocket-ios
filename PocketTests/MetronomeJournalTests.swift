import XCTest
import SwiftData
@testable import Pocket

/// **A note written at the metronome records the metronome** (ADR 0160) — the sixth owner kind, and
/// the reversal of ADR 0155 §8's two refusals.
///
/// What these lock down is the pair of traps this feature walks into. The first is a schema one: no
/// `TimeSignature`, `Subdivision` or `ClickWithdrawal` may reach the `@Model`, because a custom type
/// as a SwiftData attribute crashes on migration **on device only** — which an in-memory test cannot
/// catch, so what is tested instead is that the round trip goes through raw columns and survives
/// every value they can hold. The second is the discriminator: a kind derived from something missing
/// is indistinguishable from a broken link, so the flag is stored and read in a fixed order.
final class MetronomeJournalTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    private func sitting(bpm: Int = 96, signature: TimeSignature = .standard,
                         subdivision: Subdivision = .eighths,
                         withdrawal: ClickWithdrawal = .gentle) -> MetronomeJournalContext {
        MetronomeJournalContext(bpm: bpm, timeSignature: signature, subdivision: subdivision,
                                withdrawal: withdrawal)
    }

    // MARK: - The model

    /// The whole snapshot goes down as raw values, and comes back as the same sitting. The column
    /// types are the assertion: `Int`, `Int`, `Int`, `String`, `String` — never an enum or a struct.
    func testTheSittingRoundTripsThroughRawColumns() throws {
        let entry = JournalEntry.forMetronome(text: "finally clean here", kind: .breakthrough,
                                              context: sitting(bpm: 132,
                                                               signature: TimeSignature.presets[3],
                                                               subdivision: .triplets,
                                                               withdrawal: .deep))
        XCTAssertEqual(entry.metronomeBpmAtEntry, 132)
        XCTAssertEqual(entry.metronomeBeatsAtEntry, 6)
        XCTAssertEqual(entry.metronomeNoteValueAtEntry, 8)
        XCTAssertEqual(entry.metronomeSubdivisionRaw, "triplets")
        XCTAssertEqual(entry.metronomeWithdrawalRaw, "deep")

        let restored = try XCTUnwrap(entry.metronomeContext)
        XCTAssertEqual(restored.bpm, 132)
        XCTAssertEqual(restored.timeSignature.name, "6/8")
        XCTAssertEqual(restored.timeSignature.accentBeats, [0, 3],
                       "a preset's accents are derived on read, not stored")
        XCTAssertEqual(restored.subdivision, .triplets)
        XCTAssertEqual(restored.withdrawal, .deep)
    }

    /// It is its own kind, and it is **not** a standalone note. The two flags partition: setting both
    /// would leave `ownerKind`'s ordering to decide which one counted.
    func testMetronomeIsItsOwnKindAndNotStandalone() {
        let entry = JournalEntry.forMetronome(text: "at the click", kind: .note, context: sitting())
        XCTAssertEqual(entry.ownerKind, .metronome)
        XCTAssertEqual(entry.isMetronome, true)
        XCTAssertNil(entry.isStandalone, "the flags partition — a metronome note is not standalone")
    }

    /// The kind comes from the **flag**, never from the columns being present. Strip the flag and the
    /// entry falls back to `.orphan` even with a full snapshot on it — which is exactly the failure a
    /// payload-derived kind would produce silently.
    func testTheKindComesFromTheFlagNotThePayload() {
        let entry = JournalEntry.forMetronome(text: "at the click", kind: .note, context: sitting())
        entry.isMetronome = nil
        XCTAssertEqual(entry.ownerKind, .orphan)
        XCTAssertNotNil(entry.metronomeContext, "the payload survived; only the classification went")
    }

    /// A unit relationship, and a routine id, still outrank the flag — the ADR 0143 ordering rule
    /// survives a sixth case being slotted under it.
    func testAnOwnerOutranksTheMetronomeFlag() {
        let exerciseEntry = JournalEntry.forExercise(text: "ex", kind: .note, commandBpmAtEntry: 96)
        exerciseEntry.exercise = Exercise(name: "Spider", currentTempo: 80, commandTempo: 96)
        exerciseEntry.isMetronome = true
        XCTAssertEqual(exerciseEntry.ownerKind, .exercise)

        let sessionEntry = JournalEntry.forSession(text: "good hour", kind: .session,
                                                   routineUID: UUID(), routineName: "Warm-up",
                                                   units: [])
        sessionEntry.isMetronome = true
        XCTAssertEqual(sessionEntry.ownerKind, .session)
    }

    /// A metronome note carries **no unit snapshot**. `commandBpmAtEntry` in particular stays nil: a
    /// free-play tempo is not a *command* — nothing was promoted or measured — and sharing that
    /// column would make `JournalSheet.bpmLabel`'s rhythm pairing wrong for half its rows (ADR 0121).
    func testMetronomeCarriesNoUnitSnapshotAndNoCaption() {
        let entry = JournalEntry.forMetronome(text: "at the click", kind: .note, context: sitting())
        XCTAssertNil(entry.commandBpmAtEntry, "a free-play tempo is not a command")
        XCTAssertNil(entry.commandNotesPerBeatAtEntry)
        XCTAssertNil(entry.masteryAtEntry)
        XCTAssertNil(entry.commandTempoAtEntry)
        XCTAssertNil(entry.routineUID)
        XCTAssertNil(entry.ownerLabelAtEntry, "the caption is a constant, never a snapshotted string")
    }

    /// Every row written before this reads exactly as it did. The flag and all five columns are
    /// additive optionals with no declaration default, so the migration is a no-op.
    func testAPreMetronomeRowIsUnaffected() {
        let entry = JournalEntry.forStandalone(text: "written before 0160", kind: .note)
        XCTAssertNil(entry.isMetronome)
        XCTAssertNil(entry.metronomeContext)
        XCTAssertEqual(entry.ownerKind, .standalone, "an old standalone note stays standalone")
    }

    // MARK: - The raw-value read path

    /// **`Subdivision.none` has the raw value `""`.** An empty string is a recorded "no subdivision";
    /// `nil` is "never recorded". Collapsing the two would be invisible in the UI and wrong in the
    /// store, so the distinction is pinned here.
    func testAnEmptySubdivisionRawIsAValueNotAMissingOne() throws {
        let recorded = try XCTUnwrap(MetronomeJournalContext(beats: 4, noteValue: 4, bpm: 90,
                                                             subdivisionRaw: "",
                                                             withdrawalRaw: "off"))
        XCTAssertEqual(recorded.subdivision, .none)

        let neverRecorded = try XCTUnwrap(MetronomeJournalContext(beats: 4, noteValue: 4, bpm: 90,
                                                                  subdivisionRaw: nil,
                                                                  withdrawalRaw: nil))
        XCTAssertEqual(neverRecorded.subdivision, .none, "an absent column degrades to the default")
        XCTAssertEqual(neverRecorded.withdrawal, .off)
    }

    /// A raw value this version doesn't know degrades to the default rather than failing the whole
    /// snapshot — the tempo and meter an old entry *does* know must still render.
    func testUnknownRawValuesDegradeRatherThanDiscardTheSnapshot() throws {
        let restored = try XCTUnwrap(MetronomeJournalContext(beats: 5, noteValue: 4, bpm: 108,
                                                             subdivisionRaw: "quintuplets",
                                                             withdrawalRaw: "brutal"))
        XCTAssertEqual(restored.bpm, 108)
        XCTAssertEqual(restored.timeSignature.name, "5/4")
        XCTAssertEqual(restored.subdivision, .none)
        XCTAssertEqual(restored.withdrawal, .off)
    }

    /// Without a meter there is no sitting to describe, so there is no context — which is what an
    /// entry misclassified by a future bug would produce, and why the row renders nothing for it.
    func testAMissingMeterYieldsNoContext() {
        XCTAssertNil(MetronomeJournalContext(beats: nil, noteValue: 4, bpm: 96,
                                             subdivisionRaw: "eighths", withdrawalRaw: "off"))
        XCTAssertNil(MetronomeJournalContext(beats: 4, noteValue: nil, bpm: 96,
                                             subdivisionRaw: "eighths", withdrawalRaw: "off"))
    }

    // MARK: - The caption

    /// The feed line drops the two defaults — a caption that reads "off" on nearly every entry
    /// teaches nothing — and keeps tempo and meter always, because those are the sitting.
    func testSummaryDropsTheDefaultsAndKeepsTheSitting() {
        XCTAssertEqual(sitting(bpm: 96, subdivision: .eighths, withdrawal: .gentle).summary,
                       "96 BPM · 4/4 · ♫ · gentle withdrawal")
        XCTAssertEqual(sitting(bpm: 72, subdivision: .none, withdrawal: .off).summary,
                       "72 BPM · 4/4")
        XCTAssertEqual(sitting(bpm: 120, signature: TimeSignature.presets[4],
                               subdivision: .none, withdrawal: .standard).summary,
                       "120 BPM · 12/8 · standard withdrawal")
    }

    // MARK: - The feed

    /// The caption is a constant, and it goes **nowhere**: the metronome screen exists, but opening
    /// it would restore whatever state it was left in rather than the sitting the note describes.
    func testTheFeedLabelsItMetronomeAndRoutesNowhere() {
        let entry = JournalEntry.forMetronome(text: "at the click", kind: .note, context: sitting())
        let item = JournalTimeline.Item.note(entry)
        XCTAssertEqual(JournalTimeline.ownerLabel(for: item), "Metronome")
        XCTAssertNil(JournalOwnerRoute.route(for: item),
                     "a caption must never promise a destination it can't reach")
        XCTAssertTrue(JournalTimeline.searchHaystack(for: item).contains("metronome"),
                      "the constant caption makes 'metronome' a search term for free")
    }

    // MARK: - The write seam

    /// Writing through the sixth owner stores the snapshot it was handed — **already taken**, at the
    /// moment the composer opened (ADR 0160 §5), not re-read here.
    func testWriterStoresTheSittingItWasHanded() throws {
        let context = try makeContext()
        XCTAssertTrue(JournalWriter.add(to: .metronome(sitting(bpm: 84, subdivision: .sixteenths,
                                                               withdrawal: .off)),
                                        text: "  hands break down here  ", kind: .struggle,
                                        into: context))
        let entry = try XCTUnwrap(try context.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(entry.text, "hands break down here", "text is trimmed")
        XCTAssertEqual(entry.ownerKind, .metronome)
        XCTAssertEqual(entry.metronomeContext?.bpm, 84)
        XCTAssertEqual(entry.metronomeContext?.subdivision, .sixteenths)
        XCTAssertNil(entry.loop)
        XCTAssertNil(entry.exercise)
    }

    /// An all-whitespace note writes nothing, on this owner as on every other.
    func testWriterIgnoresWhitespaceOnlyText() throws {
        let context = try makeContext()
        XCTAssertFalse(JournalWriter.add(to: .metronome(sitting()), text: "   \n ", kind: .note,
                                         into: context))
        XCTAssertTrue(try context.fetch(FetchDescriptor<JournalEntry>()).isEmpty)
    }

    /// The composer's footer promises a snapshot, unlike the standalone one which promises none.
    func testTheComposerSaysWhatItSnapshots() {
        XCTAssertEqual(JournalOwner.metronome(sitting()).destinationLine,
                       "Saves straight to your Journal, snapshotting the click you're playing to.")
        XCTAssertTrue(JournalOwner.metronome(sitting()).entries.isEmpty,
                      "a metronome owner holds no journal to read back")
    }

    // MARK: - The engine

    /// The snapshot reads the withdrawal **in force**, not the one configured. A ramp suspends
    /// withdrawal (ADR 0132 §4), so a note written mid-climb must not claim one the player never
    /// heard — and the host opt-in is what makes the field meaningful on this owner and no other.
    @MainActor
    func testEngineSnapshotsTheWithdrawalInForce() {
        // `AppSettings.clickWithdrawal` reads `UserDefaults.standard`, shared across the suite.
        let key = AppSettings.Key.clickWithdrawal
        let previous = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.set(ClickWithdrawal.deep.rawValue, forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let engine = StandaloneMetronomeEngine()
        engine.allowsClickWithdrawal = true
        engine.setBPM(104)
        engine.setTimeSignature(TimeSignature.presets[1])
        engine.setSubdivision(.eighths)

        let onTheClick = engine.journalContext
        XCTAssertEqual(onTheClick.bpm, 104)
        XCTAssertEqual(onTheClick.timeSignature.name, "3/4")
        XCTAssertEqual(onTheClick.subdivision, .eighths)
        XCTAssertEqual(onTheClick.withdrawal, .deep)

        // A host that never opted in hears no withdrawal, so it records none.
        engine.allowsClickWithdrawal = false
        XCTAssertEqual(engine.journalContext.withdrawal, .off)
    }
}
