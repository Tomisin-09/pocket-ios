import XCTest
@testable import Pocket

/// The readable-width cap rule (ADR 0105 — iPad adaptivity groundwork). `PocketLayout.contentWidth`
/// is the pure statement of what `readableWidth()`'s `frame(maxWidth:)` resolves to: cap at the
/// measure, never upscale past what's offered. Pinned because a regression here would either let the
/// hub stretch edge-to-edge at regular width (cap ignored) or pin it narrow on the phone (over-eager
/// cap) — both silent, neither caught by a build.
final class AdaptiveLayoutTests: XCTestCase {

    func testNarrowScreenGetsFullWidth() {
        // Compact width (iPhone portrait ~393pt) is below the cap, so content fills it — the cap
        // is a no-op here, which is what keeps the modifier safe to apply unconditionally.
        XCTAssertEqual(PocketLayout.contentWidth(available: 393), 393)
        XCTAssertEqual(PocketLayout.contentWidth(available: 430), 430) // iPhone Pro Max portrait
    }

    func testWideScreenIsCappedAtTheMeasure() {
        // Regular width (iPad landscape 1024pt, portrait ~744pt) exceeds the cap, so content holds
        // the readable measure and centres instead of stretching.
        XCTAssertEqual(PocketLayout.contentWidth(available: 1024), PocketLayout.readableContentWidth)
        XCTAssertEqual(PocketLayout.contentWidth(available: 744), PocketLayout.readableContentWidth)
    }

    func testExactlyAtTheCapIsUnchanged() {
        XCTAssertEqual(PocketLayout.contentWidth(available: PocketLayout.readableContentWidth),
                       PocketLayout.readableContentWidth)
    }

    func testCustomCapIsHonoured() {
        // A caller can pass a tighter measure (e.g. a form sheet) and it wins over the default.
        XCTAssertEqual(PocketLayout.contentWidth(available: 1024, cap: 520), 520)
        XCTAssertEqual(PocketLayout.contentWidth(available: 400, cap: 520), 400)
    }
}
