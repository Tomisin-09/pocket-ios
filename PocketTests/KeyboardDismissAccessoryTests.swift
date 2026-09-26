import UIKit
import XCTest
@testable import Pocket

/// **The keyboard had no way off it, on every screen** (device, iOS 26.6, 2026-09-26).
///
/// SwiftUI's `.keyboard` toolbar stopped drawing on the device while the simulator still drew it, and
/// a number pad has no Return key — so the metronome's tempo could be typed and never left.
/// `KeyboardDismissAccessory` replaces it with a checkmark in a window of its own. The window itself
/// needs a keyboard to test and is covered by `KeyboardDismissUITests`; these pin the two decisions it
/// makes: **where** the button goes, and **whether** a focused input gets one.
@MainActor
final class KeyboardDismissAccessoryTests: XCTestCase {

    private let screen = CGRect(x: 0, y: 0, width: 402, height: 874)
    private typealias Place = KeyboardAccessoryPlacement

    // MARK: - Where

    func testTheCheckmarkSitsAboveTheKeyboardAtTheTrailingEdge() throws {
        let keyboard = CGRect(x: 0, y: 874 - 336, width: 402, height: 336)
        let frame = try XCTUnwrap(Place.frame(keyboard: keyboard, in: screen))
        XCTAssertEqual(frame.maxX, 402 - Place.trailingInset)
        XCTAssertEqual(frame.maxY, keyboard.minY - Place.gap, "it floats clear of the keys")
        XCTAssertEqual(frame.width, Place.side)
        XCTAssertGreaterThanOrEqual(Place.side, 44, "under 44pt is too small to hit reliably")
    }

    /// The end frame of a keyboard animating away lies below the screen. Read literally it is a
    /// keyboard, and the button would be placed above a thing that is leaving.
    func testAKeyboardBelowTheScreenIsNoKeyboard() {
        let leaving = CGRect(x: 0, y: 874, width: 402, height: 336)
        XCTAssertNil(Place.frame(keyboard: leaving, in: screen))
    }

    /// With a hardware keyboard attached, iOS shows only a short shortcut bar. That is not a keyboard
    /// anyone types on, and it has its own way to dismiss.
    func testAHardwareKeyboardsShortcutBarGetsNoCheckmark() {
        let shortcutBar = CGRect(x: 0, y: 874 - 55, width: 402, height: 55)
        XCTAssertNil(Place.frame(keyboard: shortcutBar, in: screen))
    }

    /// Landscape puts the sensor housing on one side; the button keeps clear of the safe area there.
    func testTheTrailingSafeAreaPushesTheCheckmarkIn() throws {
        let landscape = CGRect(x: 0, y: 0, width: 874, height: 402)
        let keyboard = CGRect(x: 0, y: 402 - 209, width: 874, height: 209)
        let frame = try XCTUnwrap(Place.frame(keyboard: keyboard, in: landscape, trailingSafeInset: 59))
        XCTAssertEqual(frame.maxX, 874 - 59 - Place.gap)
    }

    // MARK: - Whether

    func testAPlainFieldOrNoteGetsTheCheckmark() {
        XCTAssertTrue(KeyboardDismissAccessory.wantsCheckmark(for: UITextField()))
        XCTAssertTrue(KeyboardDismissAccessory.wantsCheckmark(for: UITextView()),
                      "a note field grows downwards, so Return is a newline — this is its only way off")
    }

    func testASearchFieldIsLeftToItsOwnSearchKey() {
        XCTAssertFalse(KeyboardDismissAccessory.wantsCheckmark(for: UISearchTextField()))
    }

    /// A field in an alert: the alert's own buttons end it, and the checkmark would float undimmed
    /// beside a dimmed alert.
    func testAFieldInsideAnAlertGetsNone() {
        let alert = UIAlertController(title: "Rename", message: nil, preferredStyle: .alert)
        let field = UITextField()
        alert.view.addSubview(field)
        XCTAssertFalse(KeyboardDismissAccessory.wantsCheckmark(for: field))
    }

    /// Nothing focused, or something focused that is not text — an out-of-process view's host, say.
    func testNothingThatIsNotATextInputGetsOne() {
        XCTAssertFalse(KeyboardDismissAccessory.wantsCheckmark(for: nil))
        XCTAssertFalse(KeyboardDismissAccessory.wantsCheckmark(for: UIView()))
    }
}
