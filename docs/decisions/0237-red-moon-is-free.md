# ADR 0237 — Red Moon is free

- **Status:** Accepted — building on `pocket-343-free` (2026-10-01).
- **Date:** 2026-10-01 (decided 2026-09-24; the removal scoped in Q&A on 2026-10-01)
- **Supersedes:** ADR 0112 — the Pro tier, its trial, its gates and its StoreKit design are gone
  (D1, D2). Its reason for existing, a free set of play-along tools beside a paid workbench, is moot,
  because there is no paid workbench. The Oracle tier it reserved is now governed by D3.
- **Supersedes:** ADR 0144 — D1 (the whole app is Pro), D3 (`AccessPolicy` kept as a seam), D4 (the
  Home gates and the launch wall), D5 (trial length from StoreKit), D6 (the trial reminder) and D7
  (no email reminder) all go. D2's *Toolkit and Journal free forever* is now true of everything, and
  its trust argument becomes D3 here. D8's first-run seeding stands as written, and its content is
  onboarding now, not trial content.
- **Supersedes:** ADR 0156 — proposed and never built. It budgeted a launch wall that no longer exists.
- **Amends:** ADR 0187 — **D20**: there is no Practice tier. If Oracle ever carries a price it is
  the only thing that does, and D3 below constrains what it may contain. Everything else in 0187
  stands, and the Oracle stays parked (0211); this ADR does not reopen it.
- **Amends:** ADR 0219 — the gate, not the song. **D5** (one access axis keyed on a frozen id) and
  **D7** (the launch wall defers once) go with the wall. D1–D4, D6, D8 and D9 stand: the starter
  track still ships, still arrives by tap, and its card was always about an empty library (D4).
- **Amends:** ADR 0162 — **D2**: the *Red Moon Pro* hub row is removed, so the group above
  PREFERENCES is *You* alone (D7).
- **Amends:** ADR 0120 — **§4**: four events leave the closed vocabulary, `paywall_shown`,
  `paywall_dismissed`, `purchase_completed` and `restore_completed`. Their names are retired, never
  reused (D8). §1–§3 and §5–§7 are unchanged.
- **Relates to:** 0070 (never grades; held at every tier, and now there is one) · 0113 (the intake
  wins the first screen, and now nothing competes with it) · 0158, 0220 (the starter track as
  onboarding) · 0186 (the practice-reminder sweep that clears the trial notification) · 0189
  (additive schema) · 0165 (the manual quotes the app).
- **Schema:** none. No `@Model` change and no migration (D6).

## Context

On 2026-09-24 the owner decided Red Moon ships free. It is a portfolio piece, not a business. The
driver was not reach or conversion. It was not wanting to sell: the energy that pricing, a paywall,
banking, tax and VAT across territories would take is better spent on the work. The maintenance floor
that remains (the developer programme fee and a build each year for the new iOS) was considered and
accepted.

What the app ran until this ADR is ADR 0144 as amended by 0219. Every capability was Red Moon Pro.
Home drew padlocks on Practice, the Song library, Today's session, Jump back in and the recent-routines
rail. A full-screen paywall came up once per launch. Settings had a Red Moon Pro screen with a trial
countdown, Manage and Restore. A trial reminder could schedule one local notification. One song, the
bundled starter track, was open as a free taste. In code that was 64 app files and 18 test files
reading the paywall's symbols, and about 180 non-comment lines in `Pocket/Features` alone.

**No one has ever subscribed.** The products in App Store Connect were never sold. So there is no
subscriber to carry across, no entitlement to honour, and no "cancel your old subscription" message to
write.

**Nothing about Pro was ever persisted on a model.** ADR 0112 gated at read time: `isPro` was
computed live and passed into `AccessPolicy`, and no `@Model` field carried it. `Exercise.presetSlug`
and `Routine.presetSlug` look like entitlement fields and are not. They are seeding provenance.

## Decisions

### D1 — The app is free, with no in-app purchase

No subscription, no tier, no trial, no tip jar, no one-time unlock. The App Store price is Free. The
two products and their group are removed from sale in App Store Connect, which is the owner's action,
not the repo's.

### D2 — Remove the machinery; don't leave it dormant

0144 D3 kept `AccessPolicy` as a seam on the argument that deleting it "would make the decision
irreversible in exchange for nothing". That argument does not survive D3 below. The seam's one use
was to draw a line across capability that already exists, and D3 forbids exactly that. Keeping it
would keep about two hundred branches whose only purpose is a move this ADR rules out.

The branches were also never exercised. `-uiTesting` forced Pro through a debug override, so every UI
test drove the unlocked app, and the locked branch a free player actually met was the one no test ran.
With the gates gone, UI tests run the same app users get.

So all of it goes: `AccessPolicy`, `StoreManager`, `PaywallTrigger`, the paywall and its host, the
trial countdown, the trial reminder and its plan, `ProSettingsView`, the `.storekit` configuration and
the scheme's reference to it. **Git history is the archive.** `f3a4175` is the last commit with all of
it in place.

### D3 — If Oracle ever has a price, it is strictly additive

