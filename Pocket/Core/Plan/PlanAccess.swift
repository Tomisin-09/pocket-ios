import Foundation

/// Red Moon's one plan (ADR 0256): its two products, and the rules that turn what StoreKit says a
/// player owns into what they can open.
///
/// **Foundation only, and it decides everything.** `PlanStore` is the one type that talks to the App
/// Store, and it decides nothing: it reduces each transaction to an `OwnedPurchase` and hands the list
/// here. So every rule the ADR states is a unit test, not a sandbox session (AGENTS.md's pure-logic
/// rule).
enum PlanProduct {
    /// £1 / $1 a month, an auto-renewable subscription in the group *Red Moon* (D1).
    static let monthly = "click.decooperations.pocket.plan.monthly"
    /// £15 / $15 once, a non-consumable. Called **Pay once**, never *Lifetime* or *Own it* (D1).
    static let payOnce = "click.decooperations.pocket.plan.payonce"
    /// Both, in the order the wall offers them.
    static let all = [monthly, payOnce]
}

/// One verified transaction, reduced to the facts the rules read.
struct OwnedPurchase: Equatable, Sendable {
    let productID: String
    /// Shared by a family organiser rather than bought by this player (D6). Access ignores it; the
    /// cancel row does not, because a shared subscription is not this player's to cancel (D5).
    var isFamilyShared = false
    /// Set by a refund, or by the organiser ending Family Sharing (D6).
    var revokedAt: Date?
    /// The monthly's period end. `nil` for Pay once, which never expires.
    var expiresAt: Date?
}

/// What the player can open. Three states, because two of the rules care which way they paid: the
/// cancel row (D5) and *Your plan*'s summary (D10).
enum PlanAccess: String, Equatable, Sendable {
    case none
    case monthly
    case payOnce

    /// Whether the plan is on. Every gate reads this and nothing else: there is one plan, so there
    /// is nothing finer to ask (D11).
    var isOn: Bool { self != .none }

    /// *Your plan*'s value in Settings (D10).
    var summary: String {
        switch self {
        case .none: "Free"
        case .monthly: "Monthly"
        case .payOnce: "Pay once"
        }
    }

    /// The access a set of owned purchases gives. **Pay once wins**: someone who bought it while the
    /// monthly still renews has Pay once, which is what the cancel row (D5) is for.
    ///
    /// The revocation and expiry checks repeat what `Transaction.currentEntitlements` already
    /// filters. They are here so the rule holds for whatever list it is given, and a stale one can't
    /// keep a refunded plan open.
    static func resolve(_ owned: [OwnedPurchase], now: Date) -> PlanAccess {
        let live = owned.filter { purchase in
            purchase.revokedAt == nil && (purchase.expiresAt.map { $0 > now } ?? true)
        }
        if live.contains(where: { $0.productID == PlanProduct.payOnce }) { return .payOnce }
        if live.contains(where: { $0.productID == PlanProduct.monthly }) { return .monthly }
        return .none
    }

    /// Whether Settings shows *Cancel your monthly plan* (D5 step 3): Pay once is owned, by purchase
    /// or through the family, **and** the player's own monthly will renew again.
    static func offersCancelMonthly(access: PlanAccess, ownMonthlyRenews: Bool) -> Bool {
        access == .payOnce && ownMonthlyRenews
    }

    /// Whether the wall greets a returning player (D4): the plan is off, and StoreKit has seen this
    /// Apple Account buy it before.
    static func greetsReturningPlayer(access: PlanAccess, hasBoughtBefore: Bool) -> Bool {
        !access.isOn && hasBoughtBefore
    }
}

/// A screen behind the plan (ADR 0256 D2). The case names the wall's title, so a player who tapped
/// *Train your ear* reads that at the top, not a generic "Upgrade".
///
/// **Only the gated side is listed.** A free screen has no gate and so no door. The free line itself
/// is pinned by `PlanAccessTests`, against the Toolkit's sections, which are the one place free and
/// gated sit side by side in a single list.
enum PlanDoor: String, CaseIterable, Sendable {
    case practice
    case todaysSession
    case practiceLog
    case loopTrainer
    case earTraining
    case watchOnNeck
    case improvise
    case drill
    case newDrill
    case routine
    case journal
    case myChords
    case myProgressions
    case myTabs

    /// The wall's navigation title: the name the player tapped, as the app spells it there.
    var title: String {
        switch self {
        case .practice: "Practice"
        case .todaysSession: "Today's session"
        case .practiceLog: "Practice log"
        case .loopTrainer: "Practice now"
        case .earTraining: "Train your ear"
        case .watchOnNeck: "Watch it on the neck"
        case .improvise: "Improvise"
        case .drill: "Exercise"
        case .newDrill: "New exercise"
        case .routine: "Routine"
        case .journal: "Journal"
        case .myChords: "My chords"
        case .myProgressions: "My progressions"
        case .myTabs: "My tabs"
        }
    }
}

/// How a price is written (ADR 0256 D1). The prices are round on purpose ("more intentional, no
/// tricks"), and StoreKit's `displayPrice` would write £1 as "£1.00", so a whole amount drops its
/// pence. A storefront whose conversion isn't whole (€1.09) keeps them, because rounding a price
/// in copy would state a price nobody charges.
enum PlanPrice {
    static func isWhole(_ value: Decimal) -> Bool {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return rounded == value
    }
}

