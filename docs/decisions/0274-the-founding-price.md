# ADR 0274 — The founding price: yours for as long as you keep the plan

- **Status:** Accepted. Tomisin decided the founding price on 2026-10-21 and chose the wording on
  2026-10-23. Built on `pocket-388-founding-price`. Still owed, outside the repo: the App Store
  description and the site (Consequences).
- **Date:** 2026-10-23
- **Amended by:** ADR 0277 (2026-10-26) — **D2**: the prices that hold the lock are £0.99 a month
  and £14.99 once, because App Store Connect offered no round point. 0277 also records that the
  founding price is the products' price, not an introductory offer. The lock and D1's wording stand.
- **Amends:** ADR 0256 — **D8**: the promise's second line. *"We'll never raise the price"* goes, and
  a price lock takes its place (D1, D2 here). The second half, *"nothing you can do today will ever
  move behind a higher one"*, stays word for word. Two other things go with it: D8's reason for
  saying *"We'll"* (D3 here) and the Consequences' *"A price can never rise"* (Consequences here).
  D1's prices, and everything else, stand.
- **Relates to:** 0237 D3 (nothing free may ever move behind a price, which D8's second half carries
  on) · 0263 (keeping is free; its *"D8's promise above all"* now means this wording) · 0145 D6 (help
  copy names no price and no period) · 0187 and 0211 (the Oracle stays parked; 0256 D11's per-use
  exception stays outside the lock)
- **Schema:** none. Nothing about the plan is stored on a model. The lock is a choice made in App
  Store Connect on the day of a price rise (D3).

## Context

ADR 0256 D8 promised, word for word on the wall, in the App Store description and on the site:

> **£1 a month, or £15 once.**
> We'll never raise the price, and nothing you can do today will ever move behind a higher one.

On 2026-10-21 Tomisin pulled back from the first half: *"I'm gonna climb back from the promise to
never change the price. But the price will remain the same, just that now, it'll be marketed as a
founders price... no end in sight but at least it gives me the latitude to raise prices [with]
minimal negativity. Especially since users who pay the one price will be rewarded."*

**Now is the time to change it.** Nobody has bought the plan yet, because neither product has been
created in App Store Connect. So, as when 0256 replaced 0237's promise, the change comes before
anyone has been made the promise it takes away.

"Founding price" can mean two different things:

- **A promotion.** A low price that ends one day. One with no end in sight is a permanent sale,
  which is exactly the trick the round £1 was chosen to rule out (0256 D1: *"no tricks or
  nothing"*).
- **A lock.** The price can rise, but never for a player who already holds it. The promise moves
  from the price to the person. Tomisin's own analogy from 0256 fits it: a fixed-rate tariff
  fixes the customer's rate, not the tariff.

This ADR chooses the lock.

## Decisions

### D1 — The promise, verbatim

This replaces 0256 D8's quote. It appears in the same places: the wall, the App Store description
and the site.

> **£1 a month, or £15 once.**
> That's the founding price, and it's yours for as long as you keep the plan. Nothing you can do
> today will ever move behind a higher one.

- **The first line is still built from the products' own prices** (0256 D3), so an American player
  reads *$1 a month, or $15 once.*
- **The second half stays word for word.** Tomisin pulled back from the price promise, not from the
  free line.
- **The condition is in the promise itself.** *"For as long as you keep the plan"* says, in the
  promise, when the lock ends (D3), so no small print is needed to qualify it.
- **The promise never appears** in the name, subtitle, screenshots or previews (Guideline 2.3.7,
  as in 0256 D8).
- **Tomisin chose this wording over two others:**
  - *"This is the founding price: we'll never raise yours."* It's shorter, but it isn't true for a
    player who lapses past Apple's window (D3), so the condition would have to sit in small print
    elsewhere.
  - *"Founding price: £1 a month, or £15 once."* This leads line 1 with the label. It's the most
    marketing-forward of the three, and selling is what 0256 kept off the wall.

### D2 — A lock, not a promotion

- **The prices don't change.** They stay £1 a month and £15 once (0256 D1). *(0277: £0.99 and
  £14.99, the nearest points App Store Connect offers.)*
