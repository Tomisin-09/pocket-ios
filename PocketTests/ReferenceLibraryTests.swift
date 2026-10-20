import XCTest
@testable import Pocket

/// **The References library's rules** (ADR 0264 D3, D4, D5, and D2's toast line): how rows group into
/// sources, how sources split into sections, what search finds, and the words the screens say.
///
/// All on **uninserted** models: these rules read rows and write nothing, so no store is needed and
/// none of the XCTest host's insert traps apply (`docs/swiftdata-gotchas.md`).
final class ReferenceLibraryTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func at(_ minutes: Double) -> Date { base.addingTimeInterval(minutes * 60) }

    private func link(_ title: String = "", url: String = "https://youtube.com/watch?v=a", note: String = "",
                      added minutes: Double = 0, exercise: Exercise? = nil, song: Song? = nil, loop: Loop? = nil,
                      routine: Routine? = nil) -> ReferenceLink {
        ReferenceLink(title: title, note: note, urlString: url, dateAdded: at(minutes),
                      exercise: exercise, song: song, loop: loop, routine: routine)
    }

    private func file(_ title: String = "", kind: ReferenceLinkKind = .pdf, added minutes: Double = 0,
                      exercise: Exercise? = nil) -> ReferenceLink {
        ReferenceLink(title: title, attachmentFileName: "\(UUID().uuidString).\(kind.fileExtension)",
                      dateAdded: at(minutes), kind: kind, exercise: exercise)
    }

    private func song(_ title: String) -> Song {
        Song(title: title, duration: 180, ref: SongRef(id: title, source: .localFile, bookmark: nil))
    }

    // MARK: - D3: one source per link

    /// A source used in two places is two rows, and the library draws it once.
    func testRowsOfOneLinkAreOneSourceNewestRowFirst() throws {
        let older = link("Triads", added: 0, exercise: Exercise(name: "Triad climb"))
        let newer = link("Triads", added: 5, routine: Routine(name: "Morning routine"))
        let other = link("Bends", url: "https://youtube.com/watch?v=b", added: 1)

        let sources = ReferenceLibrary.sources([older, other, newer])
        XCTAssertEqual(sources.count, 2)
        let triads = try XCTUnwrap(sources.first)
        XCTAssertEqual(triads.rows.map(\.uid), [newer.uid, older.uid])
        XCTAssertEqual(triads.places.map(\.name), ["Morning routine", "Triad climb"])
    }

    /// A picture has no address to match on, so two files are two sources whatever they're called —
    /// even file rows that somehow carry one address (a newer build's rows).
    func testFilesNeverGroup() {
        XCTAssertEqual(ReferenceLibrary.sources([file("Chart"), file("Chart")]).count, 2)
        let one = file("Chart")
        let two = file("Chart")
        one.urlString = "https://example.com/a"
        two.urlString = "https://example.com/a"
        XCTAssertEqual(ReferenceLibrary.sources([one, two]).count, 2)
    }

    /// Only a row written by hand or a newer build has neither; it must not merge with every other such row.
    func testARowWithNoAddressAndNoFileStandsAlone() {
        XCTAssertEqual(ReferenceLibrary.sources([link(url: ""), link(url: "")]).count, 2)
    }

    func testSourcesAreNewestFirstByTheirNewestRow() {
        let lesson = link("Lesson", url: "https://example.com/l", added: 1)
        let lessonAgain = link("Lesson", url: "https://example.com/l", added: 9, exercise: Exercise(name: "A"))
        let tab = link("Tab", url: "https://example.com/t", added: 5)
        XCTAssertEqual(ReferenceLibrary.sources([lesson, tab, lessonAgain]).map(\.displayTitle), ["Lesson", "Tab"])
    }

    /// Filed if any row has an owner; the rows no owner holds are its *Kept for later* (D3).
    func testASourceIsFiledWhileAnyRowIs() throws {
        let kept = link(note: "Only the chorus", added: 0)
        let filed = link(added: 1, exercise: Exercise(name: "Spider"))
        let source = try XCTUnwrap(ReferenceLibrary.sources([kept, filed]).first)
        XCTAssertTrue(source.isFiled)
        XCTAssertEqual(source.keptForLater.map(\.uid), [kept.uid])
        XCTAssertFalse(try XCTUnwrap(ReferenceLibrary.sources([link()]).first).isFiled)
    }

    /// Filed nowhere, every note shows under *What you took from it*, newest first, and a row with none
    /// shows nothing; filed, the notes are under their places and this is empty.
    func testASourceFiledNowhereListsEachNote() throws {
        let older = link(note: "The chorus", added: 0)
        let silent = link(note: "  ", added: 1)
        let newer = link(note: "The bridge", added: 2)
        let unfiled = try XCTUnwrap(ReferenceLibrary.sources([older, silent, newer]).first)
        XCTAssertEqual(unfiled.unfiledNotes.map(\.uid), [newer.uid, older.uid])

        let filed = link(note: "On the drill", added: 3, exercise: Exercise(name: "Spider"))
        XCTAssertTrue(try XCTUnwrap(ReferenceLibrary.sources([older, filed]).first).unfiledNotes.isEmpty)
    }

    func testTheSourceARowBelongsToFollowsThatRow() throws {
        let one = link(added: 0)
        let two = link(added: 1, exercise: Exercise(name: "Spider"))
        let elsewhere = link(url: "https://example.com/x")
        let source = try XCTUnwrap(ReferenceLibrary.source(containing: one.uid, in: [one, two, elsewhere]))
        XCTAssertEqual(source.rows.map(\.uid), [two.uid, one.uid])
        XCTAssertNil(ReferenceLibrary.source(containing: UUID(), in: [one]))
    }

    // MARK: - What a row says (D4)

    /// The newest name the player typed; else the site, as an unnamed row already reads.
    func testTheTitleIsTheNewestNameTyped() throws {
        let named = link("CAGED, the A shape", added: 0)
        let unnamed = link(added: 5, exercise: Exercise(name: "Spider"))
        XCTAssertEqual(try XCTUnwrap(ReferenceLibrary.sources([named, unnamed]).first).displayTitle,
                       "CAGED, the A shape")
        XCTAssertEqual(try XCTUnwrap(ReferenceLibrary.sources([link()]).first).displayTitle, "youtube.com")
    }

    func testTheOriginIsTheSiteOrTheKind() throws {
        XCTAssertEqual(try XCTUnwrap(ReferenceLibrary.sources([link()]).first).origin, "youtube.com")
        XCTAssertEqual(try XCTUnwrap(ReferenceLibrary.sources([file(kind: .pdf)]).first).origin, "PDF")
        XCTAssertEqual(try XCTUnwrap(ReferenceLibrary.sources([file(kind: .text)]).first).origin, "Text file")
    }

    func testTheNoteLineIsTheFirstLineOfTheNewestNote() throws {
        let older = link(note: "Older note", added: 0)
        let newer = link(note: "The A shape starts at 3:40.\nRoot on the 5th string.", added: 1,
                         exercise: Exercise(name: "Spider"))
        let silent = link(note: "  ", added: 2, routine: Routine(name: "Week 3"))
        XCTAssertEqual(try XCTUnwrap(ReferenceLibrary.sources([older, newer, silent]).first).noteLine,
                       "The A shape starts at 3:40.")
        XCTAssertNil(try XCTUnwrap(ReferenceLibrary.sources([link()]).first).noteLine)
    }

    /// Each kind of owner names itself, a loop with its song, and a place with no name reads *Untitled*.
    func testEachPlaceSaysWhatItIs() {
        let slowBend = song("Slow Bend")
        let verse = Loop(name: "Verse riff", start: 0.1, end: 0.2, speed: 1.0, repeats: 4)
        verse.song = slowBend
        XCTAssertEqual(link(exercise: Exercise(name: "Spider")).place,
                       ReferencePlace(kind: .exercise, name: "Spider"))
        XCTAssertEqual(link(song: slowBend).place?.detail, "Song")
        XCTAssertEqual(link(loop: verse).place, ReferencePlace(kind: .loop, name: "Verse riff", parent: "Slow Bend"))
        XCTAssertEqual(link(loop: verse).place?.detail, "Loop · Slow Bend")
        XCTAssertEqual(link(routine: Routine(name: " ")).place?.name, "Untitled")
        XCTAssertNil(link().place)
    }

    func testAPlaceUsedTwiceIsNamedOnce() throws {
        let drill = Exercise(name: "Spider")
        let source = try XCTUnwrap(ReferenceLibrary.sources([link(added: 0, exercise: drill),
                                                             link(added: 1, exercise: drill)]).first)
        XCTAssertEqual(source.places.count, 2)
        XCTAssertEqual(source.distinctPlaces.map(\.name), ["Spider"])
    }

    // MARK: - Sections and search (D4)

    /// *Not filed*, then *Everything* with the rest: a source sits in one of them, never both.
    func testSectionsSplitTheUnfiledFromTheRest() {
        let kept = link("Kept", url: "https://example.com/k", added: 2)
        let filed = link("Filed", url: "https://example.com/f", added: 1, exercise: Exercise(name: "Spider"))
        let alsoKept = link("Also kept", url: "https://example.com/a", added: 3)
        let sections = ReferenceLibrary.sections(ReferenceLibrary.sources([kept, filed, alsoKept]))
        XCTAssertEqual(sections.notFiled.map(\.displayTitle), ["Also kept", "Kept"])
        XCTAssertEqual(sections.everything.map(\.displayTitle), ["Filed"])
    }

    func testSearchFindsTheTitleTheSiteANoteOrAPlace() {
        let sources = ReferenceLibrary.sources([
            link("Hybrid picking", url: "https://example.com/1"),
            link(url: "https://vimeo.com/2"),
            link("Bends", url: "https://example.com/3", note: "Only the Chorus voicings"),
            link("Triads", url: "https://example.com/4", exercise: Exercise(name: "Triad climb"))
        ])
        func found(_ query: String) -> [String] {
            let sections = ReferenceLibrary.sections(sources, matching: query)
            return (sections.notFiled + sections.everything).map(\.displayTitle)
        }
        XCTAssertEqual(found("HYBRID"), ["Hybrid picking"], "case is ignored")
        XCTAssertEqual(found("vimeo"), ["vimeo.com"])
        XCTAssertEqual(found("chorus"), ["Bends"])
        XCTAssertEqual(found("climb"), ["Triads"])
        XCTAssertTrue(found("nothing like it").isEmpty)
        XCTAssertEqual(found("  ").count, 4, "a blank search finds everything")
    }

    func testSearchIgnoresAccents() {
        let sources = ReferenceLibrary.sources([link("Beyoncé, the riff")])
        XCTAssertEqual(ReferenceLibrary.sections(sources, matching: "beyonce").notFiled.count, 1)
    }

    // MARK: - The words

    /// *N to file* while anything is unfiled, otherwise the count of sources (D4).
    func testTheToolkitRowsValue() {
        XCTAssertEqual(ReferenceLibrary.toolkitValue([]), "None yet")
        let filed = ReferenceLibrary.sources([link(exercise: Exercise(name: "Spider")),
                                              link(url: "https://example.com/b", routine: Routine(name: "W"))])
        XCTAssertEqual(ReferenceLibrary.toolkitValue(filed), "2 saved")
        let mixed = ReferenceLibrary.sources([link(exercise: Exercise(name: "Spider")),
                                              link(url: "https://example.com/b"), file()])
        XCTAssertEqual(ReferenceLibrary.toolkitValue(mixed), "2 to file")
    }

    /// A delete that keeps something says what it kept (D2), and one that kept nothing says nothing.
    func testTheToastsSecondLine() {
        XCTAssertNil(ReferenceLibrary.keptLine(references: 0))
        XCTAssertEqual(ReferenceLibrary.keptLine(references: 1), "Its reference stays in References")
        XCTAssertEqual(ReferenceLibrary.keptLine(references: 2), "Its 2 references stay in References")
        XCTAssertEqual(ReferenceLibrary.keptLine(references: 3, plural: true), "Their 3 references stay in References")
    }

    func testTheDeleteButtonCountsThePlaces() {
        XCTAssertEqual(ReferenceLibrary.deleteButtonTitle(places: 0), "Delete")
        XCTAssertEqual(ReferenceLibrary.deleteButtonTitle(places: 1), "Delete")
        XCTAssertEqual(ReferenceLibrary.deleteButtonTitle(places: 2), "Delete from both places…")
        XCTAssertEqual(ReferenceLibrary.deleteButtonTitle(places: 3), "Delete from all 3 places…")
    }

    /// It always confirms, and names every place it will leave (D5).
    func testTheDeleteMessageNamesEveryPlace() {
        XCTAssertEqual(ReferenceLibrary.deleteMessage(places: []),
                       "It isn't filed anywhere. It goes from References with what you wrote about it, and "
                        + "this can't be undone.")
        XCTAssertEqual(ReferenceLibrary.deleteMessage(places: [ReferencePlace(kind: .exercise, name: "Triad climb")]),
                       "It comes off Triad climb, with the note you wrote there. This can't be undone.")
        let both = ReferenceLibrary.deleteMessage(places: [ReferencePlace(kind: .exercise, name: "Triad climb"),
                                                           ReferencePlace(kind: .routine, name: "Morning routine")])
        XCTAssertEqual(both, "It comes off Triad climb and Morning routine, with the note on each. "
                        + "This can't be undone.")
    }
}
