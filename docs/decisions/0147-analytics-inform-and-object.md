# ADR 0147 — analytics moves from opt-in to inform-and-object, and the region decides which

- **Status:** Accepted
- **Date:** 2026-08-06 (`pocket-238-analytics-inform-and-object`)
- **Supersedes in part:** ADR 0120 §2 (opt-in, defaulting to off) and §3 (the ask comes after a first
  practice). **§1, §4, §5, §6 and §7 stand unchanged** — Tier 3 is still closed permanently, the
  vocabulary is still closed and lint-enforced, Aptabase EU is still the processor, the write-only
  key carve-out is still narrow, and there is still no off-the-grid mode.
- **Extends:** ADR 0092 ("your playing never leaves your device" is load-bearing there too)

## Context

ADR 0120 shipped analytics **off by default**, asked for as the last rung of the first-run ladder
after a first practice. It also recorded, plainly, what that costs: *"at typical consent rates,
absolute numbers become meaningless. Only ratios survive."* And it accepted a second cost — that the
intake flow and the first session are **permanently unmeasurable**, because nothing may be buffered
before consent.

Those were the right calls on the law as 0120 read it. The law has since been read again, and one
half of it has actually moved.

**The obvious argument for opting out is not the one being made here, and proposing it would repeat
an argument this repo has already rejected in writing.** ADR 0120 §2 anticipated "but Aptabase is
anonymous" and conceded it outright — *"Aptabase says so, and it is right"* — then explained why it
doesn't help: the binding test is not GDPR but **ePrivacy Article 5(3) / PECR regulation 6**, which
governs storing or accessing information on a user's terminal equipment *irrespective of whether that
information is personal*. Anonymity was never what would unlock opt-out. Anyone reopening this on
anonymity grounds should read 0120 §2 first and stop there.

**What changed is UK statute.** The Data (Use and Access) Act 2025, **Schedule A1 paragraph 5**, in
force **5 February 2026**, creates an exception to PECR regulation 6 for **first-party analytics used
solely for statistical purposes to improve the service**. The ICO's final guidance landed **29 April
2026**. The exception is conditional, not general — it requires **clear and comprehensive information**
about the purpose, and a **simple, free means of objecting**.

ADR 0120 is dated 2026-07-29 — written three months *after* that guidance — and does not mention it.
This is a gap in 0120, not a change of appetite.

Pocket fits the exception's shape closely: first-party, a closed thirteen-event vocabulary that
carries no strings by construction (0120 §4), Aptabase EU as processor, no ad tech anywhere, and
IDFA/ATT ruled out permanently rather than merely unbuilt (0120 §1).

**The EU has not moved.** Article 5(3) still requires consent. The Digital Omnibus proposes an
Article 88a audience-measurement exception of much the same shape, but it is a *proposal* carrying a
critical joint EDPB/EDPS opinion (February 2026). Building to a proposal would be building to
something that may not arrive in that form.

None of this is legal advice, and 0120's standing recommendation holds unchanged: **a professional
check is cheap and worth doing before there is any real scale.**

## Decision

### 1. Two consent models, chosen by region — not one global flip

```swift
enum ConsentModel {
    case ask     // EEA (+CH): ePrivacy Art 5(3) — explicit consent, default OFF
    case notify  // UK + rest of world: DUAA Sch A1 para 5 — inform + object, default ON
}
```

`AnalyticsPolicy.consentModel(regionCode:)` is the single pure rule, and it decides **only the
default**. It never decides whether an event may be sent — that stays one early return in
`Analytics.send`, re-read on every event, exactly as 0120 built it. None of the 25 call sites move,
and `shouldEmit(consentGranted:isUITesting:isPreview:)` keeps its signature and its body. Only its
doc comment changes, because "consent granted" now means "enabled, however that value arrived".

Three details in the region set that are easy to get wrong:

- **The UK is not in the EEA.** `GB` needs no special case; it falls through to `.notify` naturally.
  Writing a `GB` branch would imply the EEA set contains it, which is the actual error.
