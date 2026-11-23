import SwiftUI
import UIKit
import XCTest
@testable import Pocket

/// The moon themes (ADR 0311, 0312): what each one maps, that the catalog has every colour set and
/// every piece of art the mapping names, that the themed tokens follow the theme they are drawn in
/// while the fixed ones don't, and that no space on Home sits beside the theme's colour (D10).
@MainActor
final class MoonThemeTests: XCTestCase {

    // MARK: The stored choice

    /// No stored choice means Blood Moon, so every existing install keeps the brand (D1).
    func testNothingStoredIsBloodMoon() {
        XCTAssertEqual(MoonTheme.standard, .blood)
        XCTAssertEqual(MoonTheme.resolved(storedValue: nil), .blood)
        XCTAssertEqual(MoonTheme.resolved(storedValue: "eclipse"), .blood, "an unknown value draws the brand")
        XCTAssertEqual(MoonTheme.resolved(storedValue: "harvest"), .harvest)
    }

    func testEightThemesInTheirOrder() {
        XCTAssertEqual(MoonTheme.allCases, [.blood, .blue, .jade, .corn, .silver, .pink, .harvest, .cold])
        XCTAssertEqual(Set(MoonTheme.allCases.map(\.name)).count, 8)
        for theme in MoonTheme.allCases {
            XCTAssertTrue(theme.name.hasSuffix(" Moon"), theme.name)
            XCTAssertTrue(theme.line.hasSuffix("."), theme.line)
        }
    }

    /// The themes are part of the plan (ADR 0312 D1): the choice draws while the plan is on, Blood Moon
    /// while it's off, and the choice stands until StoreKit has answered.
    func testThePlanDecidesWhatIsDrawn() {
        XCTAssertEqual(MoonTheme.effective(chosen: .harvest, planIsOn: true, planHasResolved: true), .harvest)
        XCTAssertEqual(MoonTheme.effective(chosen: .harvest, planIsOn: false, planHasResolved: true), .blood)
        XCTAssertEqual(MoonTheme.effective(chosen: .harvest, planIsOn: false, planHasResolved: false), .harvest)
        XCTAssertEqual(MoonTheme.effective(chosen: .blood, planIsOn: false, planHasResolved: true), .blood)
    }

    // MARK: The mapping (ADR 0311 D4, D5)

    func testPracticeFamilies() {
        let families = MoonTheme.allCases.map(\.practice)
        XCTAssertEqual(families, [.terracotta, .teal, .jade, .corn, .silver, .pink, .harvest, .cold])
    }

    /// 0311 D5's table, row by row, with the Toolkit as ADR 0312 D5 moved it: Library, Metronome, Journal,
    /// Toolkit, Oracle.
    func testSpacePalettes() {
        let table: [MoonTheme: [ColorFamily]] = [
            .blood: [.teal, .plum, .gold, .pink, .crimson],
            .blue: [.terracotta, .plum, .gold, .pink, .crimson],
            .jade: [.terracotta, .plum, .gold, .pink, .crimson],
            .corn: [.teal, .plum, .terracotta, .pink, .crimson],
            .silver: [.terracotta, .plum, .gold, .pink, .crimson],
            .pink: [.teal, .plum, .gold, .terracotta, .teal],
            .harvest: [.teal, .plum, .crimson, .corn, .crimson],
            .cold: [.terracotta, .plum, .gold, .jade, .crimson]
        ]
        for theme in MoonTheme.allCases {
            XCTAssertEqual([theme.library, theme.metronome, theme.journal, theme.toolkit, theme.oracle],
                           table[theme], theme.name)
        }
    }

    /// A theme never gives a Home space the colour Practice is wearing.
    func testNoSpaceWearsThePracticeFamily() {
        for theme in MoonTheme.allCases {
            let spaces = [theme.library, theme.metronome, theme.journal, theme.toolkit]
            XCTAssertFalse(spaces.contains(theme.practice), theme.name)
            XCTAssertEqual(Set(spaces).count, spaces.count, "\(theme.name): two spaces share a family")
        }
    }

    /// Every filled button a themed role draws has a colour set to draw in.
    func testEveryButtonFamilyHasAButton() {
        for theme in MoonTheme.allCases {
            XCTAssertNotNil(theme.practice.button, theme.name)
            XCTAssertNotNil(theme.metronome.button, theme.name)
        }
    }

    // MARK: The catalog

    /// Every colour set the mapping names exists, in both appearances, so no themed token can fall
    /// back to `Color(themed:)`'s magenta.
    func testEveryNamedColourSetExists() {
        for theme in MoonTheme.allCases {
            for role in ThemeRole.allCases {
                let name = theme.colorSet(role)
                XCTAssertNotNil(UIColor(named: name),
                                "\(theme.name) · \(role) names \(name), which isn't in the catalog")
            }
        }
        for family in ColorFamily.allCases {
            for name in [family.text, family.cardWash, family.circleWash] + [family.button].compactMap({ $0 }) {
                XCTAssertNotNil(UIColor(named: name), "\(family) names \(name)")
                XCTAssertNotEqual(Self.srgb(name, .light), Self.srgb(name, .dark), "\(name) has no dark value")
            }
        }
    }

