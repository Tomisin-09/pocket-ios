# ADR 0319 — The founding window is 30 days

- **Status:** Accepted. Decided by Tomisin on 2026-11-24, with availability still off and nobody
  ever having bought the plan. Built on `pocket-478-founding-window-30-days`.
- **Date:** 2026-11-24
- **Amends:** ADR 0280 — **D1**: the founding window is the first 30 days on sale, not 90, so its
  last day is 29 days after day 1. **D5**: the description's schedule line says 30 days (D2 here).
  **D6** and **D7** count to day 30 and day 31 instead of day 90 and day 91 (D3, D4 here), and
  D7's first step moves into the build that goes on sale (D5 here). The prices, the after-window
  prices, D3 (founders keep theirs) and D4 (it ends on a date, not a count) stand.
- **Relates to:** 0274 (the lock, and the wall's line, which changes in 1.6.1: D5 here) · 0279 (the
  listing) · 0306 (the site, which says the schedule too)
- **Schema:** none. Prices are read from StoreKit (0256 D3).

## Context

0280 set the founding window at the first 90 days on sale: £0.99 a month or £4.99 once, then £2.99
or £9.99 for players who join after. On 2026-11-24, with 1.6 cut and about to be submitted, Tomisin
asked for a shorter window:

> i want to make a small tweak to the founders price, instead of 90 days lets make it 30

A month is where 0280 began. Tomisin's first version ended the window after *"the first month or
100 downloads, whichever happens faster"*. 0280 D4 turned down the count, not the month, and its
reasons still hold.

**Now is still the time to change it.** Availability has been off since 7 August, so no player has
been told 90 days. The same day, Tomisin set the build that goes on sale: *"we'll go live with
1.6.1"*. Day 1 is the day 1.6.1's availability goes on.

## Decisions

### D1 — The founding window: the first 30 days on sale

| | Founding (days 1–30) | After |
|---|---|---|
| Monthly | **£0.99** a month, a free week first | **£2.99** a month, a free week first |
| **Pay once** | **£4.99** | **£9.99** |

- Day 1 is still the day App Store availability goes on, and it is still recorded in 0280 D1 on the
  day. The window's last day is 29 days later.
- UK prices, the base storefront. Other storefronts take App Store Connect's conversion (0256 D1).

### D2 — The schedule line says 30 days

0280 D5's description line, with the new length:

> The founding price is for Red Moon's first 30 days on sale. After that, it's £2.99 a month, or
> £9.99 once.

The site, the promotional text and posts say the same schedule. The app still shows no countdown and
no *limited time* (0280 D5).

### D3 — Nothing else about the price changes in the 30 days

0280 D6 holds for the shorter window: neither price, nor the plan's shape, changes in it. D6's next
look at price stays where it was, after day 90. It was set there so the look would have sales in
hand, and day 90 now brings two months of them at £2.99 and £9.99.

### D4 — The order for day 31

0280 D7, with the new days:

1. **The wall and the FAQ** stop calling the price *the founding price* for a player who joins after
   the window. This now happens before day 1, in 1.6.1 (D5).
2. **Schedule the rise** in App Store Connect for day 31, choosing *Keep the current price for
   existing subscribers* (0280 D3).
3. **Then the site** drops its founding block. The description can wait for the next version,
   because it states the schedule (D2).

### D5 — The wall's line changes in 1.6.1, the build that goes on sale

The wall's second line, verbatim from 0274 D1, is *"That's the founding price, and it's yours for as
long as you keep the plan."* It is true for every player during the window, and false for one who
joins on day 31 and reads it beside £2.99. The FAQ's *Will the price go up?* answer says *"Today's
price is the founding price"* and has the same problem.

0280 D7 gave a build 90 days to change it. With 30, two things argued against waiting until after
launch:

- **A month is short for a review.** 1.4 (10) sat in review for more than ten days, so a build sent
  after day 1 would have had to go in within the first fortnight.
- **An update doesn't reach every phone.** The line is compiled into the app, and the app makes no
  network call of its own (0239), so nothing can change it remotely. A player who installed during
  the window and didn't update would keep the old line beside the new price.

Tomisin chose to change it in 1.6.1, and to put 1.6.1 on sale (2026-11-24). So the build every player
gets from day 1 already carries the new line, and no build is owed inside the window.

- **The new line is shown during the window too**, so it has to be true on both sides of day 30. A
  line that switches on a date is possible only if day 1 is fixed before 1.6.1 is archived, and it
  would still trust the phone's clock.
- **The wording isn't chosen here.** It needs its own ADR, amending 0274 D1 (0280 D7), written
  before 1.6.1 is archived. The listing and the site keep saying *founding price* and the schedule
  (D2), so the founding price is still said where a buyer reads about the plan.

## Consequences

- **Fewer founders.** The window covers a third of the time, so fewer players get £0.99 and £4.99,
  and the after-window prices start two months sooner. What a sale brings in is unchanged (0280's
  table).
- **The January return falls after the window** unless day 1 is in December, and then only its
  first days. The marketing plan recommends not moving day 1 for it: the window rewards being early,
  and the price shouldn't set the launch date.
- **Code:** none for the window. The wall, *Your plan* and the FAQ read `displayPrice`. D5 changes
  the wall's and the FAQ's line in 1.6.1, under an ADR of its own.
- **Docs, in this change:** 0280 (header and notes at D1, D5, D6 and D7), the back notes in 0274 and
  0277 that quote 0280's 90 days, `PROJECT.md`, `docs/architecture.md`,
  `docs/app-store-listing-copy.md` (the banner, the description's *One plan* block, *Price /
  availability*) and the CHANGELOG.
- **Owed outside the repo:**
  - **The description in App Store Connect.** 1.6 went to review on 2026-11-24 with the
    description pasted that day, so it can't change there, and it doesn't need to: 1.6 never goes on
    sale. 1.6.1's record starts as a copy of it, so that is where the line becomes D2's.
  - The site's landing and support pages, which say 90 days (`site` branch, ADR 0306).
  - The Marketing Foundation, revised the same day.
  - Day 1's date, in 0280 D1.
- **Reversibility.** Free until day 1. After day 1 the end date has been said in public: shortening
  it would break it, which 0280 D4's reading of UK consumer law rules out, and lengthening it
  repeatedly turns the date into the kind of *limited time* claim D4 exists to avoid.

## Alternatives rejected

- **90 days, as 0280 decided.** Replaced at Tomisin's call on 2026-11-24.
- **The first month or 100 downloads.** Still rejected, for 0280 D4's reasons: downloads aren't
  buyers, and a buyer couldn't know when it ends.
- **Keep today's line in the build on sale and change it after day 1.** Rejected by D5: a month is
  short for a review, and a phone that doesn't update keeps the old line.
