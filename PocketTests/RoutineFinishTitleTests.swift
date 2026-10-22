import XCTest
@testable import Pocket

/// **Done or Finish** — what a ramp-less block's own completion button says (ADR 0271).
///
/// Four screens used to work this out with their own copy of one comparison, and an off-by-one in any
/// of them would label the last block *Done* (so the player can't tell it ends the routine) or a middle
/// block *Finish* (so they think it does). Neither throws; both read fine in a screenshot of the wrong
/// block.
final class RoutineFinishTitleTests: XCTestCase {

    private func context(block index: Int, of count: Int) -> RoutineRunContext {
        RoutineRunContext(stageIndex: index, stageCount: count, autoStart: false, canGoBack: index > 0,
                          onBack: {}, onSkip: {}, onFinished: {}, onExit: {})
    }

    func testOnlyTheLastBlockSaysFinish() {
        XCTAssertEqual(context(block: 0, of: 4).finishTitle, "Done")
        XCTAssertEqual(context(block: 2, of: 4).finishTitle, "Done")
        XCTAssertEqual(context(block: 3, of: 4).finishTitle, "Finish")
    }

    func testAOneBlockRoutineFinishesOnItsOnlyBlock() {
        XCTAssertEqual(context(block: 0, of: 1).finishTitle, "Finish")
    }
}
