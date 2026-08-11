# 0144 — One app, one price

- **Status:** Accepted — built and **device-verified** 2026-08-06 (`pocket-235-one-app-one-price`),
  v2 close-out workstream A. The device pass is what added the Journal to D2's free surface, and it
  caught a live App Store Connect inconsistency (annual on a 14-day intro offer, monthly on a
  2-month one) that D5's derived copy reported faithfully instead of papering over.
- **Date:** 2026-08-06
- **Supersedes:** the **tier half** of ADR 0112 (freemium monetization). 0112 stays as the record of
  why a free line existed, what it cost to build, and why it was withdrawn before it ever met a
  user. Its *pricing* (£5.99/mo · £49.99/yr, annual-first), its `StoreManager` design, its
  "gate at read time, never persist entitlement" rule and its `AccessPolicy` seam all survive
  unchanged.
- **Builds on:** ADR 0070 (Pocket never grades the player — holds at every tier), ADR 0113 (the
  profile is local and account-free — which is why the trial reminder is a *local* notification and
  never an email), ADR 0120 (analytics: opt-in, closed event vocabulary, `reportingName` strings are
  frozen wire format), ADR 0092 (AI is the later paid lever, unchanged by this).

## Context

v1 is **approved by App Review and deliberately held**. There are no users, no purchase history and
no migration cost. This is the cheapest moment the business model will ever be changeable, and the
last one before the teacher-recruited TestFlight cohort sees the app.

The ADR 0112 free line is expensive in two currencies.

**In code.** It needs a `canAuthor`/`canRun` split, two frozen slug allowlists (`freeTasteSlugs`,
`freeTasteRoutineSlugs`), a routine-bypass rule to stop a Pro drill being smuggled into a free
routine and run there, and a demo-edit exception with its own footer copy explaining why Add is
missing. Every one of those exists to describe a boundary — not to make the app better at practice.

**In first impressions.** What a free player actually meets is a locked museum: four preset
exercises they may run but not edit, one routine they may rearrange but not extend, and a paywall
behind most taps. The taste was meant to hook conversion. What it more plausibly does is teach
someone that this app mostly says no.

Two things make a hard paywall defensible rather than hostile, and both are cheap:

1. **The Toolkit is genuinely useful on its own** — tuner, metronome, chord and theory tools. It
   already contains **zero `isPro` reads**, so leaving it free costs nothing to build. A lapsed or
   undecided player lands on something worth keeping installed, and therefore stays re-convertible.
   It also gives App Review something to evaluate without a sandbox purchase.
2. **An honest trial ending.** A month-long annual-first trial is the highest-regret shape in the
   catalogue: long enough to forget, expensive enough to resent. Accidental conversion comes back as
   refunds, one-star reviews, and exactly the word-of-mouth damage the teacher channel can least
   afford.

## Decision

- **D1 — The free/Pro split is retired. The whole app is Red Moon Pro, evaluated through a free
  trial.** There is no permanent free content tier: no free-tier templates, no free-taste presets,
  no runnable demo routine.

- **D2 — The Toolkit and the Journal are free forever, and those two exemptions are the entire free
  surface.**
  - The **Toolkit** — tuner, metronome, chord tools, theory tools, glossary, and after ADR 0145 the
    help. It is not a taste of the paid product; it is a different, complete, small thing we give
    away. It contains no gates within.
  - The **Journal** — your notes, your session reflections, your recordings, and the Progress screen
    that reads them. *Added on the device pass, 2026-08-06.* The argument is trust, not
    merchandising: **what you wrote and what you recorded is yours, and a lapsed subscription must
    not take it back.** A player who cancels and finds their practice diary locked has been punished
    for leaving, and that is precisely the story that reaches a teacher's other students. It also
    costs almost nothing to give — the Journal is *empty* without Pro-authored practice to write
    about, so this makes no free player self-sufficient.
  - The Journal's doors **out** — an entry's caption opening its exercise, loop or routine — stay
    gated (`JournalTabView` already routes them through `AccessPolicy`). Reading your own history is
    free; walking from it back into the workbench is not. This is the D3 defence-in-depth gates
    doing real work, and it is what let the exemption be a two-line change.

- **D3 — `AccessPolicy` survives as the single seam. Its call sites are not removed.** The policy
  *bodies* collapse to `isPro`; the ~20 call sites, the `isFreeTastePreset:`/`isFreeTasteRoutine:`
  parameters (now defaulted) and the slug helpers all stay. Both allowlists become empty sets with a
  comment naming them as the seam. **A future free line is then a one-file change**, and the gates
  keep working as defence in depth behind D4's wall. Deleting the seam to save a few lines would
  make the decision irreversible in exchange for nothing.

- **D4 — Gate at the Home destinations, plus one launch wall.** Twenty individual gates with
  everything Pro means twenty walls to walk into. So: the top-level Home destinations that lead into
  the workbench — **Practice, Song library and Today's session**, plus the two second doors into
  those same surfaces (**"Jump back in"** and the **recent-routines rail**) — present the paywall
  when `!isPro`; **Toolkit and Journal do not** (D2); and a dismissible full-screen paywall appears
  **once per launch** while `!isPro`.
  Cards stay **visible and locked** rather than hidden — a visible locked app is the merchandising,
  and the paywall's value props are otherwise abstract claims about a screen you've never seen.