/// The monthly's free period (ADR 0256 D1), as App Store Connect sets it: a week today. The app
/// never states a length of its own (0144 D5's rule, kept). `PlanStore` maps the product's
/// introductory offer onto this at the boundary, so the phrasing is a unit test, not a sandbox
/// session.
struct PlanTrial: Equatable, Sendable {
    enum Unit: Equatable, Sendable {
        case day, week, month, year
    }

    let unit: Unit
    let value: Int

    /// `nil` for a period that isn't positive, so a malformed offer claims no trial at all. Whole
    /// weeks of days read as weeks, because StoreKit can report a week as seven days.
    init?(unit: Unit, value: Int) {
        guard value > 0 else { return nil }
        if unit == .day, value.isMultiple(of: 7) {
            self.unit = .week
            self.value = value / 7
        } else {
            self.unit = unit
            self.value = value
        }
    }

    /// After *for*: "a week", "2 weeks", "a month".
    var length: String { value == 1 ? "a \(noun)" : "\(value) \(noun)s" }

    /// After *the free*: "week", "2 weeks", "month".
    var span: String { value == 1 ? noun : "\(value) \(noun)s" }

    private var noun: String {
        switch unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        }
    }
}

/// The wall's words (ADR 0256 D3, D4, D8). Prices come in as the products' `displayPrice`, never as
/// literals, so the copy can't disagree with the price sheet in any storefront.
enum PlanWallCopy {
    static func headline(returning: Bool) -> String {
        returning ? "Everything you made is still here." : "Practising is part of the plan."
    }

    static func explanation(returning: Bool) -> String {
        returning
            ? "Your drills, routines and Journal are just as you left them. They open again with the plan."
            : "Your songs, loops and markers are free for good. The plan is for practising them: drills, "
                + "routines, Today's session, the loop trainer and your Journal."
    }

    /// The promise's first line (D8), in the player's own currency.
    static func promise(monthly: String, payOnce: String) -> String {
        "\(monthly) a month, or \(payOnce) once."
    }

    /// The promise's second line, verbatim (D8).
    static let promiseLine =
        "We'll never raise the price, and nothing you can do today will ever move behind a higher one."

    /// The monthly button's two lines (D1): the free week first, while the player can still have it.
    static func monthlyOption(monthly: String, trial: PlanTrial?) -> (title: String, detail: String) {
        guard let trial else { return ("\(monthly) a month", "Renews monthly. Cancel any time.") }
        return ("Try it free for \(trial.length)", "Then \(monthly) a month. Cancel any time.")
    }

    /// Guideline 3.1.2's disclosure, beside the buttons. With a free week on offer it also says what
    /// the week becomes, and how to leave before it costs anything.
    static func renewalDisclosure(monthly: String, trial: PlanTrial? = nil) -> String {
        let monthlyTerms = if let trial {
            "The monthly plan is free for \(trial.length), then renews automatically at \(monthly) a "
                + "month until you cancel it. Cancel in your Apple Account's Subscriptions at least 24 "
                + "hours before the free \(trial.span) ends and you pay nothing, or at least 24 hours "
                + "before any later renewal."
        } else {
            "The monthly plan renews automatically at \(monthly) a month until you cancel it. Cancel any "
                + "time in your Apple Account's Subscriptions, at least 24 hours before it renews."
        }
        return monthlyTerms + " Pay once is a single payment and never renews. Both are shared with your "
            + "family through Family Sharing."
    }

    /// *Your plan*'s status line on the monthly (D10).
    ///
    /// - `endsOn`: the current period's last day, as the player reads it. `nil` when the monthly isn't
    ///   the player's own (Family Sharing) or hasn't been read, so nothing can be said about its end.
    /// - `freeSpan`: the free period's span ("week") while the player is in it, otherwise `nil`.
    /// - `monthly`: the price, `nil` until the product loads.
    static func monthlyStatus(endsOn day: String?, freeSpan: String?, renews: Bool, monthly: String?) -> String {
        guard let day else { return "You're on the monthly plan, and everything in Red Moon is open." }
        switch (freeSpan, renews) {
        case (let span?, true):
            let then = monthly.map { "Then it's \($0) a month" } ?? "Then it renews monthly"
            return "Your free \(span) ends on \(day). \(then) until you cancel, and everything in Red Moon "
                + "is open."
        case (let span?, false):
            return "Your free \(span) ends on \(day). You've cancelled, so you won't be charged, and "
                + "everything you made stays."
        case (nil, true):
            return "Your plan renews on \(day), and everything in Red Moon is open."
        case (nil, false):
            return "Your plan ends on \(day) and won't renew. Everything you made stays."
        }
    }

    /// The warning before Pay once while the monthly renews (D5 step 1).
    static let renewingWarningTitle = "Your monthly plan will keep renewing"
    static let renewingWarning =
        "Paying once doesn't cancel it, and Red Moon can't cancel it for you. After you pay, your "
            + "subscriptions open so you can turn the monthly off."
}
