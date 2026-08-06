import XCTest
@testable import Pocket

/// The Toolkit **Help & FAQs** catalog + search (ADR 0145). Mirrors `GlossaryTermTests` — static
/// content, so the tests guard its integrity and the pure search filter `FAQView` drives.
///
/// Two of these are policy guards rather than integrity checks, and they are the reason this file
/// matters more than its glossary twin: **D6** (no price or trial length may be hardcoded in help copy)
/// and **D5** (the mastery/command-tempo answer quotes `PracticeFieldInfo` rather than restating it).
/// Both are the kind of thing that stays correct until someone edits copy in a hurry.
///
/// What no test can check is whether an answer is *true*. Read them against the shipped app.
final class FAQEntryTests: XCTestCase {

    // MARK: - Catalog integrity

    func testCatalogIsNonEmpty() {
        XCTAssertFalse(FAQEntry.all.isEmpty)
    }

    func testQuestionsAreUnique() {
        // `id` is the question, and `FAQView` keys its expansion set on it — a duplicate would open
        // two rows at once.
        let questions = FAQEntry.all.map(\.question)
        XCTAssertEqual(questions.count, Set(questions).count, "Duplicate FAQ questions")
    }

    func testEveryEntryHasAQuestionAndAnswer() {
        for entry in FAQEntry.all {
            XCTAssertFalse(entry.question.trimmingCharacters(in: .whitespaces).isEmpty)
            XCTAssertFalse(entry.answer.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    func testEveryAreaHasAtLeastOneEntry() {
        // The grouped list drops empty areas; an area declared but never used would just be dead code.
        for area in FAQEntry.Area.allCases {
            XCTAssertTrue(FAQEntry.all.contains { $0.area == area }, "No entries in \(area.rawValue)")
        }
    }

    // MARK: - Search filter (pure — drives FAQView)

    func testEmptyQueryReturnsEverything() {
        XCTAssertEqual(FAQEntry.matching("").count, FAQEntry.all.count)
        XCTAssertEqual(FAQEntry.matching("   ").count, FAQEntry.all.count)
    }

    func testSearchMatchesQuestionCaseInsensitively() {
        XCTAssertFalse(FAQEntry.matching("ramp").isEmpty)
        XCTAssertFalse(FAQEntry.matching("RAMP").isEmpty)
    }

    func testSearchMatchesInsideAnswers() {
        // "Spotify" is named in an answer's body as well as its question; "iCloud Drive" is only ever
        // in bodies. Searching the second must still hit — which is what force-expanding matches in
        // `FAQView` is for.
        let hits = FAQEntry.matching("iCloud Drive")
        XCTAssertFalse(hits.isEmpty, "Expected an answer mentioning iCloud Drive")
        XCTAssertTrue(hits.allSatisfy { $0.answer.localizedCaseInsensitiveContains("iCloud Drive") },
                      "Every hit should have matched in its answer, not its question")
    }

    func testSearchReturnsEmptyForNonsense() {
        XCTAssertTrue(FAQEntry.matching("zzzznotathing").isEmpty)
    }

    // MARK: - D6: no price, no trial length (ADR 0145 D6, inheriting ADR 0144)

    func testNoAnswerHardcodesAPriceOrTrialLength() {
        // The live price and trial length come from StoreKit and App Store Connect; help copy that
        // names either goes stale silently and ships a promise the paywall doesn't make.
        let forbidden = try? NSRegularExpression(pattern: "\\d+[- ]day|£|\\$|€")
        XCTAssertNotNil(forbidden)
        for entry in FAQEntry.all {
            let range = NSRange(entry.answer.startIndex..., in: entry.answer)
            let hit = forbidden?.firstMatch(in: entry.answer, range: range)
            XCTAssertNil(hit, "“\(entry.question)” names a price or trial length — ADR 0145 D6 "
                         + "forbids it. Point at the paywall or Settings ▸ Red Moon Pro instead.")
        }
    }

    // MARK: - D5: quoted copy, so the surfaces can't drift

    func testMasteryAnswerQuotesTheInAppExplanations() {
        let answer = FAQEntry.all.first { $0.question.localizedCaseInsensitiveContains("mastery") }
        XCTAssertNotNil(answer, "The mastery vs command tempo entry is mandated (docs/backlog.md)")
        XCTAssertTrue(answer?.answer.contains(PracticeFieldInfo.mastery) == true,
                      "Must quote PracticeFieldInfo.mastery verbatim, not paraphrase it (D5)")
        XCTAssertTrue(answer?.answer.contains(PracticeFieldInfo.commandTempo) == true,
                      "Must quote PracticeFieldInfo.commandTempo verbatim, not paraphrase it (D5)")
    }

    // MARK: - The support address (the mailto fallback)

    func testSupportAddressAppearsInAnAnswerAsPlainText() {
        // A `mailto:` does nothing on a device with no Mail account, so the address has to be
        // readable and copyable inside the catalog itself. Deleting it from the answer would remove
        // the only way such a player can reach us.
        XCTAssertTrue(FAQEntry.all.contains { $0.answer.contains(FAQEntry.supportAddress) },
                      "No answer carries \(FAQEntry.supportAddress) as plain text")
    }
}