- **`nil` → `.ask`.** An unknown location takes the stricter path. This is the only safe direction for
  a default to fail in.
- **Switzerland is included in `.ask`** although it sits outside ePrivacy. The inclusion is cheap and
  conservative, and CH is routinely treated alongside the EEA in privacy tooling.

The region comes from `Locale.current.region?.identifier` — good-faith and conventional. It is not a
location claim and is not verified; a player who moves is not tracked. StoreKit storefront is a
possible later refinement if there is ever a reason to want one.

### 2. The disclosure lives in the intake, where "Skip" cannot escape it

Under `.notify`, a one-line footnote sits **between the step content and the bottom bar** of
`ArtistIntakeView`, so it is visible on all four steps — critically step 0, which is where **Skip**
exits. A disclosure a user can leave without seeing is not "clear and comprehensive information", and
the exception is conditional on that phrase.

> Red Moon counts which features get used, anonymously — never your playing. Turn it off any time in
> Settings ▸ Privacy.

**This reclaims what 0120 §3 accepted as permanently lost.** Counting now starts at install, so the
intake flow and the first session become measurable — which is the question analytics was built to
answer ("does a cold install reach a first practice") and the one thing 0120 could not observe.

Note the inversion this performs on 0120 §3's reasoning. 0120 rejected a fifth intake step because
*"putting another screen in front of that flow would tax the exact metric it is there to observe"*.
That objection was to a **screen with a decision in it**. A footnote asks nothing, blocks nothing and
adds no step, so the objection does not carry over. The rejection of a fifth *step* still stands.

### 3. The default is seeded on first launch, because three defaults cannot be kept in agreement

`analyticsEnabled` currently has **three separate `false` defaults** that must agree, with no
compiler help: the `AppSettings` accessor, and two views that each declare their own
`@AppStorage(...) = false`. Flipping the accessor alone would render an **OFF toggle to a user who is
actually ON** — the privacy control lying about the privacy state, which is worse than either value.

Rather than coordinate three defaults, remove the problem: `seedAnalyticsDefaultIfNeeded(model:)`
writes the key explicitly on first launch — the same idiom as the neighbouring
`recordInstallDateIfNeeded`. After it runs the key is always present, so **no `default:` anywhere is
load-bearing**, and any that remain are unreachable rather than wrong.

Migration then falls out for free, including the case that matters most:

| Existing state | Behaviour |
|---|---|
| Tapped "Count me in" | key present `true` → seed no-ops → stays on |
| Tapped "No thanks" | key present `false` → seed no-ops → **stays off, permanently** |
| Never asked (key absent) | seeded per region |

**An explicit decline under 0120 survives this change forever.** Nobody who said no is re-enrolled by
a default. That is the property the seeding approach buys, and it is why the no-op must be tested in
*both* directions rather than only the `true` one.

`analyticsPromptSeen` is renamed `analyticsDisclosureSeen`, since it now covers having been *told*,
not only *asked*. **The UserDefaults key string stays `"analyticsPromptSeen"`** so no data migration
is owed.

### 4. The consent sheet gains a mode, and the anti-nudge rule gets stricter, not looser

`AnalyticsConsentSheet` takes a `mode: ConsentModel`.

- **`.ask`** — today's screen, verbatim. **No behavioural change for EEA users at all.**
- **`.notify`** — a **catch-up for pre-existing installs only**, i.e. players who passed the intake
  before this build and so never saw the footnote. The headline becomes a statement rather than a
  question, the primary action is "Got it", and the secondary is "Turn this off", writing
  `analyticsEnabled = false`. A fresh install never sees it, because the footnote already did the job.

0120 §3's rule — declining is a **full-width, equally reachable target** — applies here with *more*
force, not less. When the default is off, a nudge costs you a data point. When the default is on, a
nudge is the difference between informing someone and processing them without their noticing. The
`.notify` secondary is therefore held to the same weight as the primary.

### 5. The soft edge, recorded rather than hidden