- **No end date, no countdown, no "limited time".** Tomisin: *"no end in sight"*.
- **No struck-through "usual price".** Nobody has ever been charged one. Showing one would be the
  trick the round price exists to avoid.
- **The reward for joining early is the lock itself.** Nothing else is added. There's no badge, and
  no founder status on *Your plan*, which still says *Monthly* or *Pay once*. Whether founders get
  anything more is **not decided here**.

### D3 — What "yours" means for each way to pay

- **Pay once.** One payment, and nothing is ever charged again. A later rise reaches only later
  buyers.
- **The monthly.** When the price rises, App Store Connect's *Keep the current price for existing
  subscribers* is chosen, in every storefront, every time. A kept price is **never removed** for
  existing subscribers. Apple's help says that step can't be reversed, and taking it is the only
  way to break this promise.
- **Keeping the plan.** If a subscriber's monthly expires, Apple holds their kept price for **60
  days**. Resubscribe within that time and the price is still theirs. After it, they join at the
  price of the day. The 60 days is Apple's figure, not Red Moon's, and Apple can change it. So the
  in-app copy doesn't name it: the FAQ says Apple holds the price *"for a while"*. That follows
  0145 D6's rule that help copy names no figure the App Store owns, and `FAQEntryTests` enforces it.
- **From the monthly to Pay once.** At any given time, Pay once has one price for everyone. A
  founder on the monthly who switches to Pay once later pays that day's Pay once price. The lock
  covers the way a player already pays, not the other way.
- **Apple's own price changes.** *"Retail price changes initiated by Apple due to tax changes and
  significant foreign exchange rate movements will exclude auto-renewable subscriptions."* So the
  monthly's price only moves when Red Moon moves it. 0256 D8 said *"We'll"* to leave room for
  Apple's moves, and that hedge is no longer needed. Apple may still move Pay once's price in
  another storefront, but that only affects players who haven't bought it.

Source: App Store Connect Help, *Manage pricing for auto-renewable subscriptions*
(developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions),
read 2026-10-23.

### D4 — The first price rise, if there is one

Nothing here schedules a rise. If one comes, it happens in this order:

1. **Ship a build first** whose wall and FAQ no longer call the new price "the founding price". The
   first line follows StoreKit automatically, but the word *founding* doesn't. A new player reading
   *"£2 a month… That's the founding price"* would be reading something false.
2. **Then schedule the rise** in App Store Connect, keeping existing subscribers' prices (D3).

The copy for after a rise needs its own ADR, amending this one.

0256 D11 leaves one exception open: a feature with a real per-use running cost could be priced on
its own. That exception stays outside the lock, just as it stayed outside the old promise, because
the lock covers the plan's price. **The Oracle's future is not decided here.**

### D5 — What changes in the app

- `PlanWallCopy.promiseLine` now holds D1's second line. `PlanAccessTests` pins it word for word.
- Help & FAQs ▸ *Will the price go up?* now answers *"Not for you."* and explains the lock without
  naming a price or a period.
- Nothing else changes: the first line, the wall's layout, StoreKit and Settings ▸ *Your plan* stay
  as they are.

## Consequences

- **Reversibility.** This replaces 0256's *"A price can never rise (D8)"*:
  - A free door still can never close.
  - The price can rise for new players, but never for a player who holds it.
  - A paid door can still open later.
- **Owed outside the repo** (release work, step 5 of the plan): the App Store description and the
  site carry D1's wording, not 0256 D8's.
- **Nothing to set up in App Store Connect now.** *Keep the current price* is a choice made on the
  day of a rise (D4), not a setting.
- **Nothing to add to the sandbox pass.** The lock lives in App Store Connect and involves no code.

## Alternatives rejected

- **Keep *"We'll never raise the price."*** Tomisin's call: it rules out ever raising the price, for
  everyone, forever.
- **A founding price as a promotion,** whether time-limited or with no end. See Context.
- ***"We'll never raise yours."*** See D1.
- **"Founding price:" leading the first line.** See D1.
- **A struck-through "usual price".** See D2.
