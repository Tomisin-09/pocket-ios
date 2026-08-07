# StoreKit sandbox validation — the purchase path (ADR 0112)

**Status:** prerequisites cleared 2026-08-07, testing not started · **Blocks:** shipping any build
that shows the paywall — and it is the **last open item in v2**.
**Context:** ADR 0112 merged 2026-07-28 (PR #178, `47fbd83`); ADR 0144 (PR #220) made the trial
length read from the product. The ASC products are set up and out of Draft; **the purchase path
itself is still unverified.**

## Progress — device pass 2026-08-07

**Account A (monthly → lapse) is COMPLETE and passed.** Sandbox confirmed at every checkpoint: the
purchase sheet showed `[Sandbox]`, the confirmation showed `[Environment: Sandbox]`, prices in GBP,
and both plan cards offered the 1-month trial before purchase. `isPro` flipped, gates opened, the
lapse re-locked every surface, the free surface survived, and the paywall's negative-eligibility
state was confirmed before any eligibility reset.

**Two findings came out of it.**

1. 🐛 **A lapse did not re-lock until a cold launch** — fixed on branch
   `pocket-241-entitlement-foreground-refresh`, and ✅ **re-verified on device 2026-08-07**: the app
   now re-locks on return from background, with no force-quit. `refreshEntitlements()` had no
   foreground caller and a plain expiry mints no transaction, so `Transaction.updates` never fired.
   Worse than a stale screen: the trial countdown *did* vanish on time (it reads a stored date, not
   StoreKit), so the app announced the trial was over while still granting it. Fix = `scenePhase →
   .active` re-check at the app root.
   ⚠️ **Reproducing this needs a lapse that happens while the app is backgrounded** — a lapsed
   account plus a fresh launch proves nothing, because `init` always resolved correctly. The cycle is:
   Reset Eligibility → buy → cancel auto-renew → **background without force-quitting** → wait out the
   period → return via the app switcher. Note also that the UI tests can never cover this or the
   locks: `-uiTesting` forces `debugProOverride = true`, so `isPro` is always true under test and the
   locked state is never rendered.
2. 💄 The recent-routines rail and the "Jump back in" card were both gated but drew **no lock** — the
   two doors on Home that looked open while they weren't. `proGated` only swaps the destination for a
   paywall button; the padlock lives in each card's own label, and neither had one. Locks added on
   the same branch, trailing on the eyebrow/top row where `HomeNavCard` puts them. ✅ **Both confirmed
   present on device 2026-08-07** — which is the only way they *can* be confirmed, since the UI tests
   run fully unlocked.

**Two things that turned out not to be testable or needed as written:**

- **The trial reminder notification cannot fire in sandbox.** `TrialReminderPlan.leadTime` is 24h and
  the compressed trial is ~5 minutes, so `decide` always returns `.cancel` — correctly. Covered by
  `TrialReminderPlanTests` instead. The old suggestion to drive it from Xcode's *Manage StoreKit
  Transactions* doesn't apply either; that's a local-config feature.
- **"Reset Eligibility" exists** on the sandbox account's Manage → Subscriptions screen, and resets
  intro-offer eligibility per subscription for the same account. This softens (does not remove) the
  "one account, one shot" constraint below: a spent account is now reusable for trial testing. Two
  accounts are still wanted, so one can hold a live entitlement while another is lapsed.

**Cancelling auto-renew in sandbox** is Settings → Developer → Sandbox Apple Account → Manage →
Subscriptions → Cancel Subscription. **Not** the app's own Manage Subscription, which presents
`.manageSubscriptionsSheet` against the *production* account.

### Still outstanding

- [ ] Re-verify finding 1's fix on device against a lapsed account
- [ ] **Account B** — annual purchase, monthly ↔ annual switching (a deferred downgrade is the correct
      result, given the level split)
- [ ] **Restore on a wiped install** — needs a spare device or a device backup; see the warning below
- [ ] The `.storekit` "Sync from App Store Connect" loose end
- [ ] The pre-submission items

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

✅ **The sitting was done 2026-08-06.** Recorded here because the console state is the input to
everything below, and none of it is visible from this repo.

### 1 — Make the two offers agree, at 1 month ✅ DONE

The 2026-08-06 device pass found the annual on a **14-day** intro offer and the monthly on a
**2-month** one — neither the decided value, and not even the same value. Hardcoded paywall copy
would have hidden this; ADR 0144 D5 made the app read the length from the product, which is why it
surfaced.

- [x] Annual (£49.99/yr) — free, **1 month**, all storefronts  (was 14 days)
- [x] Monthly (£5.99/mo) — free, **1 month**, all storefronts  (was 2 months)

ASC has no 30-day option; **1 month is the decided value** (ADR 0144 D5), and the app will say
whatever the product says. `Configuration/RedMoonPro.storekit` already carries `P1M` on both, so
**no code change was owed here** — that file only drives simulator and local runs.

### 2 — Out of Draft ✅ DONE (verify the screenshot is current)

Group **Red Moon Pro** (ID `22260435`), console state as of 2026-08-07:

| Level | Reference name | Product ID | Duration | Status |
|---|---|---|---|---|
| 1 | Red Moon Pro Annual | `click.decooperations.pocket.pro.annual` | 1 year | Prepare for Submission |
| 2 | Red Moon Pro Monthly | `click.decooperations.pocket.pro.monthly` | 1 month | Prepare for Submission |

- [x] Reference name · duration · price
- [x] Subscription **group** localization — English (U.S.), display name "Red Moon Pro", app name
      "Red Moon Practice"
- [x] Per-product localization, and the per-product **review screenshot** — implied complete, since
      an incomplete sheet shows *Missing Metadata* rather than *Prepare for Submission*
- [ ] ⚠️ **Confirm the review screenshot is the post-#221 paywall** (Red Moon PRO wordmark,
      loops-led copy). "Prepare for Submission" only proves a screenshot exists, not that it is the
      current one. If it predates #221 it is a stale depiction of the purchase screen.