    /// D4's values, as the catalog holds them, so a colour set edited by hand can't drift from the ADR.
    func testTheNewFamiliesHoldTheADRsValues() {
        let table: [String: (String, String)] = [
            "Jade": ("006F5F", "3CAC96"), "JadeCTA": ("007262", "67B9A7"),
            "Corn": ("63660B", "9AA044"), "CornCTA": ("65690F", "A9AF67"),
            "Silver": ("5D6269", "C5D3E1"), "SilverCTA": ("60656C", "D4DFEB"),
            "Pink": ("9B3F85", "D37EBC"), "PinkCTA": ("9F4188", "D697C3"),
            "Harvest": ("8E5400", "D7892A"), "HarvestCTA": ("925700", "DB9E5D"),
            "Cold": ("2762AA", "659DE3"), "ColdCTA": ("2A65AD", "83ADE2"),
            "TealCTA": ("18698B", "799BA9")
        ]
        for (name, (light, dark)) in table {
            XCTAssertEqual(Self.hex(name, .light), light, "\(name), light")
            XCTAssertEqual(Self.hex(name, .dark), dark, "\(name), dark")
        }
    }

    // MARK: The art and the icon (ADR 0312 D2, D3)

    func testEveryThemeHasItsArt() {
        for theme in MoonTheme.allCases {
            for name in [theme.wordmarkImage, theme.logoImage, theme.markImage] {
                XCTAssertNotNil(UIImage(named: name), "\(theme.name): no \(name)")
            }
        }
        XCTAssertEqual(MoonTheme.blood.wordmarkImage, "RedMoonWordmark", "Blood Moon keeps the brand's own names")
    }

    /// The icons the app can set are the icons the build compiled: `project.yml`'s
    /// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` writes them into the built Info.plist.
    func testTheAlternateIconsAreTheOnesBuilt() throws {
        let icons = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let alternates = try XCTUnwrap(icons["CFBundleAlternateIcons"] as? [String: Any])
        XCTAssertEqual(Set(alternates.keys), Set(MoonTheme.allCases.compactMap(\.alternateIconName)))
        XCTAssertNil(MoonTheme.blood.alternateIconName, "Blood Moon is the primary icon")
        XCTAssertEqual(MoonTheme.allCases.compactMap(\.alternateIconName).count, 7)
    }

    // MARK: The tokens follow the theme they are drawn in

    /// The bridge itself: a themed token, resolved in an environment that names a theme, takes that
    /// theme's colour set. If this fails, every themed colour is stuck on Blood Moon.
    func testThemedTokensFollowTheEnvironment() {
        for theme in MoonTheme.allCases {
            for scheme in [ColorScheme.light, .dark] {
                XCTAssertEqual(resolved(PocketColor.practice, theme, scheme),
                               resolved(Color(theme.practice.text), .blood, scheme), "\(theme.name), \(scheme)")
                XCTAssertEqual(resolved(PocketColor.practiceCTA, theme, scheme),
                               resolved(Color(theme.practice.button ?? ""), .blood, scheme))
                XCTAssertEqual(resolved(PocketColor.library, theme, scheme),
                               resolved(Color(theme.library.text), .blood, scheme))
                XCTAssertEqual(resolved(PocketColor.journal, theme, scheme),
                               resolved(Color(theme.journal.text), .blood, scheme))
                XCTAssertEqual(resolved(PocketColor.toolkitCardWash, theme, scheme),
                               resolved(Color(theme.toolkit.cardWash), .blood, scheme))
                XCTAssertEqual(resolved(PocketColor.oracle, theme, scheme),
                               resolved(Color(theme.oracle.text), .blood, scheme))
                XCTAssertEqual(resolved(PocketColor.waveformAccent, theme, scheme),
                               resolved(PocketColor.practice, theme, scheme), "the song player follows Practice")
                XCTAssertEqual(resolved(PocketColor.mastery, theme, scheme),
                               resolved(PocketColor.practice, theme, scheme), "mastery tracks Practice")
            }
        }
    }

    /// Spaces move, meanings don't (D3): everything outside the themed roles is the same in every theme.
    func testFixedColoursDontMove() {
        var fixed: [Color] = [PocketColor.background, PocketColor.ink, PocketColor.textSecondary,
                              PocketColor.gridLine, PocketColor.active, PocketColor.confirm, PocketColor.danger,
                              PocketColor.fine, PocketColor.marker, PocketColor.pin, PocketColor.confirmWash,
                              PocketColor.chordInk]
        fixed += PocketColor.loopPalette
        for degree in 0...7 { fixed.append(PocketColor.chord(degree: degree)) }
        for theme in MoonTheme.allCases {
            for scheme in [ColorScheme.light, .dark] {
                for (index, colour) in fixed.enumerated() {
                    XCTAssertEqual(resolved(colour, theme, scheme), resolved(colour, .blood, scheme),
                                   "fixed colour \(index) moved in \(theme.name), \(scheme)")
                }
            }
        }
    }

