# ADR 0256 — One plan: £1 a month, or £15 once

- **Status:** Accepted — decided with Tomisin on 2026-10-16/17, as step 2 of the release plan
  (pricing, the Practice hub, the detail sheets). Built on `pocket-367-one-plan`. Still owed, outside
  the repo: App Store Connect, the sandbox device pass and the site (Consequences).
- **Date:** 2026-10-17
- **Supersedes:** ADR 0237 — **D1** (the app is free, with no in-app purchase) and **D7** (Settings
  loses its plan row): Red Moon has one plan again (D1 here), and Settings shows it (D10). **D3**'s
  promise that nothing free may ever move behind a price is replaced, before anyone held the free
  build, by D2's free line and D8's promise. **D2** stands as history: the old machinery stays
  deleted, and StoreKit returns as new code (D9), not restored from `f3a4175`. D4, D5, D6 and D8
  stand.
- **Amends:** ADR 0162 — **D2**: the group above PREFERENCES holds *You* and *Your plan* again, and a
  third row, *Cancel your monthly plan*, while D5's condition holds.
- **Relates to:** 0112 (whose free line, "play-along tools beside a paid workbench", this mostly
  restores, without the Journal) · 0219 (the starter track: no longer the only open door, still the
  onboarding) · 0144 (its D5 rule, that the trial's length is read from the product, holds again for
  the free week; D1) · 0187 and 0211 (the Oracle stays parked, and its price is not decided here; D11) ·
  0070 (never grades, at every tier) · 0181 (Your data) · 0255 (no release build until main's UI job
  is green)
- **Schema:** none. Nothing about the plan is stored on a model; access is read live from StoreKit
  (D9).

## Context

ADR 0237 made Red Moon free on 2026-10-01. The free build never shipped. Red Moon has never been on
sale, and no one has had the free build, so no promise 0237 made has reached a player yet.

On 2026-10-16 Tomisin reopened pricing, and reframed it. What Red Moon sells is **control and
stability**, not ownership. The price is "more than a price, it's a signifier": it sets Red Moon
apart from the expensive apps on one side and the large catalogue of free ones on the other. Going
free had partly been about not wanting to be a salesman, and that is a reason to keep the offer
small and plain, not a reason to have none.

A subscription suits stability, because stability is delivered month by month. A UK fixed-rate
tariff is the comparison: you pay for the fix, not the gas. The thing such a plan promises never to
do is what is usually called enshittification.

**The first draft (2026-10-17 morning) made only the starter song free.** The same day Tomisin moved
the line: *"we'll make the song library and media player free… this would be the original taster,
but everything else attached to it i.e. journal and practice will be gated."* The original taster is
ADR 0112's free line. D2 is that line, with the Journal moved behind the plan.

## Decisions

### D1 — One plan, two ways to pay

| | Price | Kind | Product id |
|---|---|---|---|
| Monthly | **£1 / $1** a month | auto-renewable subscription, group *Red Moon* | `click.decooperations.pocket.plan.monthly` |
| **Pay once** | **£15 / $15** | non-consumable | `click.decooperations.pocket.plan.payonce` |

- **Round on purpose.** Not £0.99 and not £14.99. Tomisin: the round figure "seems more intentional,
  no tricks or nothing".
- **No annual plan.** At £8.99 a year against £15 once, Pay once costs less than two years of annual,
  so the annual's only buyer is someone who doesn't believe the promise. Three tiers is also the
  standard paywall playbook (the compromise effect, decoy pricing), which is selling.
