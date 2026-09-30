import XCTest
@testable import Pocket

/// **A written tab, stored and carried** (ADR 0235 D8): the payload a `WrittenTab` keeps, what an export
/// carries, what an archive written before 0235 does, and what a restore lands, on the saved progressions'
/// rules (ADR 0188 D1, D6).
final class WrittenTabTests: XCTestCase {

    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private let guitar = [64, 59, 55, 50, 45, 40]

    private var content: TabContent {
        TabContent(labels: [.fretted(string: 2, fret: 5), .fretted([FrettedNote(string: 2, fret: 7)], into: .legato),
                            .fretted([FrettedNote(string: 1, fret: 8, bend: 2, vibrato: true)], into: nil)],
                   bars: [2], sections: [TabSection(start: 0, name: "Intro")])
    }

    private var payload: WrittenTabPayload {
        WrittenTabPayload(content: content, openMidi: guitar, tuningLabel: "Guitar · Standard")
    }

    private func record(uid: UUID = UUID(), title: String = "Morning riff", payload: JSONValue?? = nil)
        -> WrittenTabRecord {
        WrittenTabRecord(uid: uid, title: title, createdAt: date, changedAt: date.addingTimeInterval(60),
                         payload: payload ?? JSONValue.decoding(self.payload.encoded))
    }

    private func archive(_ tabs: [WrittenTabRecord]?) -> PracticeArchive {
        PracticeArchive(exportedAt: date, appVersion: "1.4", includesTakeAudio: false, writtenTabs: tabs)
    }

    // MARK: - The payload

    func testAPayloadKeepsTheNotesBarsSectionsAndStrings() throws {
        let read = try XCTUnwrap(WrittenTabPayload.decoded(from: payload.encoded))
        XCTAssertEqual(read, payload)
        XCTAssertEqual(read.content, content)
        XCTAssertEqual(read.notes.bars, [2])
        XCTAssertEqual(read.notes.sections, [TabSection(start: 0, name: "Intro")])
        XCTAssertEqual(read.notes.openMidi, guitar)
        XCTAssertTrue(read.notes.hasStructure)
    }

