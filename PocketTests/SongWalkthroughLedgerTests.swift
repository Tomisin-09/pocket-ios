import XCTest
@testable import Pocket

/// When the first-song walkthrough runs (ADR 0149 §2, §4): armed by the first import, spent by the
/// visit that shows it, back only on request.
final class SongWalkthroughLedgerTests: XCTestCase {

    private var store: UserDefaults!
    private let suite = "SongWalkthroughLedgerTests"

    override func setUp() {
        super.setUp()
        store = UserDefaults(suiteName: suite)
        store.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        store.removePersistentDomain(forName: suite)
        store = nil
        super.tearDown()
    }

    private var ledger: AppSettings.SongWalkthroughLedger { AppSettings.songWalkthroughLedger(store: store) }

    func testAFreshInstallHasNeverBeenArmed() {
        XCTAssertEqual(ledger, .never)
        XCTAssertFalse(AppSettings.takeArmedSongWalkthrough(store: store), "Nothing to guide before a song")
    }

    /// §2: the first successful import arms it, and the visit that shows it spends it for good.
    func testTheFirstImportArmsItAndOneVisitSpendsIt() {
        AppSettings.armSongWalkthroughIfFirstImport(libraryAlreadyHadAudio: false, store: store)
        XCTAssertEqual(ledger, .armed)
        XCTAssertTrue(AppSettings.takeArmedSongWalkthrough(store: store))
        XCTAssertEqual(ledger, .spent)
        XCTAssertFalse(AppSettings.takeArmedSongWalkthrough(store: store), "It never returns by itself")
    }

    /// A later import — the second song, the next batch — never arms it again (§4).
    func testALaterImportNeverRearmsIt() {
        AppSettings.armSongWalkthroughIfFirstImport(libraryAlreadyHadAudio: false, store: store)
        _ = AppSettings.takeArmedSongWalkthrough(store: store)
        AppSettings.armSongWalkthroughIfFirstImport(libraryAlreadyHadAudio: false, store: store)
        XCTAssertEqual(ledger, .spent)
    }

    /// A player upgrading with songs already in the library is not making a first import, and is
    /// never walked through an app they already use. Writing `.spent` down also stops the importer
    /// fetching the library on every import after.
    func testAnImportIntoALibraryWithAudioSpendsItWithoutArming() {
        AppSettings.armSongWalkthroughIfFirstImport(libraryAlreadyHadAudio: true, store: store)
        XCTAssertEqual(ledger, .spent)
        XCTAssertFalse(AppSettings.takeArmedSongWalkthrough(store: store))
    }

    /// Help & FAQs' way back in (§4, §6) re-arms it whatever happened before.
    func testHelpRearmsASpentWalkthrough() {
        AppSettings.armSongWalkthroughIfFirstImport(libraryAlreadyHadAudio: true, store: store)
        AppSettings.rearmSongWalkthrough(store: store)
        XCTAssertTrue(AppSettings.takeArmedSongWalkthrough(store: store))
    }

    /// A value written by a later build that knows a fourth state reads as `.never`, not a crash.
    func testAnUnknownStoredValueResolvesToNever() {
        XCTAssertEqual(AppSettings.resolvedSongWalkthroughLedger(storedValue: "somethingNew"), .never)
        XCTAssertEqual(AppSettings.resolvedSongWalkthroughLedger(storedValue: nil), .never)
    }

    /// §5's one ceremony is the player's, not the run's.
    func testTheCeremonyLatchSurvivesARearm() {
        AppSettings.recordSongWalkthroughCeremonySeen(store: store)
        AppSettings.rearmSongWalkthrough(store: store)
        XCTAssertTrue(AppSettings.songWalkthroughCeremonySeen(store: store))
    }

    /// Only the UI test that asks for the walkthrough gets it back fresh — ceremony and all.
    func testTheUITestResetArmsItAndClearsTheCeremony() {
        AppSettings.recordSongWalkthroughCeremonySeen(store: store)
        AppSettings.resetSongWalkthroughForUITest(store: store)
        XCTAssertEqual(ledger, .armed)
        XCTAssertFalse(AppSettings.songWalkthroughCeremonySeen(store: store))
    }

    // MARK: - The launch seam

    /// Suppressed under `-uiTesting` so it never covers the suite's controls or the manual's figures;
    /// open everywhere else, and to the one test that names it.
    func testTheWalkthroughIsOpenOutsideUITestsAndToTheTestThatAsks() {
        let uiTesting = UITestHooks.launchArgument
        let walkthrough = UITestHooks.walkthroughArgument
        XCTAssertTrue(UITestRuntime.parseWalkthrough(in: []))
        XCTAssertFalse(UITestRuntime.parseWalkthrough(in: [uiTesting]))
        XCTAssertTrue(UITestRuntime.parseWalkthrough(in: [uiTesting, walkthrough]))
    }
}
