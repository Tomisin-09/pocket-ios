import UIKit
import XCTest
@testable import Pocket

/// The App Icon choice (ADR 0314): what it stores, what the plan lets it put on the Home Screen, and
/// which moon's icon that is with the app drawn in a given theme.
@MainActor
final class AppIconChoiceTests: XCTestCase {

    // MARK: The stored choice (D2)

    /// Nothing stored means the icon matches the theme, which is what every install did before.
    func testTheDefaultMatchesTheTheme() {
        XCTAssertEqual(AppIconChoice.standard, .matchesTheme)
    }

    func testItStoresAsOneString() {
        for choice in AppIconChoice.allCases {
            XCTAssertEqual(AppIconChoice(rawValue: choice.rawValue), choice, choice.rawValue)
        }
        XCTAssertEqual(AppIconChoice.matchesTheme.rawValue, "matchesTheme")
        XCTAssertEqual(AppIconChoice.moon(.harvest).rawValue, "harvest", "a moon stores as its theme does")
        XCTAssertNil(AppIconChoice(rawValue: "eclipse"), "an unknown value must fall back to the default")
        XCTAssertNil(AppIconChoice(rawValue: ""))
    }

    /// *Matches theme* first, then the eight moons in the Theme screen's order, each named as its theme.
    func testNineChoicesInTheirOrder() {
        XCTAssertEqual(AppIconChoice.allCases, [.matchesTheme] + MoonTheme.allCases.map(AppIconChoice.moon))
        XCTAssertEqual(AppIconChoice.matchesTheme.name, "Matches theme")
        XCTAssertEqual(AppIconChoice.moon(.pink).name, "Pink Moon")
    }

    // MARK: The plan (D3)

    /// One moon's icon is part of the plan: it holds while the plan is on, gives way to Blood Moon's
    /// while it's off, and stands until StoreKit has answered, as a theme does.
    func testAMoonIconNeedsThePlan() {
        let pink = AppIconChoice.moon(.pink)
        XCTAssertEqual(AppIconChoice.effective(chosen: pink, planIsOn: true, planHasResolved: true), pink)
        XCTAssertEqual(AppIconChoice.effective(chosen: pink, planIsOn: false, planHasResolved: true), .moon(.blood))
        XCTAssertEqual(AppIconChoice.effective(chosen: pink, planIsOn: false, planHasResolved: false), pink)
    }

    /// Blood Moon's icon and *Matches theme* are free: neither changes when the plan is off.
    func testBloodMoonAndMatchingAreFree() {
        for choice in [AppIconChoice.matchesTheme, .moon(.blood)] {
            XCTAssertEqual(AppIconChoice.effective(chosen: choice, planIsOn: false, planHasResolved: true), choice,
                           choice.name)
        }
    }

    /// A moon's icon is part of the plan as its theme is: its wall is titled with the
    /// screen it was tapped on, names the icons, and says Blood Moon's stays free.
    func testTheIconWallNamesTheIconsAndKeepsBloodMoonFree() {
        XCTAssertEqual(PlanDoor.appIcon.title, "App Icon")
        XCTAssertEqual(PlanWallCopy.headline(returning: false, door: .appIcon), "The moon icons are part of the plan.")
        let explanation = PlanWallCopy.explanation(returning: false, door: .appIcon)
        XCTAssertTrue(explanation.contains("Blood Moon"), explanation)
        XCTAssertTrue(explanation.contains("free for good"), explanation)
        XCTAssertEqual(PlanWallCopy.headline(returning: true, door: .appIcon), "Everything you made is still here.")
    }

    // MARK: Which icon (D1)

    func testMatchingTakesTheDrawnTheme() {
        XCTAssertEqual(AppIconChoice.matchesTheme.icon(drawnTheme: .harvest), .harvest)
        XCTAssertEqual(AppIconChoice.matchesTheme.icon(drawnTheme: .blood), .blood)
    }

    /// The two asks the choice exists for: an icon that stays put when the theme changes, and a moon icon
    /// with the app left in Blood Moon.
    func testAKeptIconIgnoresTheTheme() {
        XCTAssertEqual(AppIconChoice.moon(.blood).icon(drawnTheme: .harvest), .blood)
        XCTAssertEqual(AppIconChoice.moon(.pink).icon(drawnTheme: .blood), .pink)
    }

    /// A lapsed player who kept Pink Moon's icon under Harvest Moon colours is drawn in Blood Moon and
    /// shown Blood Moon's icon: nothing paid for outlives the plan.
    func testALapseTakesBothBackToBloodMoon() {
        let theme = MoonTheme.effective(chosen: .harvest, planIsOn: false, planHasResolved: true)
        let icon = AppIconChoice.effective(chosen: .moon(.pink), planIsOn: false, planHasResolved: true)
        XCTAssertEqual(icon.icon(drawnTheme: theme), .blood)
        XCTAssertEqual(AppIconChoice.matchesTheme.icon(drawnTheme: theme), .blood)
    }

    // MARK: The tiles (D4)

    /// Every moon has a tile to draw, and Blood Moon's is the brand's own name.
    func testEveryMoonHasItsTile() {
        for moon in MoonTheme.allCases {
            let image = UIImage(named: moon.iconTileImage)
            XCTAssertNotNil(image, "\(moon.name): no \(moon.iconTileImage)")
            XCTAssertEqual(image?.size.width, image?.size.height, "\(moon.name)'s tile isn't square")
        }
        XCTAssertEqual(MoonTheme.blood.iconTileImage, "IconTile")
        XCTAssertEqual(MoonTheme.harvest.iconTileImage, "IconTileHarvest")
    }
}
