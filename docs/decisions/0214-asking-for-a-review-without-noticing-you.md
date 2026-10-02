# ADR 0214 — asking for a review without noticing you

- **Status:** Accepted — built (`pocket-318-review-prompt`), ported onto `main` after ADR 0237 on
  `pocket-345-review-prompt`
- **Date:** 2026-09-10 (`pocket-318-review-prompt`); ported 2026-10-01
- **Amended by:** ADR 0239 (2026-10-02) — **D7** goes: there is no analytics, so no
  `review_requested`. **D2**'s ladder loses the analytics rung, so the ask is the fourth rung, after
  the intake and the naming invitation. D3–D6 and D8 stand.
- **Relates to:** ADR 0186 (a reason to come back — D1's rule that the only legal trigger is
  something the player *did*, applied one surface further out), ADR 0070 (no performance feedback),
  ADR 0113 (the Home profile-moment ladder this joins as a fifth rung), ADR 0144 D4 (the launch
  paywall this was written to stay out from under — removed by ADR 0237 before this merged; see
  D3), ADR 0120 / 0147 (the closed analytics vocabulary and its
  refusal to widen), ADR 0145 / 0162 (Help & About, where the permanent door lives), ADR 0161 (the
  in-app contact form — considered as a destination for unhappy players, and rejected), ADR 0198
  (the end-of-session composer, which this deliberately does not touch)
- **Schema:** none. No `@Model`, no field, no migration. One `UserDefaults` key holding one JSON
  record.

## Context

Red Moon has never asked for a rating. There is no `SKStoreReviewController`, no
`RequestReviewAction`, no backlog item and no prior decision — the whole subject is unexamined, and
`StoreManager` has been the app's only StoreKit type. *(Ported note, 2026-10-01: ADR 0237 has since
deleted `StoreManager`, so this is now the app's only StoreKit use. `requestReview` needs no
entitlement and no `.storekit` configuration, and has nothing to do with a price.)*

That is a real gap at submission: ratings compound, the app has none, and every competitor in the
*practice organisers* cohort asks. But it is a gap in a product whose three most load-bearing
documents all forbid the mechanism that the category normally reaches for.

- **ADR 0186** — *"The app never notices your absence. It keeps appointments you made, and shows
  what is already true."*
- **`docs/design-brief.md` §3.5** — *"No shame."* The app grades neither playing nor habits. *"No
  streaks, no 'this year', no heatmaps, no consistency scores."*
- **`RoutinePlayerView+Finished.swift`**, in its own doc comment — the end-of-session composer
  *"asks an open question rather than fishing for a rating."*

The third one is the sharpest, because it describes the exact screen a growth-minded engineer would
put this on. The session-complete screen is where the player has just finished something and feels
good about it, which is why every playbook says to ask there, and why that file wrote down years ago
that it would not.

**A review prompt is nevertheless defensible here, and the distinction is not a loophole.** ADR 0186
and design-brief §3.5 forbid the app passing judgement on *the player* — their playing, their
consistency, their absence. A review prompt asks the player to pass judgement on *the app*. The
direction of the verdict is reversed, and it is the direction that those documents are about.

What survives from them is the constraint on the **trigger**: it must fire from something the player
just did, never from something they failed to do. That is ADR 0186 D1 restated one surface out, and
it is the single rule the rest of this file is built to make mechanical.

## Decision

**The app asks once, on the way back from work the player finished, and can never learn what
happened next.**

### D1 — the trigger is completed sittings, and it is not negotiable downward

The ask requires **five completed practice sittings** (`ReviewPromptPlan.sittingsBeforeAsking`).

A *sitting*, not a run. A six-block routine writes six `PracticeRun` rows in one evening, and
`PracticeLog.sittings(_:gap:)` already merges runs on a 30-minute gap; counting rows would fire the
ask on somebody's first evening. A sitting also only exists if a run **completed** —
`PracticeLogWriter` writes nothing for a run stopped by hand, and drops anything under a second — so
five sittings is five genuine finished pieces of work, on five occasions, usually across a week or
more.

