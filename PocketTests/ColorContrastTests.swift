import XCTest
@testable import Pocket

final class ColorContrastTests: XCTestCase {

    private let black = RGBComponents(red: 0, green: 0, blue: 0)
    private let white = RGBComponents(red: 1, green: 1, blue: 1)

    func testLuminanceEndpoints() {
        XCTAssertEqual(ColorContrast.relativeLuminance(black), 0, accuracy: 1e-9)
        XCTAssertEqual(ColorContrast.relativeLuminance(white), 1, accuracy: 1e-9)
    }

    func testRatioBlackOnWhiteIsMax() {
        let lumWhite = ColorContrast.relativeLuminance(white)
        let lumBlack = ColorContrast.relativeLuminance(black)
        XCTAssertEqual(ColorContrast.ratio(lumWhite, lumBlack), 21, accuracy: 0.01)
    }

    func testRatioIsSymmetric() {
        let lumWhite = ColorContrast.relativeLuminance(white)
        let lumBlack = ColorContrast.relativeLuminance(black)
        XCTAssertEqual(ColorContrast.ratio(lumWhite, lumBlack),
                       ColorContrast.ratio(lumBlack, lumWhite), accuracy: 1e-9)
    }

    func testBrightColourIsLegibleOnBlack() {
        // An amber-ish accent reads fine on near-black.
        XCTAssertTrue(ColorContrast.isLegible(foreground: RGBComponents(red: 0.96, green: 0.62, blue: 0.04),
                                              background: black))
        XCTAssertTrue(ColorContrast.isLegible(foreground: white, background: black))
    }

    func testNearBlackIsNotLegibleOnBlack() {
        XCTAssertFalse(ColorContrast.isLegible(foreground: RGBComponents(red: 0.1, green: 0.1, blue: 0.1),
                                               background: black))
    }
}
