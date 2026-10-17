import XCTest
@testable import Pocket

/// The plan's rules (ADR 0256). `PlanStore` only reduces StoreKit's transactions to `OwnedPurchase`s;
/// every decision about what they open is here, and so is every test of one.
final class PlanAccessTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var tomorrow: Date { now.addingTimeInterval(86_400) }
    private var yesterday: Date { now.addingTimeInterval(-86_400) }

    private func monthly(expires: Date? = nil, shared: Bool = false, revoked: Date? = nil) -> OwnedPurchase {
        OwnedPurchase(productID: PlanProduct.monthly, isFamilyShared: shared, revokedAt: revoked,
                      expiresAt: expires ?? tomorrow)
    }

    private func payOnce(shared: Bool = false, revoked: Date? = nil) -> OwnedPurchase {
        OwnedPurchase(productID: PlanProduct.payOnce, isFamilyShared: shared, revokedAt: revoked)
    }

    // MARK: - D1: two products, new ids

    func testTwoProductsMonthlyFirst() {
        XCTAssertEqual(PlanProduct.all, [PlanProduct.monthly, PlanProduct.payOnce])
    }

    /// App Store Connect never reuses a product id, and the old Pro ids were set up and never sold.
    func testIdsAreNotTheRetiredProIds() {
        for id in PlanProduct.all {
            XCTAssertFalse(id.contains(".pro."), id)
        }
    }

    // MARK: - resolve

    func testNothingOwnedIsNoPlan() {
        XCTAssertEqual(PlanAccess.resolve([], now: now), .none)
        XCTAssertFalse(PlanAccess.none.isOn)
    }

    func testARenewingMonthlyOpensThePlan() {
        XCTAssertEqual(PlanAccess.resolve([monthly()], now: now), .monthly)
        XCTAssertTrue(PlanAccess.monthly.isOn)
    }

    func testPayOnceOpensThePlan() {
        XCTAssertEqual(PlanAccess.resolve([payOnce()], now: now), .payOnce)
        XCTAssertTrue(PlanAccess.payOnce.isOn)
    }

    /// Bought Pay once while the monthly still renews: the player has Pay once, and that is the state
    /// the cancel row exists for (D5).
    func testPayOnceWinsOverARenewingMonthly() {
        XCTAssertEqual(PlanAccess.resolve([monthly(), payOnce()], now: now), .payOnce)
        XCTAssertEqual(PlanAccess.resolve([payOnce(), monthly()], now: now), .payOnce)
    }

    /// D6: a family-shared purchase opens the plan exactly as a bought one does.
    func testFamilySharedOpensThePlan() {
        XCTAssertEqual(PlanAccess.resolve([payOnce(shared: true)], now: now), .payOnce)
        XCTAssertEqual(PlanAccess.resolve([monthly(shared: true)], now: now), .monthly)
    }

    /// D6: a refund, or the organiser ending Family Sharing, closes the plan.
    func testARevokedPurchaseOpensNothing() {
        XCTAssertEqual(PlanAccess.resolve([payOnce(revoked: yesterday)], now: now), .none)
        XCTAssertEqual(PlanAccess.resolve([monthly(revoked: yesterday)], now: now), .none)
        XCTAssertEqual(PlanAccess.resolve([payOnce(shared: true, revoked: yesterday)], now: now), .none)
    }

    /// The 2026-08 sandbox pass: a lapse that nothing re-reads leaves the plan open. The rule itself
    /// must close it for any list it is handed, stale or not.
    func testAnExpiredMonthlyOpensNothing() {
        XCTAssertEqual(PlanAccess.resolve([monthly(expires: yesterday)], now: now), .none)
        XCTAssertEqual(PlanAccess.resolve([monthly(expires: now)], now: now), .none)
    }

    func testARevokedPayOnceFallsBackToALiveMonthly() {
        XCTAssertEqual(PlanAccess.resolve([payOnce(revoked: yesterday), monthly()], now: now), .monthly)
    }

    func testAnUnknownProductOpensNothing() {
        let old = OwnedPurchase(productID: "click.decooperations.pocket.pro.monthly", expiresAt: tomorrow)
        XCTAssertEqual(PlanAccess.resolve([old], now: now), .none)
    }

    // MARK: - D5: the cancel row

    func testCancelRowNeedsPayOnceAndARenewingMonthly() {
        XCTAssertTrue(PlanAccess.offersCancelMonthly(access: .payOnce, ownMonthlyRenews: true))
        XCTAssertFalse(PlanAccess.offersCancelMonthly(access: .payOnce, ownMonthlyRenews: false))
        XCTAssertFalse(PlanAccess.offersCancelMonthly(access: .monthly, ownMonthlyRenews: true))
        XCTAssertFalse(PlanAccess.offersCancelMonthly(access: .none, ownMonthlyRenews: true))
    }

    // MARK: - D4: the returning player

    func testOnlyALapsedBuyerIsGreetedAsReturning() {
        XCTAssertTrue(PlanAccess.greetsReturningPlayer(access: .none, hasBoughtBefore: true))
        XCTAssertFalse(PlanAccess.greetsReturningPlayer(access: .none, hasBoughtBefore: false))
        XCTAssertFalse(PlanAccess.greetsReturningPlayer(access: .monthly, hasBoughtBefore: true))
    }

    func testTheReturningHeadlineSaysNothingWasLost() {
        XCTAssertEqual(PlanWallCopy.headline(returning: true), "Everything you made is still here.")
        XCTAssertNotEqual(PlanWallCopy.headline(returning: false), PlanWallCopy.headline(returning: true))
    }

    // MARK: - D10: the summary

    func testSettingsSummaryNamesTheWayTheyPaid() {
        XCTAssertEqual(PlanAccess.none.summary, "Free")
        XCTAssertEqual(PlanAccess.monthly.summary, "Monthly")
        XCTAssertEqual(PlanAccess.payOnce.summary, "Pay once")
    }

    // MARK: - D2: the free line, where it is drawn in one list

    /// The Toolkit is the one list holding both sides of D2. The three things you make are the
    /// plan's; the three tools that remember nothing are free.
    func testToolkitSplitsAlongTheFreeLine() {
        XCTAssertEqual(ToolkitSection.myChords.planDoor, .myChords)
        XCTAssertEqual(ToolkitSection.myProgressions.planDoor, .myProgressions)
        XCTAssertEqual(ToolkitSection.myTabs.planDoor, .myTabs)
        XCTAssertNil(ToolkitSection.tuner.planDoor)
        XCTAssertNil(ToolkitSection.glossary.planDoor)
        XCTAssertNil(ToolkitSection.help.planDoor)
    }

    /// A Toolkit door's wall is titled with the row the player tapped.
    func testToolkitDoorsAreTitledAsTheirRows() {
        for section in ToolkitSection.allCases {
            guard let door = section.planDoor else { continue }
            XCTAssertEqual(door.title, section.info.title)
        }
    }

    func testEveryDoorHasATitle() {
        for door in PlanDoor.allCases {
            XCTAssertFalse(door.title.isEmpty, door.rawValue)
        }
    }

    // MARK: - D8: the promise

    func testThePromiseIsBuiltFromThePricesItIsGiven() {
        XCTAssertEqual(PlanWallCopy.promise(monthly: "£1.00", payOnce: "£15.00"),
                       "£1.00 a month, or £15.00 once.")
        XCTAssertEqual(PlanWallCopy.promise(monthly: "$1.00", payOnce: "$15.00"),
                       "$1.00 a month, or $15.00 once.")
    }

    func testThePromiseLineIsVerbatim() {
        XCTAssertEqual(PlanWallCopy.promiseLine,
                       "We'll never raise the price, and nothing you can do today will ever move behind a higher one.")
    }

    /// Guideline 3.1.2: the disclosure names the renewing price and how to cancel.
    func testTheDisclosureNamesThePriceAndTheWayOut() {
        let text = PlanWallCopy.renewalDisclosure(monthly: "£1.00")
        XCTAssertTrue(text.contains("£1.00 a month"))
        XCTAssertTrue(text.contains("renews automatically"))
        XCTAssertTrue(text.contains("Cancel any time"))
    }

    // MARK: - D1: the free week

    private let week = PlanTrial(unit: .week, value: 1)

    func testAWeekReadsAsAWeek() {
        XCTAssertEqual(week?.length, "a week")
        XCTAssertEqual(week?.span, "week")
    }

    /// StoreKit can report a week as seven days. The copy says a week either way.
    func testWholeWeeksOfDaysReadAsWeeks() {
        XCTAssertEqual(PlanTrial(unit: .day, value: 7), week)
        XCTAssertEqual(PlanTrial(unit: .day, value: 14)?.length, "2 weeks")
        XCTAssertEqual(PlanTrial(unit: .day, value: 3)?.length, "3 days")
    }

    /// The length is App Store Connect's (0144 D5's rule), so changing it there changes the copy.
    func testOtherLengthsAreWrittenAsTheyAre() {
        XCTAssertEqual(PlanTrial(unit: .month, value: 1)?.length, "a month")
        XCTAssertEqual(PlanTrial(unit: .week, value: 2)?.span, "2 weeks")
    }

    func testAPeriodThatIsNotPositiveClaimsNoTrial() {
        XCTAssertNil(PlanTrial(unit: .week, value: 0))
        XCTAssertNil(PlanTrial(unit: .day, value: -7))
    }

    func testTheMonthlyButtonLeadsWithTheFreeWeekWhileItIsOnOffer() {
        let offered = PlanWallCopy.monthlyOption(monthly: "£1", trial: week)
        XCTAssertEqual(offered.title, "Try it free for a week")
        XCTAssertEqual(offered.detail, "Then £1 a month. Cancel any time.")
        let usedUp = PlanWallCopy.monthlyOption(monthly: "£1", trial: nil)
        XCTAssertEqual(usedUp.title, "£1 a month")
        XCTAssertEqual(usedUp.detail, "Renews monthly. Cancel any time.")
    }

    /// Guideline 3.1.2 with a free trial: how long it is, what it becomes, and how to leave first.
    func testTheDisclosureSaysWhatTheFreeWeekBecomes() {
        let text = PlanWallCopy.renewalDisclosure(monthly: "£1", trial: week)
        XCTAssertTrue(text.contains("free for a week, then renews automatically at £1 a month"))
        XCTAssertTrue(text.contains("before the free week ends and you pay nothing"))
        XCTAssertTrue(text.contains("Pay once is a single payment"))
        XCTAssertFalse(PlanWallCopy.renewalDisclosure(monthly: "£1").contains("free"),
                       "The disclosure offered a free week nobody can have")
    }

    // MARK: - D10: Your plan on the monthly

    private let day = "Friday 24 October"

    func testYourPlanNamesTheFreeWeeksEndAndWhatFollows() {
        XCTAssertEqual(PlanWallCopy.monthlyStatus(endsOn: day, freeSpan: "week", renews: true, monthly: "£1"),
                       "Your free week ends on Friday 24 October. Then it's £1 a month until you cancel, and "
                        + "everything in Red Moon is open.")
        XCTAssertEqual(PlanWallCopy.monthlyStatus(endsOn: day, freeSpan: "week", renews: false, monthly: "£1"),
                       "Your free week ends on Friday 24 October. You've cancelled, so you won't be charged, "
                        + "and everything you made stays.")
    }

    func testAPaidMonthSaysWhenItRenewsOrEnds() {
        XCTAssertEqual(PlanWallCopy.monthlyStatus(endsOn: day, freeSpan: nil, renews: true, monthly: "£1"),
                       "Your plan renews on Friday 24 October, and everything in Red Moon is open.")
        XCTAssertEqual(PlanWallCopy.monthlyStatus(endsOn: day, freeSpan: nil, renews: false, monthly: "£1"),
                       "Your plan ends on Friday 24 October and won't renew. Everything you made stays.")
    }

    /// A family-shared monthly isn't the player's own, so its end isn't known and nothing is claimed.
    func testWithoutAnEndYourPlanClaimsNoDate() {
        XCTAssertEqual(PlanWallCopy.monthlyStatus(endsOn: nil, freeSpan: nil, renews: false, monthly: "£1"),
                       "You're on the monthly plan, and everything in Red Moon is open.")
    }

    func testBeforeThePriceLoadsTheFreeWeekStillSaysWhatFollows() {
        let text = PlanWallCopy.monthlyStatus(endsOn: day, freeSpan: "week", renews: true, monthly: nil)
        XCTAssertTrue(text.contains("Then it renews monthly until you cancel"))
    }

    // MARK: - D1: Home's countdown

    private var london: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return calendar
    }

    private func november(_ day: Int, _ hour: Int) -> Date {
        london.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour)) ?? .distantPast
    }

    private func countdown(from now: Date, to end: Date?, span: String? = "week", renews: Bool = true) -> String? {
        PlanCountdown.line(freeSpan: span, endsAt: end, renews: renews, now: now, calendar: london)
    }

    func testTheCountdownCountsDays() {
        XCTAssertEqual(countdown(from: november(2, 20), to: november(9, 20)), "Your free week ends in 7 days")
        XCTAssertEqual(countdown(from: november(7, 9), to: november(9, 20)), "Your free week ends in 2 days")
    }

    /// Calendar days, not 24-hour blocks: two hours before a week that ends at 1am, it ends tomorrow.
    func testTheEveningBeforeReadsTomorrow() {
        XCTAssertEqual(countdown(from: november(8, 23), to: november(9, 1)), "Your free week ends tomorrow")
    }

    /// The last day never reads "0 days".
    func testTheLastDayReadsToday() {
        XCTAssertEqual(countdown(from: november(9, 8), to: november(9, 20)), "Your free week ends today")
    }

    /// 0144 D6: nagging someone who has already cancelled is the opposite of honest.
    func testNothingOnceCancelled() {
        XCTAssertNil(countdown(from: november(2, 20), to: november(9, 20), renews: false))
    }

    func testNothingOutsideTheFreeWeek() {
        XCTAssertNil(countdown(from: november(2, 20), to: november(9, 20), span: nil), "A paid month")
        XCTAssertNil(countdown(from: november(9, 21), to: november(9, 20)), "A week already over")
        XCTAssertNil(countdown(from: november(2, 20), to: nil), "No end read yet")
    }

    // MARK: - D1: round prices stay round

    private func pence(_ amount: Int) -> Decimal { Decimal(amount) / 100 }

    func testWholePricesAreWhole() {
        XCTAssertTrue(PlanPrice.isWhole(Decimal(1)))
        XCTAssertTrue(PlanPrice.isWhole(Decimal(15)))
        XCTAssertTrue(PlanPrice.isWhole(pence(1500)))
    }

    /// A conversion that isn't whole keeps its pence: rounding it in copy would state a price
    /// nobody charges.
    func testAConversionWithPenceIsNotWhole() {
        XCTAssertFalse(PlanPrice.isWhole(pence(109)))
        XCTAssertFalse(PlanPrice.isWhole(pence(1499)))
        XCTAssertFalse(PlanPrice.isWhole(pence(50)))
    }

    // MARK: - D9: the UI-test override

    private let uiTesting = UITestHooks.launchArgument
    private let plan = UITestHooks.planArgument

    func testUITestsRunOnPayOnceByDefault() {
        XCTAssertEqual(UITestRuntime.parsePlan(in: [uiTesting]), .payOnce)
    }

    func testPlanFreeRunsWithoutThePlan() {
        XCTAssertEqual(UITestRuntime.parsePlan(in: [uiTesting, plan, UITestHooks.planFree]), PlanAccess.none)
    }

    func testPlanMonthlyRunsOnTheMonthly() {
        XCTAssertEqual(UITestRuntime.parsePlan(in: [uiTesting, plan, UITestHooks.planMonthly]), .monthly)
    }

    /// A typo costs one test its wall rather than stopping the whole suite at it.
    func testAnUnknownOrMissingValueFallsBackToPayOnce() {
        XCTAssertEqual(UITestRuntime.parsePlan(in: [uiTesting, plan, "fre"]), .payOnce)
        XCTAssertEqual(UITestRuntime.parsePlan(in: [uiTesting, plan]), .payOnce)
    }

    /// Outside UI testing StoreKit decides: no argument alone can open, or close, the plan.
    func testRequiresUITesting() {
        XCTAssertNil(UITestRuntime.parsePlan(in: [plan, UITestHooks.planFree]))
        XCTAssertNil(UITestRuntime.parsePlan(in: []))
    }
}
