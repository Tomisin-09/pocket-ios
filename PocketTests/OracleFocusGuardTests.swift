import XCTest
@testable import Pocket

/// The second guard (ADR 0187 D23) — the Oracle never phrases an instruction at the body.
///
/// Two halves, and the second is the one that took the design work. Catching *"curl your finger"*
/// is easy; **not** catching *"go back to the top of the neck"*, *"the bend in bar 9"* or a player
/// writing *"my wrist hurts"* is what decides whether this guard is usable. A guard that rejects
/// correct readings gets turned off, and D12's "false positives are the safe direction" does not
/// transfer here: the sentences this one protects are the ones telling the player what to attend
/// to, which is the whole reason the rule exists.
@MainActor
final class OracleFocusGuardTests: XCTestCase {

    // MARK: - What it must catch

    /// Wulf's own example, in the two voices the finding contrasts.
    func testAnInstructionAtTheBodyTripsAndTheSameAskAtTheEffectDoesNot() {
        XCTAssertNotNil(OracleFocusGuard.check("Curl your finger a little more on the second bend."))
        XCTAssertNil(OracleFocusGuard.check("Let the second bend ring cleanly before you release it."),
                     "An instruction pointed at the sound is the whole point of the rule")
    }

    func testThePossessiveFormTripsWhateverVerbGovernsIt() {
        for prose in ["Your wrist should stay loose through the run.",
                      "Try keeping your fretting hand closer to the strings.",
                      "Watch your thumb on the way up."] {
            XCTAssertNotNil(OracleFocusGuard.check(prose), "Missed: \(prose)")
        }
    }

    func testACueVerbReachesForwardToTheBodyNounItGoverns() {
        let trip = OracleFocusGuard.check("Press down with the very tip of the index finger.")
        XCTAssertEqual(trip?.bodyWord, "finger")
        XCTAssertEqual(trip?.cue, "press")
    }

    /// The trip names both halves so a rejection can be counted by cause without the phrase itself
    /// ever being logged — the `OracleToneGuard.Trip` contract, for the same reason.
    func testTheTripNamesTheBodyWordAndTheInstruction() {
        let trip = OracleFocusGuard.check("Relax your shoulder between takes.")
        XCTAssertEqual(trip?.bodyWord, "shoulder")
        XCTAssertEqual(trip?.cue, "your")
    }

    // MARK: - What it must not catch

    /// A player's own words about their own body. Structurally this text never reaches the guard —
    /// `guardedText` drops quoted paragraphs — but the table must not fire on it either, because
    /// the second line of defence is the one that matters when the first is refactored.
    func testAPlayerWritingAboutTheirOwnBodyPasses() {
        XCTAssertNil(OracleFocusGuard.check("my wrist hurts after the barre work"))
        XCTAssertNil(OracleFocusGuard.check("I could feel it in my forearm by the end."))
    }

    /// Four nouns the guitar owns before the body does. Each of these is a sentence the app should
    /// be free to write, and each would be caught by a naive body-part list.
    func testGuitarPartsAndGuitarTechniquesArePartOfTheVocabulary() {
        for prose in ["Go back to the top of the neck and take it from there.",
                      "The bend in bar 9 is the one you marked.",
                      "Keep the tremolo arm out of it for now.",
                      "Hold the note at the end of the phrase."] {
            XCTAssertNil(OracleFocusGuard.check(prose), "False positive on: \(prose)")
        }
    }

    /// A bare mention is not an instruction. This is the line the whole table is drawn around — the
    /// guard fires on *where the sentence points attention*, not on the presence of a noun.
    func testABareBodyNounOutsideAnInstructionPasses() {
        XCTAssertNil(OracleFocusGuard.check("Left-hand fingers were the thing you wrote about most."))
    }

    /// Everything `LocalOracle` writes, checked at the type level as well as through the readings —
    /// D22's revised prose was written after this guard existed, and must stay past it.
    func testTheGuardHasNothingToSayAboutAnEmptyOrWordlessString() {
        XCTAssertTrue(OracleFocusGuard.passes(""))
        XCTAssertTrue(OracleFocusGuard.passes("—  …  ,"))
    }

    // MARK: - The pipeline

    /// The wiring, checked where it would actually leak. A model reading that trips **only** the
    /// focus guard must still be replaced wholesale by the local one: D23 rejects exactly as D12
    /// does, and a reading half-shown is a reading nobody decided to show.
    func testProseThatTripsOnlyTheFocusGuardIsStillReplacedInFull() async {
        let instructed = OracleReadingText(
            paragraphs: [.init("You spent the week on the turnaround."),
                         .init("Curl your finger more on the way into bar 9.")],
            source: .model)
        XCTAssertNil(OracleToneGuard.check(instructed.guardedText),
                     "Positive control: this prose is clean by D12 and must be caught by D23 alone")

        let coordinator = OracleCoordinator(oracle: RecordingOracle(response: instructed),
                                            local: LocalOracle())
        let context = OracleContext(promptVersion: "test-1",
                                    generatedAt: Date(timeIntervalSince1970: 1_725_494_400),
                                    windowStart: Date(timeIntervalSince1970: 1_724_889_600),
                                    windowEnd: Date(timeIntervalSince1970: 1_725_494_400))

        let outcome = await coordinator.run(context: context)

        guard case let .reading(shown, _) = outcome else { return XCTFail("Expected a reading") }
        XCTAssertEqual(shown.source, .local, "A focus-guard trip must be replaced, not shown")
        XCTAssertFalse(shown.joined.contains("You spent the week on the turnaround."),
                       "The reading was scrubbed rather than rejected in full")
    }
}
