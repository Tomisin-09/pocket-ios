import XCTest
@testable import Pocket

/// The Toolkit **Glossary** catalog + search (ADR 0096 Slice 1). Static content, so the tests guard its
/// integrity (no dupes, non-empty definitions) and the pure search filter that `GlossaryView` drives.
final class GlossaryTermTests: XCTestCase {

    // MARK: - Catalog integrity

    func testCatalogIsNonEmpty() {
        XCTAssertFalse(GlossaryTerm.all.isEmpty)
    }

    func testTermsAreUnique() {
        let names = GlossaryTerm.all.map(\.term)
        XCTAssertEqual(names.count, Set(names).count, "Duplicate glossary terms")
    }

    func testEveryTermHasATermAndDefinition() {
        for entry in GlossaryTerm.all {
            XCTAssertFalse(entry.term.trimmingCharacters(in: .whitespaces).isEmpty)
            XCTAssertFalse(entry.definition.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    func testEveryAreaHasAtLeastOneTerm() {
        // The grouped list drops empty areas; an area declared but never used would just be dead code.
        for area in GlossaryTerm.Area.allCases {
            XCTAssertTrue(GlossaryTerm.all.contains { $0.area == area }, "No terms in \(area.rawValue)")
        }
    }

    // MARK: - Search filter (pure — drives GlossaryView)

    func testEmptyQueryReturnsEverything() {
        XCTAssertEqual(GlossaryTerm.matching("").count, GlossaryTerm.all.count)
        XCTAssertEqual(GlossaryTerm.matching("   ").count, GlossaryTerm.all.count)
    }

    func testSearchMatchesTermNameCaseInsensitively() {
        XCTAssertTrue(GlossaryTerm.matching("tritone").contains { $0.term == "Tritone" })
        XCTAssertTrue(GlossaryTerm.matching("TRITONE").contains { $0.term == "Tritone" })
    }

    func testSearchMatchesInsideDefinitions() {
        // "flat five" appears only in the Tritone definition, not its term — so definition search must hit.
        let hits = GlossaryTerm.matching("flat five")
        XCTAssertTrue(hits.contains { $0.term == "Tritone" })
    }

    func testSearchReturnsEmptyForNonsense() {
        XCTAssertTrue(GlossaryTerm.matching("zzzznotathing").isEmpty)
    }
}