The DUAA exception is for statistics **to improve the service**. Five of the vocabulary's events —
the paywall and purchase ones, now five rather than four since ADR 0144 added `PaywallTrigger.launch`
— read more "commercial" than "service improvement" under a strict purpose-limited reading.

**Accepted, with the reasoning stated so a reviewer can disagree with it cleanly:** what these events
measure is whether the paywall *obstructs* — which gate is reached, and how often reaching it ends
the session. That is a question about whether the product works, and the answer changes the product.
No purchase amount, no identifier and no attribution is involved; ADR 0120 §1 already closed Tier 3
permanently.

**The fallback if a professional check disagrees is to exclude those five events under `.notify`**,
not to abandon the model. It is a five-line change to the vocabulary's emit sites, and recording it
here means the option stays open instead of being rediscovered under pressure.

## Alternatives rejected

**Flip globally to opt-out.** Simplest to build and wrong on the law: ePrivacy Article 5(3) still
binds the EEA, and the Digital Omnibus's Article 88a is a proposal with a critical EDPB/EDPS opinion
behind it. Shipping to a proposal would mean shipping a compliance position that may need withdrawing
— on the one axis where the product's public claim lives.

**Wait for Article 88a and keep one global model.** This forfeits UK and rest-of-world measurement for
an unknown period, in exchange for avoiding one pure function and one branch in a sheet. The split is
cheap; the waiting is not.

**Flip the `AppSettings` accessor's default and update the two views to match.** Rejected in §3: three
defaults that must agree with no compiler help, where the failure mode is a Privacy toggle displaying
the opposite of the truth.

**Keep asking, but ask earlier.** Would recover the install-to-first-practice measurement without any
legal argument — and would tax the metric it exists to observe, which is precisely what 0120 §3
rejected. A footnote costs the flow nothing; a decision screen costs it exactly what 0120 said.

**Treat this as licence to widen what is collected.** Explicitly not. The exception is conditional on
"solely for statistical purposes to improve the service", so a wider vocabulary would *remove* the
basis this ADR rests on. 0120 §4's closed vocabulary and its SwiftLint rule are load-bearing for
0147, not merely inherited by it.

## Consequences

- **The public claim changes again, and the same artefacts must move together** — `docs/privacy-policy.md`,
  `docs/site/redmoon-privacy.html`, `docs/app-store-listing-copy.md`. "Opt-in and off by default" is
  no longer true globally and must not be stated unqualified anywhere. The durable claim —
  **"your playing never leaves your device"** — is unchanged and remains the one to lead with.
- **`PrivacyInfo.xcprivacy` and the ASC nutrition label need no change.** They encode collection type,
  linkage and tracking. None of those move; only the lawful basis and the default do.
- **Two site pages were already wrong under 0120 and are fixed here:** `docs/site/support.html`
  ("Nothing is sent to us") and `docs/site/index.html` ("no tracking"). Pre-existing rot, not caused
  by this change, but it would be indefensible to leave standing while editing the neighbouring
  privacy text.
- **Numbers become readable for the first time.** 0120 accepted that only ratios survive; under
  `.notify` the absolute counts are meaningful for UK and rest-of-world. EEA figures remain
  consent-limited, so **any comparison across the two regions is comparing different denominators** —
  worth remembering before reading a region breakdown as a behavioural difference.
- **The consent rate itself stops being observable** where the default is on, since there is no longer
  an ask to convert. Objection rate is not a substitute: it is a much rarer, differently-motivated act.
- **A player who declined under 0120 stays declined.** Guaranteed by §3's seeding no-op, and pinned by
  a test in both directions.
- **`AnalyticsConsentSheet` now has two roles in one file.** The `.notify` role is transitional — it
  exists for installs predating this build. It becomes dead code once no such install remains, and it
  should be deleted then rather than left as furniture.
- **Unaffected:** ADR 0070 (no grading — the vocabulary still carries no mastery, tempo or accuracy),
  ADR 0092's audio boundary, ADR 0144's entitlement logic, and ADR 0120 §1's permanent closure of
  Tier 3. Nothing here widens *what* is collected; it changes only the default and where the
  disclosure sits.