- **D5 — Trial length is a month, and is derived from StoreKit, never hardcoded.** Written as
  "30 days" throughout the planning; App Store Connect has no 30-day option, so the offer is **1
  month** (`P1M`) on both products, and the app says whatever the product says. The live number
  lives in App Store Connect; `Configuration/RedMoonPro.storekit` only drives local and simulator
  testing. Paywall copy formats it from
  `product.subscription?.introductoryOffer?.period`, and eligibility is read for the **selected**
  plan rather than always the annual one. Hardcoded copy is how you ship a paywall that promises the
  wrong number to a real buyer; deriving removes the bug class rather than fixing an instance of it.

- **D6 — The trial-end reminder is a product commitment, not a nicety.** Two halves:
  - an **in-app countdown** ("Trial ends in N days · Manage") on Home and in Settings while in
    trial, deep-linked to `.manageSubscriptionsSheet` — needs no permission and cannot be denied;
  - an **opt-in local notification** 24 hours before conversion, whose authorization is requested
    **from the paywall, before purchase**, behind a "Remind me before the trial ends" toggle. Asked
    there it is something the player requested; asked after the buy it reads as "we want to sell you
    more" and gets denied.

  The scheduling decision is **pure and unit-tested** (`TrialReminderPlan`): it returns nothing when
  auto-renew is already off (nagging someone who has already cancelled is the opposite of honest),
  when the trial has passed, or when the fire date is behind us. Local notifications only — **no**
  `aps-environment` entitlement and no push, per the AGENTS.md rule against entitlements the app
  doesn't exercise.

- **D7 — No email reminder.** The app is account-free and local-only (ADR 0113). We have no address
  and will not collect one to send a billing warning.

- **D8 — First-run seeding is unchanged.** Six exercises, one routine, one song still seed on a
  fresh install. They are no longer a "free taste" — they are **trial content**, and they are what
  makes a trial worth starting rather than a month-long tour of an empty app. `presetSlug` stays on
  `Exercise` and `Routine` as seeding provenance; the specs in `PracticePresets.swift` and
  `RoutinePresets.swift` are untouched.

## Consequences

> **Two later decisions attach here (2026-08-11), neither of which disturbs the pricing model.**
>
> **Comping the closed-beta testers uses hand-renewed offer codes, not a lifetime product.** The
> eight invited testers are promised permanent access. The tempting implementation — a
> non-consumable "lifetime" IAP — is **rejected**: it reopens the one-price model this ADR settled,
> adds a third product to a two-product group, and creates an entitlement that can never be
> withdrawn or repriced. Instead they get subscription **offer codes**, reissued by hand each year.
> That is manual work forever for eight people, which is the honest trade: an operational cost
> carried deliberately, rather than a permanent product-line change made to avoid it. During the
> beta itself nothing is needed — the TestFlight sandbox grant in `StoreManager` already covers it.
>
> **D3's free-taste seam is being reopened by ADR 0158**, for the bundled demo song and its
> first-launch walkthrough. Note that it does **not** land the way D3 predicted: `freeTasteSlugs`
> and `freeTasteRoutineSlugs` cover exercises and routines, and there is no song axis at all — songs
> are gated at the Home destinations. So it is a new allowlist on the established pattern rather
> than the promised one-file change. **D4's gates stay as defence in depth**, which is what keeps
> the hole safe: walking out of the free song still meets a wall.

- **A new App Review, on stricter ground.** The held v1 approval was for a freemium build; a hard
  paywall draws 2.1 and 3.1.2 scrutiny. The free Toolkit is the mitigation and **must be named in
  the review notes** — after ADR 0145 it also carries the help and the support address, which
  strengthens the case further.

- **Intro-offer eligibility is one-shot per Apple Account per subscription group.** Anyone who
  consumed a trial in sandbox or TestFlight will not see the month. Test with a fresh sandbox
  account, and do not read a missing trial as a bug. This is also why StoreKit sandbox validation
  (workstream C) must run *after* this ADR ships and not before it.

- **`AccessPolicyTests` inverts.** Most assertions previously proved a free player *could* do
  something; they now prove they cannot. That is the intended shape of the change and the test file
  is the record of it.

- **Dead code removed:** `showsDemoFooter`, `isFreeTasteDemo` and `demoFooterText` in
  `RoutineDetailView+Access.swift` (the file stays — `canAddBlocks` / `canDeleteBlocks` still route
  through the seam).

## Alternatives rejected

- **Keep the free taste, add the launch wall anyway.** The two fight: a wall that says "everything
  is Pro" over an app that then lets you run four drills is incoherent, and it keeps all the
  boundary code.

- **Free tier = the Toolkit *plus* running (but not authoring) anything you already made.** Sounds
  generous, but it is unbounded: a lapsed player who authored 200 drills on trial keeps the whole
  app. It also reintroduces the run/author split this ADR exists to delete.

- **A shorter, safer trial (7 or 14 days).** Considered because a month annual-first is the
  regret-maximising pairing. Rejected because a practice habit is not evaluable in a week — the
  product's value claim *is* the fourth week. D6 is what pays for the length; if the reminder had
  slipped, the correct response was to shorten the trial, not to ship a month of it silently.

- **Hardcode "30-day" in the paywall copy and keep the ASC number in sync by hand.** This is
  precisely the bug that D5 exists to make impossible.

- **Delete `AccessPolicy` and test `isPro` inline.** Saves ~100 lines today and costs a
  fifteen-file change the first time a free line comes back.