This is the decision that makes free safe to promise. **Nothing that is free today may ever move
behind a price.** If an Oracle reading is ever charged for, it is the only thing that is, and
everything it reads (loops, routines, the Journal, takes) stays free whether or not the player pays.
Adding a paid feature to a free app is ordinary. Withdrawing something a player already had is the
betrayal 0144 D2 refused to commit with the Journal, and that refusal now covers the whole app.

The Oracle's own future is **not decided here.** It stays parked behind 0211's research question,
and S2–S5 of 0187 remain unstarted. If it returns with a price, StoreKit comes back as new code
written against that day's API, scoped to Oracle alone. It is not restored from history wholesale.

### D4 — The starter track stays, as onboarding

The starter track and its **Start here** card stay exactly as 0219 and 0220 built them. 0219 D6
already said the card is about an empty library, not about entitlement, and that is now the only
reason it exists. A new player meets one song that arrives by tap, signposted, with the walkthrough on
it. It is no longer a free taste of anything.

`StarterTrack.sourceID` stays frozen. `SongFileStore` names the adopted copy after it, and the
walkthrough and Home's card find the song by it. `Song.isStarterTrack` moves out of `AccessPolicy`
into `StarterTrack`, which is Foundation-only.

### D5 — Stale trial notifications are cleared on launch

A tester who took a sandbox trial may still have the trial-ending notification pending, and nothing
would ever cancel it. The practice-reminder launch sweep (0186 D3) already reads every pending request
in the app's notification centre. It now also removes the one with the trial reminder's fixed id,
`click.decooperations.pocket.trial-ending`. The id is kept as a single named constant, with a comment
saying why it outlives the feature.

### D6 — No data migration

There is no store change, because there was never anything about Pro in the store (Context). Four
`UserDefaults` keys may be left on an upgraded install: `launchWallDeferred`, `trialEndsAt`,
`trialReminderEnabled` and, in debug builds only, `debugProOverride`. Nothing reads them any more, so
they are inert. Deleting them would take code that runs on every launch, forever, to tidy values nobody
reads, so they stay where they are.

The first-run seed (six exercises, one routine, 0144 D8) is unchanged, and so are the preset slugs.
`PracticePresets` and `RoutinePresets` lose only their comments about a free taste.

### D7 — Settings loses its Red Moon Pro row

The group above PREFERENCES held two rows, *You* and *Red Moon Pro*, on 0162's argument that they were
state rather than preferences. *You* stays there alone. The debug section loses its Free/Pro/Default
override and *Show paywall*.

### D8 — Four analytics events retire, and their names are never reused

`paywall_shown`, `paywall_dismissed`, `purchase_completed` and `restore_completed` are removed from
`AnalyticsEvent`, along with `SubscriptionProduct` and `PaywallTrigger`. The vocabulary goes from
eighteen events to fourteen. Event names are a frozen wire format (0120 §4), so a retired name stays
retired. A future event that reused one would land on the old series in the dashboard and be read as
continuous with it.

## Consequences

- **Every surface opens.** Practice, the Song library, Today's session, Jump back in and the recent
  routines all open, the cards show their chevrons, and "Draw your own" is always enabled. There is
  no launch wall, so nothing competes with the first-run intake (0113) for the first screen.
- **The copy describes things, not tiers.** "Free forever" was a contrast with Pro. Where the manual,
  the App Store listing or the site said it, the thing is now described for what it is. In the app
  that reached one control: the Toolkit's Tuner row said **Free** at its end, which was the app
  stating a tier, and now states the tuner's instrument. Help & FAQs loses its *Red Moon Pro*
  section and both its questions.
- **The manual loses a chapter.** `docs/manual/subscription.md` and its figure go, and every link to
  them.
- **Reversibility.** Putting a price on something that exists is closed by D3. Putting a price on
  something new is open, and would be written fresh.
- **Outside the repo, owed by the owner:** the App Store Connect products and group removed from sale;
  the listing's subscription wording, the auto-renew/EULA line and any paywall or padlock screenshot
  replaced from `docs/app-store-listing-copy.md`; App Privacy re-checked for a Purchases declaration;
  the Paid Apps agreement kept or dropped at the owner's choice. The public site (`uk-site`) carries
  the same claims on three pages, and is updated in one release with the ADR 0236 privacy change that
  is already owed.
- **Lost:** the evidence `paywall_shown` would have given about which gate players reached for. It
  answered a question this ADR stops asking.

## Alternatives rejected

- **Flip the seam, leave the machinery** (the plan as first recorded on 2026-09-24): set
  `AccessPolicy`'s floor to everything and delete `StoreManager` later as clean-up. Rejected in the
  2026-10-01 Q&A for D2's reasons. It keeps every branch and every test of a policy that can never be
  used again, and the debug override would go on hiding the difference from UI tests.
- **A tip jar or a one-time unlock.** Either is a purchase, and so needs the Paid Apps agreement,
  banking and tax that free was chosen to drop. It is also selling, in a smaller voice.
- **Keep "free forever" on the Toolkit and the Journal.** In an app with no tier it reads as a hint
  that something else is not free.
