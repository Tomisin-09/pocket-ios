# ADR 0320 — The promise says *your price*

- **Status:** Accepted. Tomisin chose the wording on 2026-11-25, from options proposed the same day,
  for 1.6.1, the build that goes on sale. Built on `pocket-480-your-price-after-the-window`.
- **Date:** 2026-11-25
- **Amends:** ADR 0274 — **D1**: the promise's second line reads *"That's your price for as long as
  you keep the plan. Nothing you can do today will ever move behind a higher one."* The first line,
  the places it appears, and the condition written into the promise stand. ADR 0319 — **D5**: the
  wording it left open is chosen here. ADR 0280 — **D5**: the wall says the new line during the
  window too, and never says *founding*.
- **Relates to:** 0256 D8 (the promise as first written) · 0145 D6 (help names no price or trial
  length) · 0306 (the site)
- **Schema:** none.

## Context

0319 cut the founding window to the first 30 days on sale, and put the wall's change in 1.6.1, the
build that goes on sale (0319 D5). 1.6 was approved on 2026-11-25 and won't be released, so every
player gets 1.6.1's wording from day 1.

Two strings said *founding* and stop being true after day 30:

- **The wall's second line:** *"That's the founding price, and it's yours for as long as you keep
  the plan."* From day 31 the line above it shows £2.99 and £9.99.
- **The FAQ's *Will the price go up?*:** *"Not for you. Today's price is the founding price, and
  it's yours…"* False after the window, and *not for you* was never true for a reader who hadn't
  joined.

Both have to be true during the window and after it, with no countdown in the app (0280 D5) and no
price or day count in help (0145 D6). Tomisin chose all three proposals below as they were offered,
then kept the site on *founding* until the window ends (D3).

## Decisions

### D1 — The wall's line

> **£0.99 a month, or £4.99 once.**
> That's your price for as long as you keep the plan. Nothing you can do today will ever move
> behind a higher one.

- **"Your price" is true on both sides of day 30.** The first line is built from the products'
  prices (0256 D3), so *that* is whatever this player would lock in today: the founding price during
  the window, the later one after it.
- **It's the smallest change to 0274's line.** The condition stays in the promise (*for as long as
  you keep the plan*), and the second sentence is word for word.
- **Also offered:** *"The price you join at is yours for as long as you keep the plan."* It says how
  the lock works in more words. The FAQ uses that phrase instead (D2), where there's room for it.

### D2 — The FAQ answer

> **Will the price go up?**
> Not once you have the plan. The price you join at is yours for as long as you keep it: a monthly
> plan renews at that price, and Pay once is never charged again. The price for new players can
> change; yours doesn't. If you stop the monthly, Apple holds your price for a while in case you
> come back; after that, you'd join at the price of the day. Nothing you can do today will ever move
> behind a higher one. There is one plan, and new features join it.

- **It answers both readers.** *Not once you have the plan* is true for someone who holds it, and
  *the price for new players can change* is honest with someone who doesn't, without a date (0280
  D5) or a price (0145 D6).
- **Also offered:** a minimal edit that kept *"Not for you"* and said nothing about new players.

### D3 — The wall and the description match; the site keeps *founding* until day 31

- **The App Store description takes D1's line**, word for word with the wall, as 0274 D1 asks. Like
  the app, it changes only with a version, so it follows the app. *Founding price* stays in its
  schedule sentence, which the app never shows (0319 D2):

  > The founding price is for Red Moon's first 30 days on sale. After that, it's £2.99 a month, or
  > £9.99 once.

- **The site keeps the founding line during the window**: *"That's the founding price, and it's
  yours for as long as you keep the plan."* Tomisin, 2026-11-25: the site can change *"much more
  quickly than we could for the app paywall"*, so it can say *founding* while it's true and change
  the day the window ends. Its own *Will the price go up?* answer, which names the schedule, stays
  too. On day 31 the site drops its founding block (0280 D7), and where it still quotes the promise,
  it takes D1's line.
- **So the promise is word for word on two of its three surfaces during the window.** This is the one
  exception to 0274 D1's rule, and it ends on day 31.

### D4 — The app never says *founding*

`PlanAccessTests` pins D1's line and fails if it says *founding*. `FAQEntryTests` fails if any help
answer does. The build on sale stays on phones long after the window, and these strings are compiled
into it.

## Consequences

- **A founder doesn't see the word in the app.** Their price is still locked (0274 D3); the app just
  calls it *your price*, as it does for everyone. 0274 D2 already gave founders no badge or status
  on *Your plan*. The listing and the site are where *founding* is said.
- **Code:** `PlanWallCopy.promiseLine`, the FAQ entry, and two tests. The wall's card holds a shorter
  line; nothing else on it moves.
- **Docs, in this change:** `docs/app-store-listing-copy.md` (the description's *One plan* block),
  the CHANGELOG, the back edges in 0274, 0280 and 0319, and a pointer in 0256's notes that quote
  0274's line. 0319's to-do on the description is corrected: Tomisin changed 1.6's description to the
  30-day line while 1.6 was waiting for review, which App Store Connect allows.
- **Owed outside the repo:**
  - **1.6.1's record in App Store Connect:** the description's *One plan* block, as in the listing
    copy. 1.6 was approved with the founding line, and 1.6.1's record starts as a copy of it.
  - **The site, on day 31:** with its founding block gone, the landing page's plan card and
    Support's plan paragraph take D1's line (D3).
- **Reversibility:** copy only. A different line later is a one-string change and an amendment
  here.

## Alternatives rejected

- **Keep *founding* in the app and switch the line on a date.** Day 1 isn't fixed before 1.6.1 is
  archived, and the switch would trust the phone's clock (0319 D5).
- **Leave the description on the founding line.** It changes only with a version, like the app, and
  it would split the promise between the two surfaces a buyer reads in the App Store.
- **Change the site now too.** Proposed first and accepted, then reversed by Tomisin the same day:
  the site can say *founding* while it's true and change in minutes on day 31 (D3).
