import XCTest
@testable import Pocket

/// The Toolkit's rows in one place (ADR 0235 D2, D6): the hub draws them and the Home tile beside Toolkit
/// offers them. The five rows the hub had before My tabs keep their words exactly: the manual quotes them
/// (`check-manual.py` C2) and the UI tests reach them by their spoken labels (ADR 0197 D2).
final class ToolkitSectionTests: XCTestCase {

    func testTheRowsAreInTheHubsOrderWithMyTabsAfterMyProgressions() {
        XCTAssertEqual(ToolkitSection.allCases.map(\.info.title),
                       ["My chords", "My progressions", "My tabs", "Tuner", "Glossary", "Help & FAQs"])
    }

    func testTheRowsThatWereThereSayWhatTheyAlwaysSaid() {
        let said = ToolkitSection.allCases.filter { $0 != .myTabs }.map { [$0.info.icon, $0.info.subtitle] }
        XCTAssertEqual(said, [["square.grid.2x2", "Your saved voicings"],
                              ["list.bullet", "Progressions you've written"],
                              ["tuningfork", "Tune by ear or mic"],
                              ["text.book.closed", "Chord, scale & theory terms"],
                              ["questionmark.circle", "How Red Moon works"]])
        XCTAssertEqual(ToolkitSection.tuner.info.spoken, "Tuner, tune by ear or mic")
        XCTAssertEqual(ToolkitSection.glossary.info.spoken, "Glossary, chord, scale and theory terms")
        XCTAssertEqual(ToolkitSection.help.info.spoken, "Help and FAQs, how Red Moon works",
                       "the ampersand spelled out: it's read aloud, and the Toolkit UI test matches on it")
    }

    func testMyTabs() {
        XCTAssertEqual(ToolkitSection.myTabs.info.subtitle, "Tabs you write on the neck")
        XCTAssertEqual(ToolkitSection.myTabs.info.spoken, "My tabs, tabs you write on the neck")
    }

    /// The raw values are what the Home tile's choice is stored as, so renaming a case must not move them.
    func testTheStoredNamesNeverChange() {
        XCTAssertEqual(ToolkitSection.allCases.map(\.rawValue),
                       ["myChords", "myProgressions", "myTabs", "tuner", "glossary", "help"])
    }

    func testEverySpokenLabelStartsWithItsTitle() {
        for section in ToolkitSection.allCases where section != .help {
            XCTAssertTrue(section.info.spoken.hasPrefix(section.info.title + ", "), section.rawValue)
        }
    }

    // MARK: - A written tab in the list

    func testATabsLineSaysItsNotesSectionsAndInstrument() {
        let content = TabContent(labels: Array(repeating: .fretted(string: 1, fret: 3), count: 30),
                                 sections: [TabSection(start: 0, name: "Intro"), TabSection(start: 8, name: "Verse"),
                                            TabSection(start: 20, name: "Chorus"),
                                            TabSection(start: 30, name: "Outro")])
        let payload = WrittenTabPayload(content: content, tuningLabel: "Guitar · Standard")
        XCTAssertEqual(payload.summary, "30 notes · 3 sections · Guitar · Standard",
                       "a heading waiting for the next note isn't a section yet")
        XCTAssertEqual(WrittenTabPayload(content: TabContent(labels: [.fretted(string: 1, fret: 3)])).summary, "1 note")
        XCTAssertEqual(WrittenTabPayload(content: TabContent()).summary, "No notes yet")
    }

    func testWhenItChangedReadsAsTheJournalsDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 21)))
        XCTAssertEqual(WrittenTab.day(now.addingTimeInterval(-3600), now: now, calendar: calendar), "Today")
        XCTAssertEqual(WrittenTab.day(now.addingTimeInterval(-86_400), now: now, calendar: calendar), "Yesterday")
        let earlier = now.addingTimeInterval(-4 * 86_400)
        XCTAssertEqual(WrittenTab.day(earlier, now: now, calendar: calendar),
                       earlier.formatted(date: .abbreviated, time: .omitted))
    }
}
