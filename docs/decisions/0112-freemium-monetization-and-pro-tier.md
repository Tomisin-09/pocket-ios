# 0112 — Freemium monetization: free play-along tools, a flat Pro tier, and a future Oracle tier

- **Status:** Accepted
- **Date:** 2026-07-23 (`pocket-182-monetization-adr`)
- **Builds on:** ADR 0092 (AI = the paid lever, not storage; local fallback; opt-in). ADR 0069 (recording feature; its monetization was parked). ADR 0070 (Pocket never grades the player — holds at every tier).

## Context

v1 ships **Free** and is mid-submission. We want a sustainable monetization path for a
later build without betraying the project's "honour the craft" ethos.

Two earlier ideas were tried and set aside:

- **Recording as the paywall** (ADR 0069). Rejected — recording/takes is a nice-to-have with
  near-zero marginal cost; gating it reads as stingy and isn't enough incentive to convert.
- **Match Justin Guitar's ~£11/mo outright.** Justin sells a *curriculum* that partly replaces a
  teacher; Pocket is a *practice instrument*. Same price without the same value basis invites the
  wrong comparison. The £11 stays an anchor, not a target.

The insight that resolved it: the line that maps cleanly onto Pocket is **play-along tools vs. the
structured-practice system**. The exercises + routines *are* Pocket's curriculum layer — the deep
IP (ADRs 0083–0091, 0101–0109) — and, unlike AI, they cost nothing at the margin, so unlimited
access is safe to sell flat.

## Decision

**Three tiers.** Only the first two get built now; the third waits for AI to exist.

### Free forever — play-along tools
Metronome, songs/library, loops, journal, **takes/recording**, and **all strumming exercises**.
Plus a **permanent taste** of the paid layer: a curated set of **seeded preset exercises** a free
user can *run* — the low-E minor-pentatonic box, an open-chord set, **picking warm-up, and legato** —
and **one curated starter routine** they can run forever (**Morning Warm-up**). The taste is the hook
— a free user *experiences* the structured layer, hits its edge, and converts. It never expires with
the trial.

> **Amended 2026-07-28 (`pocket-191`).** This previously read "the ability to build **one** manual
> routine from free exercises". **Routines are now Pro outright**, with a single curated routine
> runnable (not editable) for free. The count-based allowance was dropped as unbuildable-without-
> ambiguity: it needed a rule for *which* routine was the free one, and an answer for what happens to
> the other nine when a trial lapses. A flat rule needs neither. The run-only allowance also **closes
> a bypass** — see §Consequences.

**The free line is running, not authoring.** Free users can *run* the curated presets (including
picking warm-up and legato), but **authoring is Pro** — both *creating a new exercise from a Pro
template* and the **"draw your own" custom fretboard canvas**, even within a family whose presets are
free to run. Nudging tempo on a preset is free; building your own technique content is not.

### Red Moon Pro — flat price, zero marginal cost
The full exercise catalog (all scales — modes/positions/CAGED; all chords — movable + custom
placer), **unlimited** custom exercises & routines (including "draw your own"), and the deterministic
**"Today's session"** self-rated planner. No per-use cost, so unlimited is safe.

**Price: £5.99/mo, or £49.99/yr** (annual ≈ £4.17/mo, ~30% off — the retention lever this category
lives on; lead with annual in the paywall). *(Set to £5.99/£49.99 before launch, 2026-07-24 — up from
the initially-proposed £4.99/£39.99.)* Deliberately **below** Justin Guitar's ~£11/mo: Red Moon
Pro is a practice *workbench*, not a curriculum, and a modest Pro price leaves clean headroom for
**Oracle** (~£10–12) to be the premium AI tier where the Justin-comparable price fits. No lifetime
option — it undercuts recurring revenue and the future Oracle upsell. Reversible: raise later and
grandfather existing subscribers.

### Red Moon Oracle — *future tier, built only after AI ships*
AI-generated "today's session" and other AI features, **with usage caps** to protect margin (per
ADR 0092). We **do not build a two-tier AI split until the AI exists** — no paywall for a phase-4
feature.

