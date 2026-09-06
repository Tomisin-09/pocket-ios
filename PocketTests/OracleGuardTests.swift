import XCTest
@testable import Pocket

/// The tone guard (ADR 0187 D12) and the two safety matchers (D13).
///
/// These are the mechanisms that make D1 safe — the context is deliberately *not* minimised, and
/// the guarantee lives on the output side instead. So the assertions below are the load-bearing
/// ones in this feature, and they are written the way the guards are: bluntly.
final class OracleGuardTests: XCTestCase {

    // MARK: - D12, the habit band

    func testTheHabitBandCatchesSentencesAboutHowOftenYouShowedUp() {
        let judgements = [
            "You've been consistent this week.",
            "Three days in a row — that's a streak.",
            "You're behind where you were.",
            "You're on track for the goal you set.",
            "You should practise the bend more often.",
            "You must keep this up.",
            "Push through it next week.",
            "No excuses next week.",
            "You've fallen off since Tuesday.",
            "You only practised on 2 days."
        ]
        for sentence in judgements {
            XCTAssertEqual(OracleToneGuard.check(sentence)?.band, .habit,
                           "Not caught by the habit band: \(sentence)")
        }
    }

    /// A sentence carrying words from both bands reports the one found first. The caller's only
    /// decision is reject-or-not, so which band it names does not change the outcome — but a test
    /// asserting a band on mixed prose would be asserting scan order, which is not a rule.
    func testASentenceInBothBandsIsRejectedRegardlessOfWhichOneItNames() {
        XCTAssertNotNil(OracleToneGuard.check("Push through the plateau."))
    }

    // MARK: - D12, the tempo band

    /// This band matters most. `TempoRecord` is literally "faster than you'd played it before" and
    /// sits one adjective away from a scoreboard.
    func testTheTempoBandCatchesSentencesThatRankATempo() {
        let judgements = [
            "The bend has plateaued at 96.",
            "Progress stalled in August.",
            "You regressed on the scale run.",
            "The tempo slipped this week.",
            "That's going backwards.",
            "A new personal best at 104.",
            "That's a PB.",
            "You set a record on Thursday.",
            "Faster than you have ever played it."
        ]
        for sentence in judgements {
            XCTAssertEqual(OracleToneGuard.check(sentence)?.band, .tempo,
                           "Not caught by the tempo band: \(sentence)")
        }
    }

    /// Punctuation and casing must not be an escape hatch. A guard that a full stop defeats is not
    /// a guard.
    func testAWordIsCaughtThroughPunctuationAndCasing() {
        XCTAssertNotNil(OracleToneGuard.check("(STREAK!)"))
        XCTAssertNotNil(OracleToneGuard.check("You should, honestly, slow down."))
    }

    /// Whole tokens, never substrings — or the table starts firing inside unrelated words.
    func testTheGuardMatchesWholeWordsOnly() {
        XCTAssertNil(OracleToneGuard.check("The phrasing sits behindhand of nothing in particular."),
                     "A substring match fired inside a longer word")
        XCTAssertNil(OracleToneGuard.check("Recorded on Tuesday, two takes."),
                     "'recorded' is not 'record'; the take vocabulary must survive the guard")
    }

    func testOrdinaryReflectiveProseIsLeftAlone() {
        let clean = [
            "Four days of playing, an hour and ten minutes in all.",
            "Bend study was played at 76 on 29 Aug, and at 96 on 1 Sep, both in 16ths.",
            "Still written down: get the intro clean.",
            "The week of 29 Aug to 4 Sep has nothing logged against it."
        ]
        for sentence in clean {
            XCTAssertNil(OracleToneGuard.check(sentence), "False positive on: \(sentence)")
        }
    }

    func testEmptyProseDoesNotTrip() {
        XCTAssertNil(OracleToneGuard.check(""))
        XCTAssertNil(OracleToneGuard.check("   \n  "))
    }

    // MARK: - D13, pain

    func testPainLanguageIsMatchedOnTheDevice() {
        for text in ["My wrist is sore after the barre work.",
                     "Tingling in the little finger again.",
                     "Some tendon ache on the stretch.",
                     "Pins and needles by the end."] {
            XCTAssertEqual(OracleSafetySignal.scan([text]), .pain, "Not matched: \(text)")
        }
    }

    /// D13 says both matchers fail *towards* the safe branch, and this is what that costs: a
    /// guitarist writing about wrist position gets the pain branch. The trade is deliberate — the
    /// cost is one fixed line and no drill proposal.
    func testAnInnocentUseOfAPainWordStillFiresAndThatIsTheDesign() {
        XCTAssertEqual(OracleSafetySignal.scan(["Working on wrist position for the vibrato."]), .pain)
    }

    // MARK: - D13, distress

    func testDistressLanguageIsMatchedAndOutranksPain() {
        for text in ["Honestly thinking about giving up.",
                     "What's the point, I'll never be good enough.",
                     "This is a waste of time.",
                     "I hate my playing."] {
            XCTAssertEqual(OracleSafetySignal.scan([text]), .distress, "Not matched: \(text)")
        }
        XCTAssertEqual(OracleSafetySignal.scan(["My wrist hurts and I'm giving up."]), .distress,
                       "Distress must outrank pain — the two have different effects and the more "
                       + "protective one wins outright")
    }

    /// The distress table is mostly phrases, unlike the pain table, because its consequence is the
    /// heavier one. A bad practice day must not summon a signposting card.
    func testABadPracticeDayIsNotDistress() {
        for text in ["That was a terrible session.",
                     "Everything fell apart at 100.",
                     "Frustrating hour, nothing landed."] {
            XCTAssertEqual(OracleSafetySignal.scan([text]), .none, "False positive on: \(text)")
        }
    }

    func testAnEmptyScanIsClean() {
        XCTAssertEqual(OracleSafetySignal.scan([]), .none)
        XCTAssertEqual(OracleSafetySignal.scan(["", "   "]), .none)
    }
}
