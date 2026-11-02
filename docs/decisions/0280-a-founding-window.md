# ADR 0280 — A founding window: £0.99 or £4.99 for the first 90 days on sale, then £2.99 or £9.99

- **Status:** Accepted. Decided with Tomisin on 2026-11-02, while 1.4 was in review and before the
  plan had been sold to anyone.
- **Date:** 2026-11-02
- **Amends:** ADR 0277 — **D1**: Pay once is £4.99 during the founding window, not £14.99, and after
  it the prices are £2.99 a month and £9.99 once (D1, D2 here). The product ids, the group and the
  free week stand. ADR 0274 — **D2**: *"No end date, no countdown, no 'limited time'"* no longer holds
  for the founding price, which now ends after 90 days on sale (D1, D4 here). The lock stands: D1's
  wording and D3's meaning of *yours* are unchanged, and the app still shows no countdown (D5 here).
- **Relates to:** 0256 (one plan, the free week, the name *Pay once*) · 0145 D6 (help copy names no
  price) · 0279 (the listing, whose description names the price)
- **Schema:** none. Prices are read from StoreKit (0256 D3).

## Context

0277 set the plan at £0.99 a month or £14.99 once, and 0274 called that the founding price: a lock,
with no end date. On 2026-11-02, with 1.4 in review, Tomisin wanted a founding price that meant
something. Under 0274 it had no edge: anyone joining at any time paid the same, so being early earned
nothing.

> I think it really gives a founding price meaning.

Tomisin's first version ended the window after *"the first month or 100 downloads, whichever happens
faster"* (D4). The decision, the same day:

> 0.99 monthly and 4.99 pay once are the final prices and 90 day price. After that we increase to
> 2.99 for month and 9.99 pay once.

**Now is the time to change it.** Nobody has bought the plan, so, as with 0274, no promise is taken
from anyone who was given it.

## Decisions

### D1 — The founding window: the first 90 days on sale

| | Founding (days 1–90) | After |
|---|---|---|
| Monthly | **£0.99** a month, a free week first | **£2.99** a month, a free week first |
| **Pay once** | **£4.99** | **£9.99** |

- **Day 1 is the day App Store availability goes on.** Record the date here when it happens; the
  window's last day is 89 days later.
- UK prices, the base storefront. Other storefronts take App Store Connect's conversion (0256 D1).
- The free week is unchanged in both periods (0256 D1).

### D2 — After the window

New players pay £2.99 a month or £9.99 once. These are the plan's prices from then on. Any later
change is a price rise or cut under 0274 D4, with its own ADR.

### D3 — Founders keep theirs

0274 D3, unchanged:

- **Pay once:** one payment, never charged again.
- **The monthly:** on the day of the rise, App Store Connect's *Keep the current price for existing
  subscribers* is chosen, in every storefront. A founder on the monthly pays £0.99 for as long as they
  keep the plan. If it lapses, Apple holds the price for 60 days.

### D4 — It ends on a date, not a count

*"The first month or 100 downloads, whichever happens faster"* was turned down:

- **Downloads aren't buyers.** If a few percent of downloads pay, 100 downloads is a handful of sales.
  The window could close having rewarded five people, before any marketing reached anyone.
- **A buyer couldn't know when it ends.** That turns honest scarcity into pressure.
- **The end has to be real.** UK consumer law bans false *limited time* claims outright. A date can be
  said in advance and kept.

### D5 — Where the window is said

- **The site, the App Store description, posts and the promotional text** say when the founding
  price ends and what follows. The description says it as a schedule (*"The founding price is for Red
  Moon's first 90 days on sale. After that, it's £2.99 a month, or £9.99 once."*), so it stays true
  after day 90 and doesn't wait on a new version to change.
- **The app shows no countdown and no *limited time*.** 0274 D2's reason holds inside the app: the
  wall states the price and the lock, it doesn't sell. During the window its words are true for every
  player: *"£0.99 a month, or £4.99 once. That's the founding price, and it's yours for as long as you
  keep the plan."*

### D6 — Nothing about the price changes during the window

Neither price, nor the plan's shape, changes in the 90 days. The next look at price is after day 90,
with sales in hand. Tomisin: *"I shouldn't think too much about the price, I'm definitely overthinking
that."*

### D7 — The order for day 91

0274 D4, applied:

1. **Before day 90, ship a build** whose wall and FAQ no longer call the price *the founding price*
   for a player who joins after the window. Its wording needs its own ADR, amending 0274. 1.4.1 can
   carry it.
2. **Schedule the rise** in App Store Connect for day 91, keeping existing subscribers' price (D3).
3. **Then the site** drops the founding block. The description can wait for the next version,
   because it states the schedule (D5).

## Consequences

- **What each sale brings in** (UK, after 20% VAT and Apple's 15% under the Small Business Program):

  | | Founding | After |
  |---|---|---|
  | Monthly | about 70p a month | about £2.12 a month |
  | Pay once | about £3.53 | about £7.08 |
  | Pay once, in months of the monthly | 5 | 3.3 |

  After the window, Pay once costs less than four months of the monthly, so most players who stay
  will pay once. Income follows new players more than renewals. Tomisin accepted that trade
  (Alternatives).
- **Code:** none for the window. The wall, *Your plan* and the FAQ read `displayPrice`. The local
  StoreKit configuration, the previews' prices and two doc comments move to £4.99.
- **Docs:** `PROJECT.md`, `docs/architecture.md`, the CHANGELOG's plan entry, and
  `docs/app-store-listing-copy.md` (the description's *One plan* block and the file's banner).
- **Owed outside the repo:**
  - App Store Connect: Pay once to £4.99.
  - **1.4's description said £14.99.** 1.4 was still *Waiting for Review* on 2026-11-02, so it is
    removed from review, given D5's description, and resubmitted.
  - The site (`uk-site`, branch `decops-066`).
  - Day 1's date, recorded in D1.
- **Reversibility.** A founder's price can't be taken back (D3). The prices after the window can
  change later under 0274 D4.

## Alternatives rejected

- **£4.99 as the permanent Pay once price.** About 7p per download against about 14p after the window,
  if 2% of downloads pay.
- **£14.99 after the window.** It keeps the founding ratio (Pay once at 5 months of the monthly), so
  the monthly keeps a long-term buyer, and each Pay once sale brings in about £10.60. Tomisin chose
  £9.99 as a price a player will call fair, and to stop reworking the price before anyone has paid it.
- **The first month or 100 downloads.** See D4.
- **The founding price as an introductory offer.** Pay once is a non-consumable and can't have one,
  and the monthly's one offer is the free week (0277 D2).
- **Half price for music students.** There's no way to check who is a student without accounts. If it
  comes back, it would be codes handed out through teachers and schools. **Not decided here.**