### Trial + post-trial mechanics
- **14-day free trial** of full Pro, via a **StoreKit 2 intro offer** (14 days free → auto-renews
  unless cancelled), triggered when the user taps into a Pro surface — not silently at install.
- **The free taste is permanent** regardless of trial state.
- **When the trial lapses without subscribing:** Free stays fully available; **any exercise built on
  a paid template locks — including the user's *own* custom exercises made from Pro templates**; the
  planner locks entirely. **Nothing is deleted** — subscribing re-unlocks everything instantly.
  Locked items stay visible, badged Pro, paywalled on open.

### Sequencing & platform
- The paywall ships in a **later build, not v1.** v1 remains Free.
- **Grandfather** (or long-trial) anyone who had the app before the paywall — early believers are
  marketing, not lost revenue.
- Enrol in Apple's **Small Business Program** (cut = 15%, not 30%). Implement with **StoreKit 2**
  (`Transaction.currentEntitlements`, restore-purchases, receipt validation).

### Implementation shape

Greenfield — no StoreKit or entitlement layer exists yet (only `Pocket.entitlements`, unrelated
app capabilities). The design:

- **Gate at read time, not write time.** Access is computed live from one `isPro` flag; nothing
  about Pro is persisted on the exercise. This is what makes trial-lapse re-lock free — `isPro` flips
  to `false` and every Pro-gated exercise + draw-your-own path re-locks with no migration, instant
  re-unlock on subscribe.
- **One entitlement source of truth** — a `StoreManager` (`@Observable`, StoreKit 2) exposing
  `isPro`, backed by `Transaction.currentEntitlements` + a `Transaction.updates` listener, injected
  via `Environment`. The only type that knows about purchases.
- **Two pure, unit-tested axes** (no SwiftUI/StoreKit, per the pure-logic rule): a `tier` switch on
  `ExerciseTemplate` (free = basic/strumming/warm-up; Pro = the rest) governing *authoring*, and a
  free-preset allowlist letting free users *run* the curated taste (picking warm-up, legato,
  pentatonic box, open chords) even from Pro families.
- **Gate at the UI seams**, all routed through one `.paywall(trigger:)` modifier: the "draw your
  own" canvas (`ExerciseShapeSheet` / `FretboardDrillEditor`), create-new-from-a-Pro-template
  (`NewExerciseSheet`), opening a Pro-authored library exercise, and the planner.
- **The 14-day trial is an App Store Connect intro offer** on both products — no app-side trial
  logic; StoreKit reports the customer as entitled during the free period.

### Paywall in practice (runtime UX)

- **Entitlement at launch:** `StoreManager` resolves `Transaction.currentEntitlements` and subscribes
  to `Transaction.updates`, publishing `isPro`; StoreKit serves the cached entitlement **offline**, so
  there is no spinner and no network dependency to use the app.
- **Locked, not hidden:** Pro surfaces stay visible with a lock / "Pro" badge (library rows, the
  "draw your own" button, the planner entry) — inviting, not greyed out. Tapping one presents the
  paywall via a single shared `.paywall(trigger:)` sheet carrying the intent, so the original action
  resumes after purchase.
- **The paywall screen** (one `PaywallView`, Futura + design tokens, theme-aware): value prop; **Annual
  pre-selected** (£49.99/yr, "≈ £4.17/mo · best value") with Monthly (£5.99/mo) beneath; one primary
  CTA; **Restore Purchases**; and the Apple-required disclosure block (auto-renews, price, cancel
  anytime) + Terms/Privacy links — a paywall missing that disclosure is rejected.
- **Trial-aware CTA:** read `product.subscription?.isEligibleForIntroOffer` → first-timers see "Start
  14-day free trial" (then £X), prior users see "Subscribe". No app-side trial bookkeeping.
- **Purchase:** CTA → `product.purchase()` → Apple's native sheet → verify `Transaction` → `isPro`
  flips true → paywall dismisses → the intent proceeds.
- **Restore & manage:** Restore re-scans `currentEntitlements` (`AppStore.sync()` if needed); Settings
  links out to the system *Manage Subscription* screen — no billing UI is built in-app.
