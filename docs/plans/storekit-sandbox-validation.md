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

## Prerequisites

- [ ] **ASC products moved to "Ready to Submit."** Both subscriptions currently sit as drafts in
      "Prepare for Submission". Sandbox will not vend a draft. They need display name, description and
      a review screenshot — **not** Apple's approval, and **not** attachment to a released build.
  - `click.decooperations.pocket.pro.monthly` — £5.99
  - `click.decooperations.pocket.pro.annual` — £49.99
  - Group "Red Moon Pro", both with the **1-month** free intro offer (was 14 days — **ADR 0144**
    changed it; confirm the live ASC value before validating, since this is what you are validating)
- [x] **Paid Applications Agreement active** (confirmed: Tide GBP bank + W-8BEN-E tax all Active)
- [ ] **Sandbox test account** — ASC → Users and Access → Sandbox → Test Accounts. Use an email that
      has never been an Apple ID (a `+tag` alias works).

## The two switches that will silently fool you

Both fail quietly: everything *looks* like it's working, and none of it is real.

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
