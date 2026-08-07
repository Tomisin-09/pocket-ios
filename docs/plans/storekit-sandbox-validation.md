# StoreKit sandbox validation — the purchase path (ADR 0112)

**Status:** not started · **Blocks:** shipping any build that shows the paywall
**Context:** ADR 0112 merged 2026-07-28 (PR #178, `47fbd83`). Everything below is unverified.

## Why this exists

The paywall, the gates and the entitlement layer are all built and merged. **The purchase itself has
never run — not once, not even in a fake environment.** Every test so far used either the local
`.storekit` config or the DEBUG `isPro` toggle. Neither touches Apple.

So the chain that actually matters is untested end to end:

> Apple confirms a purchase → `Transaction.currentEntitlements` reports it → `StoreManager` resolves
> `isPro = true` → every gate opens.

Until that runs against real App Store infrastructure, "the paywall works" means "the paywall
renders".

## The three environments (they are not interchangeable)

| | Products come from | Proves |
|---|---|---|
| Local `.storekit` config | `Configuration/RedMoonPro.storekit` in this repo | The UI renders. Nothing about Apple. |
| `SKTestSession` (unit tests) | Same local file, driven programmatically | Purchase logic in CI. **This is what failed** — see below. |
| **Sandbox** (device) | **Real App Store Connect**, real Apple servers | The actual thing: receipts, entitlements, renewals, restore. |

Only the third one validates `Transaction.currentEntitlements`.

## Prerequisites — "the ASC sitting"

One session in App Store Connect. Nothing here is code, and none of it can be scripted from this
repo; it is listed in the order the console makes easiest.

⚠️ **The two products currently disagree with each other.** The 2026-08-06 device pass found the
annual on a **14-day** intro offer and the monthly on a **2-month** one — neither is the decided
value, and they are not even the same value. Hardcoded paywall copy would have hidden this; ADR 0144
D5 made the app read the length from the product, which is why it surfaced. **Fixing this is the
point of the sitting** — everything else below is bookkeeping around it.

### 1 — Make the two offers agree, at 1 month

For **each** of `click.decooperations.pocket.pro.annual` and `.pro.monthly`, under
*Subscription Prices → Introductory Offer*:

- [ ] Annual (£49.99/yr) — free, **1 month**, all storefronts  ← currently 14 days
- [ ] Monthly (£5.99/mo) — free, **1 month**, all storefronts  ← currently 2 months

ASC has no 30-day option; **1 month is the decided value** (ADR 0144 D5), and the app will say
whatever the product says. `Configuration/RedMoonPro.storekit` already carries `P1M` on both, so
**no code change is owed here** — that file only drives simulator and local runs.

### 2 — Draft → Ready to Submit

Sandbox will not vend a draft. This needs **neither** Apple's approval **nor** a released build —
just a complete metadata sheet on each product:

- [ ] Reference name · duration · price (already set)
- [ ] Subscription **group** localization — "Red Moon Pro" display name (group-level, done once)
- [ ] Per-product localization — display name + description
- [ ] **A review screenshot on each product.** This is the field that keeps a product in Draft, and
      it is the reason the paywall's Red Moon PRO wordmark landed first: the screenshot is the
      paywall, so capture it *after* that change is on the device.
- [ ] Review notes — name the **free Toolkit and Journal** here as well as in the app's own review
      notes (ADR 0144's 2.1 / 3.1.2 mitigation)

### 3 — A fresh sandbox account

- [ ] ASC → Users and Access → Sandbox → Test Accounts. Use an email that has **never** been an
      Apple ID (a `+tag` alias works).

**Intro-offer eligibility is one-shot per Apple Account per subscription *group*.** Any account that
has already consumed a trial — including on the old 14-day offer — will never see the month, and a
missing trial on such an account is not a bug. "Clear Purchase History" on an existing test account
is not a reliable reset; make a new one. This is also why workstream C runs *after* ADR 0144 and not
before it.

- [x] **Paid Applications Agreement active** (confirmed: Tide GBP bank + W-8BEN-E tax all Active)

## The two switches that will silently fool you

Both fail quietly: everything *looks* like it's working, and none of it is real.

**`scripts/run-device.sh` is already clear of the first one** — confirmed 2026-08-06. The StoreKit
configuration is a *scheme run option* that Xcode applies when **it** launches the app; a
`devicectl` launch never applies it, so a script-installed build reads **real App Store Connect
data**. Two independent tells on that run: the paywall said "14-day" where the local file says
`P1M`, and priced in `$` where the local file is GBP. Useful — it means the script is a legitimate
way to see live product data — but it also means a device build from the script tells you nothing
about whether the *Xcode* scheme is still serving the local file.

- [ ] **Turn off the local StoreKit config.** `project.yml` wires
      `storeKitConfiguration: Configuration/RedMoonPro.storekit` into the run scheme. While it's set,
      StoreKit serves the local file and **never contacts sandbox**. Purchases will appear to succeed.
      Xcode → Scheme → Run → Options → StoreKit Configuration → **None**.
      Don't delete it from `project.yml` — it's genuinely useful for simulator work, and
      `xcodegen generate` restores it anyway.
- [ ] **Reset the DEBUG override to Default.** `StoreManager.resolveIsPro` is
      `debugOverride ?? entitled` — the override doesn't *influence* the answer, it **replaces** it.
      Left on, you're testing the toggle, not Apple. (UserDefaults key `debugProOverride`.)

## Running it

- [ ] Sign the sandbox account in on the iPhone at **Settings → Developer → Sandbox Apple Account**
      (some iOS versions: Settings → App Store → Sandbox Account). **There only** — never sign it into
      the main App Store account.
- [ ] Build to the device from Xcode with the StoreKit config off. Development signing is fine;
      `scripts/run-device.sh` covers the install.
- [ ] Hit a gate → paywall → buy. **The sheet must say `[Environment: Sandbox]`.** If it doesn't,
      you're not in sandbox — go back to the two switches.

## What to actually test

Buying is the easy path. These are the ones that break:

- [ ] **Purchase annual** → `isPro` flips → gates open
- [ ] **Purchase monthly** → same
- [ ] **Restore on a wiped install** — delete the app, reinstall, tap Restore Purchases. Apple
      requires this to work and it's a common rejection reason.
- [ ] **Trial eligibility** — the 1-month trial shows for a first-timer, and correctly does *not*
      show on a second purchase (`product.subscription?.isEligibleForIntroOffer`). The CTA and the
      disclosure must both name the length **read from the product** (ADR 0144 D5) — if they say a
      number ASC does not, that is the bug this is looking for. Eligibility is read for the
      **selected** plan, so check the monthly card too, not only the annual one.
- [ ] **Monthly ↔ annual switching** within the group (single entitlement, no double-charge)
- [ ] **Trial lapse re-locks every gate.** ⚠️ **The one most likely to be broken** — it's the
      least-travelled path in the feature, and ADR 0112's "re-enforce at trial lapse" clause has never
      been exercised. Check: **the locked Home destinations — Practice, Song library, Today's session —
      plus "Jump back in" and the recent-routines rail (ADR 0144 D4)**, exercise library rows,
      Draw your own,
      new-from-Pro-template, **and all five routine surfaces** (library `+`, Quick-session wand,
      Today's session, collection→session, song→routine).
- [ ] **The launch wall reappears after a lapse** — relaunch and it is there again, "Not now"
      dismisses it, and Home is locked-but-visible behind it.
- [ ] **The Toolkit and the Journal still work after a lapse** — tuner, metronome, chord and theory
      tools, glossary; and the Journal timeline, its takes and the Progress screen. This is the whole
      free surface (ADR 0144 D2) and the mitigation named in the review notes; if it locks, the App
      Review argument goes with it. A journal entry's caption tapping through to its exercise or
      routine **should** still hit the paywall.
- [ ] **The trial reminder** — with a short renewal rate in Xcode's *Manage StoreKit Transactions*:
      it fires ahead of conversion, the Home/Settings countdown tracks down, turning auto-renew off
      cancels it (and the countdown stays), and conversion clears the countdown rather than pointing
      it at the next renewal.
- [ ] **The old free-taste allowances are gone** (ADR 0144) — after a lapse the four former freebie
      exercises and Morning Routine are locked like everything else. If any of them still runs, an
      allowlist has been repopulated by accident.

Sandbox compresses subscription time so lapse is testable over a coffee (roughly: 1 year → 1 hour,
1 month → 5 minutes, renewing a handful of times before stopping). **Verify these against current
Apple docs rather than this table** — the values have changed between OS versions, and per AGENTS.md
Apple specifics aren't to be taken from memory.

## Lower-friction alternative

**TestFlight runs IAP in sandbox automatically**, with your normal Apple ID — no sandbox account, no
scheme fiddling, neither of the two switches to get wrong. Slower to upload, far fewer ways to be
fooled. If the Xcode route fights back, take this one.

## Loose end worth closing

`Product.products(for:)` returned `[]` under the `SKTestSession` harness, even called directly. The
test was backed out; commit `6380b20` realigned `RedMoonPro.storekit` to Xcode's format (numeric IDs,
proper intro-offer fields) but **that realignment is itself unverified**.

- [ ] Now that the products exist in ASC: open the `.storekit` file in Xcode → **Sync from App Store
      Connect**. That replaces the hand-written file with Apple's own output, which likely fixes the
      harness failure as a side effect — and would let the purchase test live in CI.

## Before any paywall build ships

- [ ] **Update the ASC "Content Rights" answer.** v1 declared *"No third-party content"*. That is no
      longer true: *Binta* by Jack Trader now ships bundled as the demo song (cleared by the rights
      holder). Separate from sandbox, but same submission.
- [ ] **Don't ship the paywall before the ASC products are live.** If a build reaches users first,
      `isPro` is permanently false and every Pro surface locks with no way to buy.

## Gotchas already paid for (don't re-discover these)

- A `static` method on a `@MainActor` class is main-actor-isolated — mark pure statics `nonisolated`
  or the tests won't compile.
- `.paywallHost()` must sit **inside** `.environment(store)` in `PocketApp`, or the host traps
  resolving `@Environment(StoreManager.self)` on launch.
- The `-uiTesting` launch argument forces Pro (DEBUG-only) so entitlement gates don't block UI-test
  flows. When gating anything new, run `-testPlan PocketAll` locally before pushing — the default
  local plan skips the UI tests.
- UI tests are only trustworthy against a **wiped** simulator container. The local sim accumulates
  seeded state a new user never has; a first-run change can pass locally and fail CI purely because of
  it (this exact thing failed CI on `d1ac247`).
