import SwiftUI
import XCTest
@testable import Pocket

/// The colours ADR 0292 moved (Practice, the Library, the song player), read from the asset catalog in
/// both appearances and held to WCAG AA for text (4.5 : 1). The swap nearly shipped the blood-moon `#C24A2C` as light-mode Practice
/// text on cream at 3.87 : 1, against the teal's 4.84; the light value was darkened to `#B0391B` to
/// match the teal, and this is what keeps it there.
@MainActor
final class BrandColorContrastTests: XCTestCase {

    private func components(_ color: Color, _ scheme: ColorScheme) -> RGBComponents {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let resolved = color.resolve(in: environment)
        return RGBComponents(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue))
    }

    private func ratio(_ foreground: Color, on background: Color, _ scheme: ColorScheme) -> Double {
        ColorContrast.ratio(ColorContrast.relativeLuminance(components(foreground, scheme)),
                            ColorContrast.relativeLuminance(components(background, scheme)))
    }

    /// The words on a filled Practice button (Start today's session, Pause) are drawn in the
    /// background colour, so the fill is measured against it (ADR 0062).
    func testPracticeButtonTextMeetsAA() {
        for scheme in [ColorScheme.light, .dark] {
            XCTAssertGreaterThanOrEqual(ratio(PocketColor.background, on: PocketColor.practiceCTA, scheme), 4.5,
                                        "practiceCTA, \(scheme)")
        }
    }

    /// Practice colours small text across the app: "All 4 ›", a routine's block count, Edit goals.
    func testPracticeTextMeetsAAOnTheBackground() {
        for scheme in [ColorScheme.light, .dark] {
            XCTAssertGreaterThanOrEqual(ratio(PocketColor.practice, on: PocketColor.background, scheme), 4.5,
                                        "practice, \(scheme)")
        }
    }

    /// The song player's accent reads the same terracotta (ADR 0292) and colours words too: *Set BPM*,
    /// the tempo sheet's actions. Its filled *Use* button carries background ink.
    func testSongAccentMeetsAA() {
        for scheme in [ColorScheme.light, .dark] {
            XCTAssertGreaterThanOrEqual(ratio(PocketColor.waveformAccent, on: PocketColor.background, scheme), 4.5,
                                        "waveformAccent, \(scheme)")
            XCTAssertGreaterThanOrEqual(ratio(PocketColor.background, on: PocketColor.waveformAccent, scheme), 4.5,
                                        "ink on waveformAccent, \(scheme)")
        }
    }

    func testLibraryTextMeetsAAOnTheBackground() {
        for scheme in [ColorScheme.light, .dark] {
            XCTAssertGreaterThanOrEqual(ratio(PocketColor.library, on: PocketColor.background, scheme), 4.5,
                                        "library, \(scheme)")
        }
    }

    /// Guards the checks above: a colour the catalog failed to supply resolves the same in both
    /// appearances, and the ratios could then pass on a fallback rather than on the real values.
    func testEachColourResolvesPerAppearance() {
        let colours = [PocketColor.practice, PocketColor.practiceCTA, PocketColor.library, PocketColor.waveformAccent,
                       PocketColor.background]
        for colour in colours {
            XCTAssertNotEqual(components(colour, .light), components(colour, .dark))
        }
    }
}