Three is reachable in one determined evening either side of a coffee break. Ten is reached by a
minority of installs, which trades away most of the players the ask exists to reach. Five is the
first number that means *came back*.

**What the trigger may never be.** Not elapsed time since install, not a launch count, not a return
after a gap, and — most of all — not a lapse noticed and acted on. Every one of those is ADR 0186's
absence frame with a different question attached.

### D2 — it is the last rung of the ladder that already exists, and it draws nothing

`HomeView.maybeOfferProfileMoment()` already sequences the first-launch intake, the "you've earned a
name" invitation, and the analytics disclosure, each taking the screen exclusively (ADR 0113). The
review ask joins as the **fifth rung**, after all three.

Two things follow, and both are the point:

- **It never competes.** A player who has not seen the intake, has not been offered a name, or has
  not been told about analytics gets none of this. The rungs above it are the app's own business
  with the player; the ask is not, so it waits.
- **It is the only rung that presents nothing of ours.** There is no sheet, no card, no copy, no
  "Enjoying Red Moon?" — the system dialog is the entire surface.

It is raised from Home's appearance callback, not from a per-action hook, which means in practice it
lands on the walk back from a practice session — the same "calmer moment" argument ADR 0113 already
made for the naming invitation.

### D3 — three ways to waste the ask, and the guard against each

`requestReview()` spends part of a budget whether or not anything is drawn, and the app is never told
which happened (D5). So an ask raised underneath something else is gone, silently, for a year. The
plan takes a `screenIsSettled` flag, and the caller computes it from three hazards:

1. **Not the launch appearance.** A cold launch is the player arriving with something to do; the ask
   waits for the walk back, which is what the CHANGELOG promises ("when you next come back to the
   home screen"). Skipping the first appearance of the process costs one Home return.
   *As written on 2026-09-10 this rule had a second reason: `PaywallHost` raised a once-per-launch
   full-screen wall over Home from the parent, and an ask under it would be spent unseen. ADR 0237
   removed the paywall before this merged; the rule was kept on the first reason alone.*
2. **No reminder landing.** A tapped practice reminder pushes a routine on that very appearance
   (ADR 0186 D6).
3. **Nothing else pushing** — an import's open-on-create, or the library.

**`.onAppear` on the stack root does not re-fire when a cover dismisses**, and this rung depends on
that. A future author who "fixes" it with an `.onChange` would move the ask onto the frame a cover
disappears, which is the one frame it must not be on. That is written into the source beside the
guard, because it is invisible when it breaks.

### D4 — every decision is pure, and the impure half holds one record

`ReviewPromptPlan` (Foundation-only, unit-tested) decides; `ReviewPrompt` (`@MainActor`) does only
what a test cannot. The pattern ADR 0186 D4 established (and ADR 0144 D6's trial reminder had, before
ADR 0237 deleted it), for the reason `PracticeReminderPlan`'s header gives: **every "don't ask this time" case is silent when it
breaks.** A prompt that fires when it should not looks, on screen, exactly like one that should have.

`Hold` is an enum of reasons rather than a `Bool`, so a test asserts *which rule fired*. This is ADR
0186's hardest-won lesson applied before it can bite here: an assertion of the form "the value was
stored" is green against a build that asks on every single appearance.

**The action is passed in, never stored.** `RequestReviewAction` exists only inside a live SwiftUI
environment. The SDK declares it `Sendable`, so the compiler will happily let a service type keep
one — and what it keeps is a handle to an environment since rebuilt. This is ADR 0186 D4's
`usesSystemNotifications` trap in a new costume, and the shape that avoids it is the same: read it in
the view, hand the call down as a closure.

**No `@AppStorage`, anywhere.** One private key owned by `ReviewPrompt`, holding a JSON record, the
way `PracticeReminder.Key` does. `AppSettings` sits sixteen lines under the
file cap and does not need three more — and because no view declares an `@AppStorage` for this, the
default-literal duplication trap cannot arise at all: there is no second site for a default to drift
into.

### D5 — the app cannot learn whether the prompt appeared, and the whole design admits it

`requestReview()` returns `Void`, synchronously, with no completion and no signal. iOS may draw the
dialog or draw nothing — because its own three-per-year budget is spent, because the player switched
in-app ratings off, because they already rated this version, or for reasons Apple does not publish.
**There is no callback, now or later.**

So the only honest fact available is *the app asked*, and that is the only fact stored: a date and a
version, named `Ask`. Never `shown`, never `dismissed`, never a rating.

Three consequences, all encoded rather than promised:

- **The record is written before the call**, not after — it is a fact about our own action, produced
  by the code that takes it, and a crash inside the system call cannot then leave us able to ask
  twice.
- **The analytics event is `review_requested`**, not `review_prompt_shown` (D7).
- **No rule may ever branch on the outcome**, because there is no input from which such a rule could
  be written. A future "they didn't rate, ask again" is not merely unwise here; it is
  unimplementable, and the naming is what makes that obvious to whoever tries.

### D6 — our gates are stricter than Apple's, so Apple's are never approached

At most **one ask per marketing version**, and at most **one per 180 days**. Both must pass, so a
version bump alone reopens nothing — a normal release train never re-asks at all.

This is deliberately *not* Apple's own sample, which re-opens the ask whenever the version changes.
Here the version gate does the opposite job: it stops a *second* ask under a build we already asked
under.

**Apple's three-per-365 budget is not modelled**, and must not be. Modelling it would mean counting
prompts *shown* — unknowable per D5 — and the count would drift from the truth in a direction we
could never detect. Every gate above binds first, so theirs stays a net we never reach. There is no
`asksThisYear` counter and there should never be one.

Degrading is conservative in both directions that matter: a clock moved backwards holds, and an
unreadable `CFBundleShortVersionString` stores `""` and holds forever. An ask that never happens is
invisible; a repeat is not.

### D7 — one event, named for what the app did

`review_requested(trigger:)`, sent by `ReviewPrompt` itself — the *presenter* owns its event, and no
gate call site knows about analytics.

`ReviewTrigger` has **one case**, `sittings`, and that is the whole vocabulary. The Settings row (D8)
is a `Link` that leaves the app and reports nothing, so there is no `settingsRow` case — for exactly
the reason `PracticeSource` has no `planner` case: a case that can never be emitted is a dashboard
category permanently at zero, which reads as a broken funnel rather than an absent one. The axis
exists so a second trigger is additive to the wire format rather than a break in it.

The vocabulary is now **fifteen** events, pinned in `AnalyticsEventTests` (nineteen when this was
written; ADR 0237 retired the four paywall events before it merged).

### D8 — the permanent door is a URL, and it is a different mechanism on purpose

A `Rate Red Moon` row in **Settings ▸ Help & About**, between `Diagnostics` and the two legal links,
opening `https://apps.apple.com/app/id…?action=write-review`.

It is **not** a second `requestReview()`, for two independent reasons and either would be enough:

- App Store Review Guideline 1.1.7 forbids wiring that API to a control the player taps to rate.
- It would silently do nothing once the budget is spent. A row that does nothing when tapped is a
  bug, and an unfalsifiable one — nobody could tell it from a working row on a fresh device.

This is also what makes D9's rejection affordable: a player who wants to rate on their own schedule
has a permanent door, so the ask never has to work hard.

**The hub does not grow.** This is a row inside `AboutSection`, not an eleventh `SettingsHubRow`, so
`check-manual.py` C1's count is untouched. **C9 is engaged and is the deal**: `docs/manual/` may
write `` `Rate Red Moon` `` only because that exact string ships in the source, and a future reword
that skips the page fails the build.

### D9 — no pre-prompt, and no filtering

Rejected: the "Enjoying Red Moon?" dialog that asks first, sends happy players to the App Store and
unhappy ones to ADR 0161's contact form.

It is the most common pattern in the category and it is the wrong one here twice over. Routing
negative sentiment away from the App Store is what Guideline 1.1.7 objects to, and apps have been
rejected for it. And separately, on this product's own terms: a custom dialog can promise a rating
sheet that iOS then declines to show, so the app would be making a claim about the next screen it has
no way to keep.

One call, no copy, nothing to be spammy with.

## Alternatives considered

**Ask on the session-complete screen.** Rejected. It is where every playbook says to ask, and
`RoutinePlayerView+Finished.swift` wrote down before this ADR existed that its composer *"asks an
open question rather than fishing for a rating"*. Putting the ask there would also collide with the
session journal note (ADR 0143, ADR 0198), turning a moment for the player's own words into a moment
about us.

**Ask mid-practice**, on a tempo climb completing or a loop being saved. Rejected. Closest to the
value moment, and the most transactional reading available: it converts a thing the player did for
themselves into a bill.

**An hour milestone** (`PracticeProgress.hourMilestones` — 10, 50, 100, 500). Genuinely considered,
and the strongest *signal* of the three: ADR-blessed already as "a wall you pass rather than a ladder
you're being timed on". Rejected on reach — ten hours is far enough out that most players who would
happily rate the app never get asked. Kept as the obvious second trigger if `review_requested` volume
says five sittings is too early.

**A pre-prompt / sentiment gate.** Rejected per D9.

**A badge, a nag, or a re-ask after a dismissal.** Rejected, and mostly impossible: per D5 the app
cannot detect a dismissal, so there is nothing to re-ask *from*. ADR 0186 D2 already rejected the
badge on its own terms.

**Absence-triggered** — asking players who have gone quiet, or asking harder when engagement drops.
Rejected outright, and it is the alternative this ADR exists to close. It is ADR 0186's whole subject
one surface further out.

**A custom in-app rating UI** that writes to our own backend. Rejected: `infrastructure/` is empty,
ADR 0113 keeps the app account-free, and a private rating we collect and act on is a feedback channel
wearing a review prompt's clothes. The contact form already exists for players who want to say
something.

## Consequences

**Nothing here is proven by a green test run, and the gap is wider than usual.** The suite proves
what the app *decided*; no test anywhere — unit, UI, or otherwise — can observe whether iOS drew the
dialog, because the process is never told. `ReviewPromptPlanTests` and `ReviewPromptTests` carry
every assertion, including one (`testTheCountIsNotEvenReadWhenACheaperGateFails`) that fails against
a build which evaluates the sitting count eagerly, which is the failure a storage assertion cannot
see.

**The prompt never appears on a TestFlight build.** Anyone verifying there will see nothing and
conclude wrongly. Verification is a Simulator or a debug device build, and `Settings ▸ Developer ▸
Reset review ask` is there so it can be exercised more than once — noting that iOS's own budget sits
on top of ours and may still decline. Above it, the same section shows what the dialog cannot: the
sittings counted, the last ask recorded (date and version), and what the next settled Home return
would decide. Since the system call returns nothing, a record that appears there after a return to
Home is the only evidence that our half ran.

**The numeric App Store ID** is not derivable from the bundle id and is recorded nowhere else in
this repo — `fastlane/Appfile` carries only `app_identifier`. It shipped on the 318 branch as a
digits-shaped placeholder; the owner supplied the real one (`6789618726`) when this was ported on
2026-10-01. It cannot be confirmed before release — Apple's public lookup returns nothing for an
unreleased app — so the first real check is tapping **Rate Red Moon** on a store build.

**`AnalyticsEvent.swift` is 349 lines of a 400 cap** (it was 390 when this was written; ADR 0237's
retired events took the rest). No split is owed yet.

**`HomeView`'s `showingLibrary` and `openingSong` became internal** so `screenIsSettled` can read
them. Same convention the file already follows for `openingRoutine` and `showingMetronome`, and the
same small cost: state that was private to one file is now visible to its extensions.

**The analytics denominator is the consenting subset**, as it is for every other event (ADR 0120 /
0147). `review_requested` counts asks among players who opted in, and is directional rather than a
census. It is worth watching for exactly one thing: whether five sittings is reached often enough to
matter, which is the number D1 would revisit.

**Docs that moved with this:** `CHANGELOG.md`, `PROJECT.md`, `docs/architecture.md`,
`docs/manual/reference/settings.md`. `docs/design-brief.md` needed no change — no token, no
screen-inventory entry — though the copy was checked against §3.5, and `Rate Red Moon` states an
action rather than passing a verdict.