    // MARK: D10's distance rule

    /// No two colours on Home sit together: every pair of Practice, the Library, the Metronome, the Journal
    /// and the Toolkit stays at least 10 apart (OKLab ΔE × 100, the nearer of light and dark), so a later
    /// change to one family can't quietly bring two of them together. 0311 D10 asked this of each space
    /// against the theme; since ADR 0312 D5 moved the Toolkit off the Metronome's plum, it holds for every
    /// pair. **One pair is accepted below it**: Harvest Moon's Toolkit, corn, 8.6 from its orange, because
    /// no family clears 10 there (0312 D5). The Oracle is left out: its Home tile is hidden (ADR 0211).
    func testNoTwoHomeColoursSitTogether() {
        let accepted = ["Harvest Moon: Practice–Toolkit": 8.6]
        for theme in MoonTheme.allCases {
            let places: [(String, ColorFamily)] = [("Practice", theme.practice), ("Library", theme.library),
                                                   ("Metronome", theme.metronome), ("Journal", theme.journal),
                                                   ("Toolkit", theme.toolkit)]
            for first in places.indices {
                for second in places.indices where second > first {
                    let pair = "\(theme.name): \(places[first].0)–\(places[second].0)"
                    let distance = Self.distance(places[first].1.text, places[second].1.text)
                    if let figure = accepted[pair] {
                        XCTAssertEqual(distance, figure, accuracy: 0.05, "the accepted near-pair moved: \(pair)")
                    } else {
                        XCTAssertGreaterThanOrEqual(distance, 10, "\(pair) is \(distance) apart")
                    }
                }
            }
        }
    }

    /// The measure is the ADR's: each theme's nearest space reproduces 0311 D5's table (Blood Moon's is the
    /// Journal at 10.9, Cold Moon's the Metronome at 11.4).
    func testTheMeasureIsTheADRs() {
        func nearest(_ theme: MoonTheme) -> Double {
            [theme.library, theme.metronome, theme.journal, theme.toolkit]
                .map { Self.distance(theme.practice.text, $0.text) }.min() ?? 0
        }
        XCTAssertEqual(nearest(.blood), 10.9, accuracy: 0.05)
        XCTAssertEqual(nearest(.cold), 11.4, accuracy: 0.05)
        XCTAssertEqual(Self.distance(ColorFamily.plum.text, ColorFamily.pink.text), 12.0, accuracy: 0.05,
                       "the Metronome and the Toolkit, 0312 D5's figure")
    }

    // MARK: Helpers

    private func resolved(_ colour: Color, _ theme: MoonTheme, _ scheme: ColorScheme) -> Color.Resolved {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        environment.moonTheme = theme
        return colour.resolve(in: environment)
    }

    /// A colour set's gamma-encoded sRGB, through UIKit, so there's no question what space it's in.
    private static func srgb(_ name: String, _ scheme: UIUserInterfaceStyle) -> [Double] {
        guard let colour = UIColor(named: name) else { return [] }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        colour.resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme))
            .getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue].map(Double.init)
    }

    private static func hex(_ name: String, _ scheme: UIUserInterfaceStyle) -> String {
        var text = ""
        for channel in srgb(name, scheme) {
            let byte: Int = Int((channel * 255).rounded())
            text += String(format: "%02X", byte)
        }
        return text
    }

    /// OKLab ΔE × 100 between two colour sets, the nearer of light and dark (ADR 0311's measure).
    ///
    /// Written as plain typed steps on purpose: CI's older compiler (Xcode 16) gave up type-checking
    /// the chained `map`/`zip`/`reduce` version of this in reasonable time.
    private static func distance(_ first: String, _ second: String) -> Double {
        var nearest = Double.infinity
        for scheme in [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark] {
            let one: [Double] = oklab(srgb(first, scheme))
            let two: [Double] = oklab(srgb(second, scheme))
            var sum: Double = 0
            for index in 0..<3 {
                let gap: Double = one[index] - two[index]
                sum += gap * gap
            }
            let delta: Double = sqrt(sum) * 100
            nearest = min(nearest, (delta * 10).rounded() / 10)
        }
        return nearest
    }

    private static func linear(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    private static func oklab(_ rgb: [Double]) -> [Double] {
        let red: Double = linear(rgb[0])
        let green: Double = linear(rgb[1])
        let blue: Double = linear(rgb[2])
        let long: Double = cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue)
        let medium: Double = cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue)
        let short: Double = cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue)
        let lightness: Double = 0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short
        let greenRed: Double = 1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short
        let blueYellow: Double = 0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short
        return [lightness, greenRed, blueYellow]
    }
}
