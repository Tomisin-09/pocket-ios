import XCTest
@testable import Pocket

/// **How the References library groups** (ADR 0275): *Newest* as ADR 0264 D4 drew it, by *Site*, and by
/// *Where it's used*; what search leaves; what a row says under each; and the stored choice.
///
/// On **uninserted** models, as `ReferenceLibraryTests` is: these rules read rows and write nothing.
final class ReferenceGroupingTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func link(_ title: String, url: String, added minutes: Double = 0, exercise: Exercise? = nil,
                      song: Song? = nil, loop: Loop? = nil, routine: Routine? = nil) -> ReferenceLink {
        ReferenceLink(title: title, urlString: url, dateAdded: base.addingTimeInterval(minutes * 60),
                      exercise: exercise, song: song, loop: loop, routine: routine)
    }

    private func file(_ title: String, kind: ReferenceLinkKind, added minutes: Double = 0) -> ReferenceLink {
        ReferenceLink(title: title, attachmentFileName: "\(UUID().uuidString).\(kind.fileExtension)",
                      dateAdded: base.addingTimeInterval(minutes * 60), kind: kind)
    }

    private func song(_ title: String) -> Song {
        Song(title: title, duration: 180, ref: SongRef(id: title, source: .localFile, bookmark: nil))
    }

    private func groups(_ links: [ReferenceLink], by grouping: ReferenceGrouping,
                        matching query: String = "") -> [ReferenceGroup] {
        ReferenceLibrary.groups(ReferenceLibrary.sources(links), by: grouping, matching: query)
    }

    private func titles(_ group: ReferenceGroup?) -> [String] { group?.sources.map(\.displayTitle) ?? [] }

    // MARK: - Newest (0264 D4, unchanged)

    /// *Not filed* with its count, then *Everything* without one: the library as it was.
    func testNewestIsTheTwoSectionsAsDrawn() {
        let found = groups([link("Kept", url: "https://example.com/k", added: 2),
                            link("Filed", url: "https://example.com/f", added: 1,
                                 exercise: Exercise(name: "Spider")),
                            link("Also kept", url: "https://example.com/a", added: 3)], by: .newest)
        XCTAssertEqual(found.map(\.title), ["Not filed", "Everything"])
        XCTAssertEqual(found.map(\.showsCount), [true, false])
        XCTAssertEqual(titles(found.first), ["Also kept", "Kept"])
        XCTAssertEqual(titles(found.last), ["Filed"])
    }

    func testAnEmptySectionIsLeftOut() {
        let filedOnly = groups([link("Filed", url: "https://example.com/f", exercise: Exercise(name: "Spider"))],
                               by: .newest)
        XCTAssertEqual(filedOnly.map(\.title), ["Everything"])
        XCTAssertTrue(groups([], by: .site).isEmpty)
        XCTAssertTrue(groups([], by: .place).isEmpty)
    }

    // MARK: - Site

    /// Sites A to Z, then the kinds of file in the order the app lists them, each source newest first.
    /// A phone's copy of a site and YouTube's short links are the site itself.
    func testSiteGroupsLinksBySiteThenFilesByKind() {
        let found = groups([
            link("Bends", url: "https://www.youtube.com/watch?v=a", added: 1),
            link("Triads", url: "https://youtu.be/b", added: 4, exercise: Exercise(name: "Triad climb")),
            link("Vibrato", url: "https://m.youtube.com/watch?v=c", added: 2),
            link("Riff tab", url: "https://songsterr.com/a/1", added: 3),
            file("Chart", kind: .pdf, added: 5),
            file("Shape", kind: .image, added: 6),
            file("Tab", kind: .text, added: 7),
            link("Album", url: "https://bandcamp.com/x", added: 8)
        ], by: .site)
        XCTAssertEqual(found.map(\.title), ["bandcamp.com", "songsterr.com", "youtube.com", "Pictures", "PDFs",
                                            "Text files"])
        XCTAssertEqual(titles(found.first { $0.title == "youtube.com" }), ["Triads", "Vibrato", "Bends"],
                       "a site's sources run newest first, filed or not")
        XCTAssertTrue(found.allSatisfy(\.showsCount))
    }

    /// Sites sort as a person reads them, not by code point: a number reads as a number.
    func testSitesSortAsTheyRead() {
        let found = groups([link("b", url: "https://site10.com/a"), link("a", url: "https://site9.com/a")],
                           by: .site)
        XCTAssertEqual(found.map(\.title), ["site9.com", "site10.com"])
    }

    /// A link with no site to read (a row written by hand, or by a newer build) goes last, under *Other*.
    func testALinkWithNoSiteIsOther() {
        let found = groups([link("Odd", url: ""), file("Notes", kind: .markdown),
                            link("Lesson", url: "https://example.com/a")], by: .site)
        XCTAssertEqual(found.map(\.title), ["example.com", "Markdown files", "Other"])
    }

    // MARK: - Where it's used

    /// *Not filed*, then the kinds of place in *Show everything*'s order.
    func testPlaceGroupsNotFiledThenEachKindInThePickersOrder() {
        let slowBend = song("Slow Bend")
        let verse = Loop(name: "Verse riff", start: 0.1, end: 0.2, speed: 1.0, repeats: 4)
        verse.song = slowBend
        let found = groups([
            link("On a loop", url: "https://example.com/1", added: 1, loop: verse),
            link("On a song", url: "https://example.com/2", added: 2, song: slowBend),
            link("On a routine", url: "https://example.com/3", added: 3, routine: Routine(name: "Morning")),
            link("On a drill", url: "https://example.com/4", added: 4, exercise: Exercise(name: "Spider")),
            link("Kept", url: "https://example.com/5", added: 5)
        ], by: .place)
        XCTAssertEqual(found.map(\.title), ["Not filed", "Exercises", "Routines", "Songs", "Loops"])
        XCTAssertEqual(found.map { titles($0) },
                       [["Kept"], ["On a drill"], ["On a routine"], ["On a song"], ["On a loop"]])
        XCTAssertTrue(found.allSatisfy(\.showsCount))
    }

    /// A source on a drill and a song is under both; on two drills, it's under Exercises once.
    func testASourceIsUnderEveryKindItsUsedOnOnce() {
        let found = groups([
            link("Triads", url: "https://example.com/t", added: 0, exercise: Exercise(name: "Triad climb")),
            link("Triads", url: "https://example.com/t", added: 1, exercise: Exercise(name: "Spider")),
            link("Triads", url: "https://example.com/t", added: 2, song: song("Slow Bend"))
        ], by: .place)
        XCTAssertEqual(found.map(\.title), ["Exercises", "Songs"])
        XCTAssertEqual(found.map { titles($0) }, [["Triads"], ["Triads"]])
    }

    /// A filed source that also has a row kept for later is filed (0264 D3): not under *Not filed*.
    func testAFiledSourceWithAKeptRowIsNotUnderNotFiled() {
        let found = groups([link("Triads", url: "https://example.com/t", added: 0),
                            link("Triads", url: "https://example.com/t", added: 1, exercise: Exercise(name: "Spider"))],
                           by: .place)
        XCTAssertEqual(found.map(\.title), ["Exercises"])
    }

    // MARK: - Search

    /// A search keeps the sources it finds, under every grouping, and drops the sections it empties.
    func testSearchNarrowsEveryGroupingAndDropsEmptiedSections() {
        let links = [link("Hybrid picking", url: "https://youtube.com/watch?v=a"),
                     link("Bends", url: "https://songsterr.com/b", exercise: Exercise(name: "Spider"))]
        XCTAssertEqual(groups(links, by: .newest, matching: "hybrid").map(\.title), ["Not filed"])
        XCTAssertEqual(groups(links, by: .site, matching: "  BENDS ").map(\.title), ["songsterr.com"])
        XCTAssertEqual(groups(links, by: .place, matching: "spider").map(\.title), ["Exercises"])
        XCTAssertTrue(groups(links, by: .site, matching: "nothing like it").isEmpty)
    }

    // MARK: - The rows, and the stored choice

    /// Only *Site* hides a row's site, which its heading says, and marks a row not filed, since only
    /// there does one share a section with filed ones. *Newest* alone doesn't fold.
    func testWhatEachGroupingAsksOfTheRows() {
        XCTAssertEqual(ReferenceGrouping.allCases.map(\.collapses), [false, true, true])
        XCTAssertEqual(ReferenceGrouping.allCases.map(\.rowShowsOrigin), [true, false, true])
        XCTAssertEqual(ReferenceGrouping.allCases.map(\.rowMarksNotFiled), [false, true, false])
        XCTAssertEqual(ReferenceGrouping.allCases.map(\.label), ["Newest", "Site", "Where it's used"])
    }

    /// The raw values are what a player's choice is stored as, so they can't change; and an install that
    /// never chose opens on the library as it was.
    func testTheStoredChoice() {
        XCTAssertEqual(ReferenceGrouping.allCases.map(\.rawValue), ["newest", "site", "place"])
        XCTAssertEqual(AppSettings.referencesGroupingDefault, .newest)
    }

    func testTheUITestResetClearsBothKeys() throws {
        let suite = "ReferenceGroupingTests.\(UUID().uuidString)"
        let store = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }
        store.set("site", forKey: AppSettings.Key.referencesGrouping)
        store.set("[\"x\"]", forKey: AppSettings.Key.referencesCollapsedSections)
        AppSettings.resetReferencesLayout(store: store)
        XCTAssertNil(store.object(forKey: AppSettings.Key.referencesGrouping))
        XCTAssertNil(store.object(forKey: AppSettings.Key.referencesCollapsedSections))
    }
}