- **Post-trial re-lock** falls out of gate-at-read-time: trial lapses → entitlement drops → `isPro`
  false → Pro-authored exercises + draw-your-own re-lock (badged, paywalled on open), nothing deleted.

### App Store Connect setup checklist

*Prerequisites*
- [ ] **Paid Applications agreement** active; **Banking** + **Tax** complete (Business section) — subs
  fail silently otherwise.
- [ ] Enrolled in the **Small Business Program** (15% commission).

*Group & products* (Monetization → Subscriptions)
- [ ] One **subscription group** "Red Moon Pro" — both plans in it (single entitlement; monthly↔annual
  switching).
- [ ] **Red Moon Pro Monthly** — id `click.decooperations.pocket.pro.monthly`, 1 month, **£5.99**.
- [ ] **Red Moon Pro Annual** — id `…pocket.pro.annual`, 1 year, **£49.99**.
- [ ] Rank **Annual above Monthly** (annual = the upgrade); tax category set; price matrix reviewed.

*Trial*
- [ ] **Introductory Offer** on *both* products: type **Free**, duration **2 weeks** (auto-eligibility:
  one per group per Apple ID, first-time only).

*Metadata & review*
- [ ] Localized display name + description per product; group display name.
- [ ] **Paywall review screenshot** + review notes per product.
- [ ] Submitted **attached to the paywall app version** (the later build, not v1).

*Testing*
- [ ] **StoreKit configuration file** for local/offline testing (accelerated renewals → watch the trial
  lapse and confirm re-lock).
- [ ] **Sandbox testers** for on-device end-to-end before submission.

## Consequences

- Free is a genuinely useful app on its own (a serious practice companion), which protects
  App-Store standing and word-of-mouth; Pro is the structured layer that directs practice.
- Entitlement gating is **template-scoped** for exercises: a template carries a free/Pro flag, and
  every exercise inherits its access from it. This is the single mechanism the app must enforce (and
  re-enforce at trial lapse).
- **Routines are gated as a whole, not by inheritance** (amended 2026-07-28). Inheritance was the
  original idea — "a routine inherits its access from the templates it uses" — but it is *unsound* on
  the run side: the routine player embeds the real `ExerciseRunView` per block with no per-block
  check, so a free player could add a Pro drill to a hand-built routine and run it there, bypassing
  the library's per-row lock in three taps. Making routines Pro, with the **one curated free-taste
  routine whose blocks are free-tier or free-taste by construction**, closes that by construction:
  the only routine a free player can ever play is one we control. `RoutinePresetsTests` pins that
  cleanliness so a future edit to the curated recipe can't silently reopen the hole.
- Routines have **five** producers, all of which must gate: the routines library `+`, its
  Quick-session wand, the planner's "Today's session", the Library's collection→session builder
  (ADR 0118), and a song's "Build a routine for this song" (ADR 0111). Two of those live outside the
  Practice space, which is exactly how a gate gets missed — any *new* producer must gate too.
- Recording is now unambiguously **Free**, formally reversing the parked ADR-0069 monetization idea.
- Pro price is set (£5.99/mo · £49.99/yr); only the **Oracle** price stays open — it needs a
  unit-economics model (Claude API cost per call × caps, net of Apple's cut) before it is set.
- No tier ever grades the player (ADR 0070) — the free/paid line is about breadth and automation,
  never judgement.

## Alternatives considered

- **Recording as the paid tier** (ADR 0069). Rejected — low marginal cost, weak incentive, reads as
  stingy.
- **Paid base app à la Justin (£11/mo for everything).** Rejected for a practice tool at this stage:
  invites "but Justin teaches me and this doesn't," and suppresses the free adoption that feeds
  conversion.
- **Free everything, only AI paid.** Rejected — leaves no monetization path until AI ships (phase 4),
  and undersells the exercise/routine IP that already exists.
- **Hard-wall the exercises with no free taste.** Rejected — users bounce before feeling the "aha";
  you can't convert someone who never got hooked.
- **Flat unlimited AI at one price.** Rejected — per-use Claude cost makes flat-unlimited a margin
  risk; Oracle needs caps (ADR 0092).