- **The monthly starts with a free week.** It is an introductory offer on the monthly in App Store
  Connect: *Free*, one week. Apple decides who is eligible: an Apple Account that hasn't had an
  introductory offer in the group before. Tomisin, later the same day, replacing this ADR's first
  "no trial": the month's trial of 0144 D5, shortened to a week. Pay once has none: introductory
  offers belong to subscriptions, and the week on the monthly already lets a player try the whole
  plan before paying anything.
  - **The length is read from the product, never written in the app** (0144 D5's rule, kept). The
    wall says *free for a week* because the product says a week. Change it in App Store Connect and
    the copy follows. Help & FAQs names no length (0145 D6).
  - **No trial reminder.** 0144 D6's notification is not restored. *Your plan* says when the free
    week ends and what follows (D10), and the disclosure beside the buttons says how to cancel. A
    reminder would be a decision of its own, and it would need a new notification id, because 0237
    D5 deletes the old one, `…trial-ending`, on every launch.
- **Other storefronts:** use App Store Connect's conversion from the base price and adjust later by
  ear. Don't set them by hand up front.
- **New product ids.** The old `…pocket.pro.monthly` / `…pro.annual` (£5.99 / £49.99, never sold) are
  taken off sale, and App Store Connect never reuses an id.

The two options are called **monthly** and **Pay once**. Not *Lifetime*, which raises "whose
lifetime?", and not *Own it*, because Red Moon sells control, not ownership.

### D2 — Playing is free; practising is the plan

**Free, for good:**

- the first-run intake (0113) and the starter track (0219);
- the **Song library**: import, organise (folders, collections), Song details, *Send this song* and
  *Export audio file*, and receiving a song;
- the **song player**: play, scrub, slow down, pitch, the click, the beat grid, A–B loops, and
  **saving loops, markers and snags**, with every field on them (name, range, mastery, type, command
  tempo, colour, tags, backing track) and the per-loop speed automator;
- **Map the song**, which is the song's own map;
- the **Metronome** (with its automator), the **Tuner**, the **Glossary** and **Help & FAQs**;
- **Settings**, all of it, including **Your data**.

**The plan:**

- the **Practice** hub: drills, routines, the loops library and the Practice log;
- **Today's session**;
- a loop's launches: **Practice now** (the loop trainer), **Train your ear**, **Watch it on the
  neck** and **Improvise**;
- drills from anywhere: *New exercise*, the Metronome's *Save as exercise*, *Carry this tempo* into
  a drill, and a song's *Exercises for this song*;
- routines from anywhere: a song's *Build a routine*, Song map's *Together*, a collection's
  session;
- the **Journal**: the tab, a loop's *Journal*, a snag's line, and takes, which are only ever
  recorded inside runs;
- the Toolkit's **My chords**, **My progressions** and **My tabs**;
- receiving a shared routine or drill.

Tomisin chose where the line sits inside a song: **loops free, practising paid**. The alternatives
were saving loops on the plan, and the whole song screen free. Saved loops are what make the player
worth opening twice, because they are its memory of a song. Everything that *practises* a loop
leaves the song screen to do it.

**The rule for everything after this:** *a feature that plays or keeps a song, or a tool that
remembers nothing, is free. A feature that practises or journals is the plan.* Whatever is free at
launch stays free for good (D8), which is the reason to keep this set no larger than it is.

### D3 — The wall stands in the screen, not at each door

Each gated screen wraps its own body in `PlanGated`. Without the plan, the screen draws the wall in
place of itself:

- as the pushed screen, when it was pushed;
- with its own close button, when it was a sheet.

Behind the wall nothing is built: no audio starts, no task runs, and no row is written.

This is the opposite of ADR 0144's shape, which tested `isPro` at about two hundred call sites
(0237 D2). The screen owns its gate, so every route to it meets the wall: Home, a song's links, a
reminder's tap, a shared file, Jump back in, and any door added later that nobody remembered to
gate. About twenty screens carry a gate. Their callers do not change.

- **Locked, not hidden.** Home's gated tiles and cards, and the Toolkit's three *My* rows, draw a
  lock while the plan is off, so a door that opens onto the wall says so first. Deeper doors, such
  as a loop's launches, open the wall without a lock, and the wall explains itself.
- **After buying, the player stays where they were going.** The wall is replaced by the screen they
  tapped, not by a confirmation.
- **The wall's contents:**
  - the door's name;
  - a headline: *"Practising is part of the plan."* for a first-timer, or *"Everything you made is
    still here."* for a returning player (D4);
  - one sentence on what is free and what the plan adds;
  - the promise (D8), with both prices read from StoreKit;
  - two buttons, *£1 a month* and *Pay once · £15*;
  - **Restore purchases**;
  - the auto-renewal disclosure;
  - Terms of Use (Apple's standard EULA) and the Privacy Policy, as Guideline 3.1.2 requires.
- **Prices are never hard-coded.** Every amount on screen comes from the product (`Product.planPrice`),
  so an American player reads $1 and the copy can't disagree with the price sheet. A whole amount
  drops its pence (*£1*, not StoreKit's *£1.00*), because round was the point (D1). A storefront whose
  conversion isn't whole keeps them (*€1.09*), because rounding it in copy would state a price nobody
  charges. If the products don't
  load, the wall says it couldn't reach the App Store and offers *Try again*. It never shows a button
  that can't work.

### D4 — A lapsed player keeps everything, and loses only the doors

- **Nothing is deleted.** The app returns to D2's free set, and the gated doors show the wall.
- **Settings ▸ Your data is never gated.** Export, restore and storage stay open, so leaving is
  always possible.
- **No read-only mode.** It would be a third state on every screen, and "look but don't touch" is a
  sales tactic.
- The wall leads with ***"Everything you made is still here."*** for anyone StoreKit has seen buy
  before. Subscribing again opens everything.

### D5 — Buying Pay once while the monthly renews

An app cannot cancel a subscription, and buying Pay once doesn't cancel one either. So:

1. **Before the purchase**, if the monthly is renewing, the wall warns that it will keep renewing
   until it is cancelled, and that the next screen is where to do it.
2. **After the purchase**, Apple's own `manageSubscriptionsSheet(isPresented:subscriptionGroupID:)`
   opens straight away.
3. **While Pay once is owned and the monthly still renews**, Settings shows *Cancel your monthly
   plan* (D10), which opens the same sheet. The row exists only under that condition and goes away
   when the renewal stops.
4. While both are owned, *Your plan* offers *Ask Apple for a refund* (`refundRequestSheet`) on the
   monthly's latest payment, for the month that overlaps. Apple decides; Red Moon promises nothing.

Family-shared Pay once counts as Pay once here (D6). The monthly counts only if it is the player's
own (`ownershipType == .purchased`), because a shared subscription isn't theirs to cancel.

The monthly's free week is a renewing monthly too: unless it is cancelled, its first payment falls
when the week ends. So steps 1 to 3 hold through it unchanged. Step 4 doesn't: nothing has been
paid, so there is nothing to refund, and *Ask Apple for a refund* stays hidden.

### D6 — Family Sharing is on for both

Both products are family-shareable. That can't be undone in App Store Connect. Access ignores
ownership: a family-shared transaction opens the plan just as a purchase does. A revocation
(Family Sharing ended, or a refund) arrives through `Transaction.updates`, drops out of
`currentEntitlements`, and closes the plan on the next refresh.

### D7 — TestFlight testers buy Pay once

TestFlight purchases run in the sandbox, so they cost testers nothing. Testers buy **Pay once** inside
TestFlight. It never expires, which avoids the sandbox's sped-up renewal clock (the likely cause of
the 2026-08 beta lock-out), and it exercises the real purchase path. There is no automatic TestFlight
grant. Tomisin buys first on a real TestFlight build. The "What to Test" note then tells testers how.

### D8 — The promise

Verbatim on the wall, in the App Store description and on the site:

> **£1 a month, or £15 once.**
> We'll never raise the price, and nothing you can do today will ever move behind a higher one.

- It never appears in the name, subtitle, screenshots or previews (Guideline 2.3.7).
- *"We'll never raise"*, because Apple may move another country's price for tax or exchange rates,
  and that is Apple's move, not ours.
- It promises nothing about features that don't exist yet (D11).
- In the app, the first line is built from the products' own prices (D3).

### D9 — Mechanics: StoreKit 2, read live, refreshed on return

- **`PlanStore`** (`@Observable`, main actor) is the only type that talks to StoreKit. It loads
  products, buys, restores, reads `Transaction.currentEntitlements`, listens to `Transaction.updates`
  for the life of the app, and is injected at the app root.
- **A gate waits for StoreKit's first answer.** `access` starts at no plan, and the first read is
  async, so for a moment "no plan" and "not asked yet" look the same. In that moment a gate shows a
  spinner and no lock draws, so a paying player never meets the wall at launch.
- **It refreshes when the app returns to the foreground.** The 2026-08 sandbox pass found that a
  lapse didn't re-lock until a cold launch, because a plain expiry mints no transaction and so never
  reaches `updates`. A `scenePhase → .active` refresh at the root closes that.
- **The rules are pure and unit-tested** (`PlanAccess`, Foundation only): which owned products give
  which access (`none` · `monthly` · `payOnce`, with Pay once winning), which door is free, when the
  cancel row shows, and which headline the wall leads with.
- **Gate at read time.** Nothing is persisted. A lapse closes the doors and a purchase opens them,
  with no migration.
- **No store in the environment means no plan.** A view outside the root, such as a hosted test
  window, fails closed. An Xcode preview is the one exception: it draws the screen, because the
  previews are where screens get checked, and a wall in each of them would hide the thing being
  checked. A preview of the wall injects a store that has no plan.
- **A local StoreKit configuration** (`Configuration/RedMoon.storekit`) is set on the run scheme only,
  for the simulator and for Xcode-launched device runs. It is a local file, not a synced one: the old
  file carried App Store Connect's sync keys, which makes Xcode read products from ASC instead of the
  file. **It has not been seen to sell anything yet.** `SKTestSession` reports no storefront in this
  test host with any file (the 2026-08 finding again), and a UI test's app never receives the scheme's
  file. So the first proof is a run from Xcode, or re-syncing it from App Store Connect once the
  products exist. A `devicectl` launch (`scripts/run-device.sh`) never applies it, so that path always
  reads the real sandbox.
- **The free week, from StoreKit** (D1). The wall offers it only while
  `isEligibleForIntroOffer` says so. Eligibility is read again on every refresh, because a purchase
  uses it up. Its length is the product's `introductoryOffer.period`, phrased by `PlanTrial`, which
  is pure and reads seven days as a week. Whether the player is *in* the free week is the current
  transaction's `offer` (a free-trial introductory offer). That property is iOS 17.2 or later; on
  17.0 and 17.1 the app can't tell, so *Your plan* reads as an ordinary monthly. Sandbox and
  TestFlight use a trial up once per account, so test it with a fresh sandbox tester. A missing week
  on an old one is not a bug (0144's lesson).
- **Previews show the offer without StoreKit.** A preview store can carry the two prices and the free
  week, so the wall and *Your plan* can be checked in Xcode with the offer drawn, and buying from one
  does nothing.
- **Under test.** `-uiTesting` runs on Pay once, so the UI tests drive the whole app as before. Adding
  `-plan free` runs without the plan. **One UI test walks the free path**: the Song library and the
  Glossary open, and Practice and the Journal show the wall. 0237 D2's complaint was that the locked
  branch was the one no test ran, and that test is the answer. The override exists only in Debug
  builds.

### D10 — Settings shows the plan

The group above PREFERENCES holds **You** and **Your plan**, and also **Cancel your monthly plan**
while D5's condition holds (this reverses 0237 D7 and amends 0162 D2).

*Your plan* states its value (0162 D3): *Free*, *Monthly* or *Pay once*. Its screen shows:

- with no plan: the two options, the monthly's free week first if the player can still have it;
- on the monthly: Apple's subscription management, and the Pay-once option. During the free week,
  the status line names the day it ends and says what follows: £1 a month, or nothing if the player
  has already cancelled;
- on Pay once: a line saying it's done;
- with no plan and on the monthly: *Restore purchases*. On Pay once there is nothing left to
  restore.

### D11 — One plan, ever

New features join the one plan. Nothing is ever split into a second tier, because a second tier is
how the salesman comes back through a side door. The one exception the policy leaves open is a
feature with a real per-use running cost, which could be priced on its own. That is policy for the
ADR, not public copy. **The Oracle's future is not decided here.** It stays parked behind 0211.

## Consequences

- **The first public release is paid.** A stranger who meets Red Moon on the App Store gets the Song
  library, the song player, the Metronome and the Tuner without paying anything. That is a real
  product on its own, and it means the penny gap falls after the player has heard what Red Moon
  does, not before.
- **The App Store hides the signifier where Red Moon competes with free apps.** A subscription app
  shows *Get* in search, the same as a free one, and 2.3.7 keeps the price out of the name, subtitle
  and screenshots. The price lives in the description, the In-App Purchases list, a promoted
  Pay-once purchase if chosen, and the site.
- **The manual stays deprioritised.** It states no price (`check-manual.py` C6 holds that). A page
  on the plan is owed when the manual comes back into scope.
- **Owed outside the repo**, started as soon as this merges so that it overlaps the Practice hub:
  - **App Store Connect:**
    - check the Paid Apps agreement and banking are still active;
    - take the old `…pro.*` products off sale;
    - create the two products in D1, with Family Sharing on for both and £1 / £15 base prices;
    - give the monthly its introductory offer: *Free*, one week, in every territory;
    - set up a sandbox tester, and build to TestFlight.
  - **Sandbox device pass:**
    - start the free week with a fresh sandbox tester (the wall offers it, *Your plan* names its
      end), let it renew, and then check the wall no longer offers it;
    - buy the monthly, and buy Pay once;
    - buy Pay once while the monthly renews (warning → manage sheet → the Settings row appears,
      then clears after cancelling);
    - restore after a reinstall;
    - a lapse (the free set and the wall, with Your data reachable);
    - a family-shared purchase, if a second Apple ID is available.
  - Then **buy Pay once on TestFlight** and write the testers' note (D7).
- **Release work (step 5 of the plan):** the listing copy for paid (the promise, and the EULA link
  in the description), the IAPs attached to the submission, App Privacy re-checked for purchases,
  and the site's price, terms and privacy (§ Purchases).
- **Reversibility.** A free door can never close (D8). A price can never rise (D8). A paid door can
  open later, and nothing here prevents that.

## Alternatives rejected

- **The starter song as the only free song** (this ADR's first draft, the same morning). It made the
  library a wall, which meant a player had to pay before importing the song they came to learn.
  Tomisin moved the line to 0112's.
- **Saving loops on the plan.** That leaves a player who can loop live but can't keep anything. The
  song player stops being worth opening twice, and the free half can no longer sell the paid half.
- **The whole song screen free.** That puts takes, notes and the practice launches on the free side,
  which is the Journal and Practice wearing a song's clothes. It is not the line Tomisin drew.
- **An annual plan, three options.** See D1.
- **No trial at all** (this ADR's first draft: "£1 for the first month is the trial"), and **0144's
  month**. Tomisin chose a week. See D1.
- **A trial reminder notification** (0144 D6). See D1.
- **A read-only mode for a lapsed player.** See D4.
- **An automatic TestFlight grant.** It hides the real purchase path from the only people testing
  it, and the 2026-08 beta grant was removed for exactly that reason.
- **A gate at every call site** (0144's shape). Two hundred branches, each one a chance to forget
  one. D3 puts the gate on the screen instead.