    func testATabWithNoBarsOrSectionsWritesNoKeysForThem() throws {
        let plain = WrittenTabPayload(content: TabContent(labels: [.fretted(string: 1, fret: 3)]))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: plain.encoded) as? [String: Any])
        XCTAssertNil(object["bars"])
        XCTAssertNil(object["sections"])
        XCTAssertEqual(WrittenTabPayload.decoded(from: plain.encoded)?.content.bars, [])
    }

    /// A newer build's kind of note must not lose the tab: it reads as an unnamed note.
    func testANoteOfAKindThisBuildCantReadIsUnnamedNotLost() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload.encoded) as? [String: Any])
        var labels = try XCTUnwrap(object["labels"] as? [Any])
        labels[1] = ["kind": "harmonic", "fret": 12]
        object["labels"] = labels
        object["someFutureKey"] = true
        let read = try XCTUnwrap(WrittenTabPayload.decoded(from: JSONSerialization.data(withJSONObject: object)))
        XCTAssertEqual(read.labels.count, 3)
        XCTAssertNil(read.labels[1])
        XCTAssertEqual(read.labels[2], content.labels[2])
    }

    func testAPayloadWithNoNotesIsNotATab() {
        XCTAssertNil(WrittenTabPayload.decoded(from: Data("{\"version\": 1}".utf8)))
        XCTAssertNil(WrittenTabPayload.decoded(from: Data("not json".utf8)))
    }

    func testAnUntitledTabIsCalledSo() {
        XCTAssertEqual(WrittenTab(title: "  ").displayTitle, "Untitled tab")
        XCTAssertEqual(WrittenTab(title: " Riff ").displayTitle, "Riff")
        XCTAssertEqual(WrittenTab().payload.content, TabContent(), "an empty blob reads as an empty tab")
    }

    func testWritingStampsTheChange() {
        let tab = WrittenTab(createdAt: date, changedAt: date)
        tab.write(payload, at: date.addingTimeInterval(90))
        XCTAssertEqual(tab.changedAt, date.addingTimeInterval(90))
        XCTAssertEqual(tab.payload, payload)
    }

    // MARK: - Export

    @MainActor
    func testAnExportCarriesTheTabExactlyAsStoredOldestFirst() throws {
        let newer = WrittenTab(title: "Newer", createdAt: date.addingTimeInterval(100), tabData: payload.encoded)
        let older = WrittenTab(title: "Older", createdAt: date, tabData: payload.encoded)
        var source = ArchiveSource()
        source.writtenTabs = [newer, older]
        let written = ArchiveBuilder.snapshot(from: source, appVersion: "1.4", includesTakeAudio: false,
                                              exportedAt: date)
        let tabs = try XCTUnwrap(written.writtenTabs)
        XCTAssertEqual(tabs.map(\.title), ["Older", "Newer"])
        XCTAssertEqual(tabs[0].uid, older.uid)
        let carried = try JSONEncoder().encode(XCTUnwrap(tabs[0].payload))
        XCTAssertEqual(WrittenTabPayload.decoded(from: carried), payload)
    }

    func testWrittenTabsSurviveAnEncodeAndDecode() throws {
        let written = archive([record()])
        XCTAssertEqual(try ArchiveBuilder.decode(ArchiveBuilder.encode(written)).writtenTabs, written.writtenTabs)
    }

    /// **Why the field is `Optional`**: an archive from before 0235 has no such key, and one missing
    /// non-optional key fails the whole file.
    func testAnArchiveWrittenBeforeWrittenTabsStillDecodes() throws {
        let data = try ArchiveBuilder.encode(archive([record()]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "writtenTabs")
        XCTAssertNil(try ArchiveBuilder.decode(JSONSerialization.data(withJSONObject: object)).writtenTabs)
    }

    // MARK: - Restore

    @MainActor
    func testARestoreLandsTheTabWithItsUIDAndDates() throws {
        let original = record()
        let landing = ArchiveRestoreWriter.materialize(archive([original]), existing: RestoreExistingKeys())
        let landed = try XCTUnwrap(landing.writtenTabs.first)
        XCTAssertEqual(landed.uid, original.uid, "preserved, like every restored row's uid")
        XCTAssertEqual(landed.title, "Morning riff")
        XCTAssertEqual(landed.changedAt, original.changedAt)
        XCTAssertEqual(landed.payload, payload)
        XCTAssertEqual(landing.rowCount, 1, "a written tab is a library item the preview counts")
    }

    @MainActor
    func testOneTheLibraryAlreadyHasIsLeftAloneAndCountedAsPresent() {
        let original = record()
        var existing = RestoreExistingKeys()
        existing.writtenTabUIDs = [original.uid]
        XCTAssertTrue(ArchiveRestoreWriter.materialize(archive([original]), existing: existing).writtenTabs.isEmpty,
                      "nothing is overwritten (ADR 0188 D6)")
        let plan = RestorePlan.make(for: archive([original, record()]), existing: existing, takeAudio: [])
        let line = plan.lines.first { $0.kind == .writtenTabs }
        XCTAssertEqual(line?.landing, 1)
        XCTAssertEqual(line?.alreadyPresent, 1)
        XCTAssertEqual(RestorePlan.Kind.writtenTabs.label, "Written tabs")
    }

    @MainActor
    func testUnreadableRowsAreSkippedAndARepeatLandsOnce() {
        let uid = UUID()
        let empty = record(payload: .some(nil))
        let notATab = record(payload: JSONValue.decoding(Data("{\"version\": 1}".utf8)))
        let landing = ArchiveRestoreWriter.materialize(archive([record(uid: uid), record(uid: uid), empty, notATab]),
                                                       existing: RestoreExistingKeys())
        XCTAssertEqual(landing.writtenTabs.map(\.uid), [uid], "a tab is its notes; a row without them is skipped")
    }

    func testAnArchiveWithoutWrittenTabsHasNoSummaryLineForThem() {
        let plan = RestorePlan.make(for: archive(nil), existing: RestoreExistingKeys(), takeAudio: [])
        XCTAssertFalse(plan.lines.contains { $0.kind == .writtenTabs })
    }
}