- [ ] Review notes — name the **free Toolkit and Journal** here as well as in the app's own review
      notes (ADR 0144's 2.1 / 3.1.2 mitigation)

**"Prepare for Submission" is the state sandbox needs.** It means metadata is complete and nothing
has been sent to App Review. Sandbox accounts can purchase at this status; neither Apple's approval
nor a released build is required. **So workstream C is unblocked — do not submit anything in order
to test it.**

**The level split is a decision, not a default.** Annual sits at level 1 and monthly at level 2, so
ASC treats monthly → annual as an **upgrade** (takes effect immediately, prorated refund of the
unused monthly) and annual → monthly as a **downgrade** (deferred to the next renewal date). Had
both sat at the same level it would be a crossgrade. This is a sane arrangement — just know it is
the behaviour the "monthly ↔ annual switching" test below will actually observe, so a deferred
downgrade is the correct result, not a bug.

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

**One phone is enough** — a sandbox account signs in at a slot entirely separate from the real App
Store account, purchases never charge, and nothing is wiped by switching. The *only* step that needs
a spare device is the restore test; see the warning on it below.

- [ ] **Install with `scripts/run-device.sh`, not from Xcode.** It launches via `devicectl`, which
      never applies the scheme's StoreKit configuration, so the build reads live ASC data by
      construction. Prefer this over setting the scheme option to None: `project.yml` wires the local
      config in, so **any `xcodegen generate` silently restores it** — and a branch switch already
      requires one.
- [ ] Sign the sandbox account in on the iPhone at **Settings → Developer → Sandbox Apple Account**
      (some iOS versions: Settings → App Store → Sandbox Account). **There only** — never sign it into
      the main App Store account. Sign out again when the pass is finished.
- [ ] Hit a gate → paywall → buy. **The sheet must say `[Environment: Sandbox]`.** If it doesn't,
      you're not in sandbox — go back to the two switches.

### Switching sandbox accounts between passes

Eligibility is one-shot per account, so a full pass needs **two accounts plus a spare** — one to
spend the trial and lapse it, one to hold a live entitlement for the negative-eligibility and restore
checks.

- **Finish one account's cycle end to end before switching.** Bouncing mid-cycle makes it ambiguous
  whose state is on screen, and the lapse checks are the ones most worth believing.
- **Force-quit and relaunch after every switch.** Sandbox account changes are sticky and the previous
  account's entitlement can linger — the same "looks like it works, none of it is real" failure as the
  two switches above. A relaunch re-runs `StoreManager.init` → `refreshEntitlements()`, and
  `refreshSubscriptionState()` clears `currentExpiration`/`willAutoRenew` when nothing is owned, so a
  stale trial countdown clears itself rather than bleeding into the next account.
- **Use trial visibility as the tell that the switch took:** fresh account shows 1 month, spent
  account shows nothing. A spent-looking paywall on an account you haven't bought anything with is
  stale state, **not** an eligibility bug.
- **The Entitlement picker is per device, not per account** — set it to Default once and leave it.

## What to actually test

Buying is the easy path. These are the ones that break:

- [ ] **Purchase annual** → `isPro` flips → gates open
- [ ] **Purchase monthly** → same
- [ ] **Restore on a wiped install** — delete the app, reinstall, tap Restore Purchases. Apple
      requires this to work and it's a common rejection reason.
      ⚠️ **This is the one destructive step, and it destroys real data.** `Pocket.entitlements` is
      empty — no CloudKit, no iCloud sync (it's deferred to "Phase 4 when sync lands") — and the app
      has no export and no file sharing. So deleting it permanently destroys every song, loop, marker,
      journal entry, take and practice-log row on that device. Do this on a **spare iPhone**, or take a
      full Finder/iCloud device backup first (app containers are included). Sandbox needs real
      hardware, so a spare device — not the simulator, which only ever serves the local `.storekit`
      file. ⚠️ **"Offload App" is not "Delete App"**: offloading preserves Documents & Data, so a
      reinstall after an offload gives a container that was never wiped and the test passes without
      proving anything.
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

### The first subscription must ride along with an app version

Apple's rule, [documented in App Store Connect Help][asc-submit]:

> "Your first consumable In-App Purchase and your first non-consumable In-App Purchase must each be
> submitted with a new app version. Similarly, your first auto-renewable subscription and your first
> non-renewing subscription must each be submitted with a new app version." … "Once the first item
> of each type has been approved, you can submit additional items of that type without a new app
> version." … "If you're submitting a new subscription it must be submitted together with its
> subscription group. Each new subscription group must be submitted with at least one of its
> subscriptions."

These are Red Moon's **first** auto-renewable subscriptions, in a **new** group. v1 was approved
without any IAPs, so that approval does not discharge the rule. Therefore:

- [ ] Create a **new app version** in ASC, upload a build of it, and use **Add for Review** on the
      Red Moon Pro group to attach **both** subscriptions to that version's submission. Group +
      subscriptions + binary go to review as one submission.

**This resolves the chicken-and-egg below rather than aggravating it.** The worry was shipping a
paywall against products that aren't live yet; because Apple *forces* the first subscription into
the same submission as an app version, the binary and the products are approved and go live
together. There is no ordering left to get wrong — the failure mode would be submitting a paywall
build *without* attaching the group, which the rule prevents.

[asc-submit]: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase

### The rest

- [x] **ASC "Content Rights" — no change needed after all.** v1 declared *"No third-party content"*,
      which briefly stopped being true when *Binta* by Jack Trader shipped as the bundled demo song.
      **ADR 0148 §7 drops the demo song**, so the app ships no third-party content and the existing
      answer stands.
- [ ] **Don't ship the paywall before the ASC products are live.** If a build reaches users first,
      `isPro` is permanently false and every Pro surface locks with no way to buy. Attaching the
      group to the version submission (above) is what guarantees this.

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
