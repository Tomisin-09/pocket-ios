# 0113 — Local artist profile: an identity, not a data grab; the home greeting is the payoff

- **Status:** Accepted
- **Date:** 2026-07-23 (`pocket-185-artist-profile-adr`)
- **Builds on:** ADR 0070 (Pocket never grades the player — the player is the judge). ADR 0112 (freemium; the planner / "Today's session" is the Pro curation surface). ADR 0102 (Home grouped sections — where the greeting lives). ADR 0092 (AI is an additive layer; a declared profile is the curated context a future Oracle can read).
- **Reverses:** the earlier "no user profiles" stance (profiles were dropped when accounts were dropped; this brings them back **without** an account).

## Context

Pocket has no account and, deliberately, no sign-in. But the practice engine — and
especially the V2 planner's "Today's session" (ADR 0112) — has to *infer* everything about
the player from behaviour. It has no declared intent to weight against: what they want to
play, who they want to sound like, how much time they have.

The obvious reference is the onboarding funnel apps like Justin Guitar use: an 8–9 screen
quiz (experience, genre, biggest challenge, commitment, age group, minutes/day) feeding a
"building your personalised plan…" reveal, then a paywall. That funnel is a **conversion
machine**, and its tone is the opposite of this project's: fake scarcity ("before it's
gone!"), unqualified claims ("3× faster\*"), invented social proof ("87% of learners"),
and demographic extraction (age band) that segments the user into a marketing cohort.

We want the *structure* of a short, warm intake — and none of the manipulation or the PII.

The insight that reshapes it: **collect an identity, not attributes.** Instead of asking who
someone *is* (birth year, cohort), hand them who they're *becoming* — an **artist name** they
choose for their musical self. That flips the frame from "student enrolled in a course" to
"artist with a practice," which is exactly this project's ethos (ADR 0070: the player is the
judge; "find music in the mistakes"). A name you chose for your musical self is a small
identity contract, and identity is the strongest habit lever there is. It is also, conveniently,
**not PII** — a pure win at App Store review.

An identity field is only worth asking for if it visibly pays off. Its payoff is the
**home-screen greeting**: a quiet, repeated, near-subliminal reinforcement of the artist frame
every time the app opens. Without the greeting the name is a dead form field; with it, the app
greets you into character.

## Decision

Add a **local, account-free `Profile`** with two jobs, each with its own visible payoff, both
optional and both skippable:

1. **Artist name → identity.** Powers the home greeting. Not PII.
2. **Sound / influences / goal / minutes-per-day → curation.** Declared intent the planner
   (ADR 0112, Pro) weights against — preset ordering, tempo defaults, session emphasis mix.

No demographic questions. No age band. No real name. Nothing leaves the device.

### The profile is local and editable — never a wall

- Stored on-device only (SwiftData). One profile per device; no account, no sync, no backend.
- Lives in **Settings**, fully editable at any time. The intake writes into it; it is not the
  only way to set it.
- **Everything is skippable and defaults gracefully.** A user who skips every question gets a
  fully working app and a warm, name-free greeting. The profile *enriches*; it never gates.

### The first-launch intake — four questions, each wired to a consumer

Skippable, one question per card, Red Moon tone, no demographics, no urgency, no paywall. Each maps
to a named consumer so no field is theatre:

1. **"Where are you with the guitar?"** *(→ planner starting difficulty)* — Just starting · Know a
   few chords · Comfortable, want to level up · Been playing a while. Self-rated, no judgement (ADR 0070).
2. **"What do you want to play?"** *(→ preset ordering + planner emphasis)* — multi-select genre
   chips: Rock · Blues · Pop · Folk/Acoustic · Jazz · Funk/Soul · R&B/Neo-soul · Metal · Singer-songwriter.
3. **"What's the dream?"** *(→ emphasis mix)* — Play songs I love · Write my own music · Get properly
   good · Just unwind.
4. **"How long most days?"** *(→ session length + tempo defaults)* — 10–15 min · ~30 min · 45+ min ·
   It varies.

**Deferred: specific-artist free text** ("Hendrix, Mayer"). Richer, but nothing consumes it today —
it is a natural future **Oracle** input (ADR 0092), so it is not collected now rather than shipped as
a dead field. (It could later also seed the name generator; see below.)

### Offer the name *after* a first session, not at the door

The intake does **not** demand an artist name on first launch. Cold "pick your artist name" is
homework and stalls the blank-page crowd. Instead:

- First launch: at most a **3–4 question**, skippable intake for the *curation* fields
  (experience, what they want to play / influences, goal, minutes-per-day) — the planner inputs.
  Short, warm, one question per card, no urgency, no reveal-theatre, no paywall.
- The **artist name is offered later** — after the player has completed a first session — framed
  as something earned ("you've put in a session — what should we call you?"), not demanded. It can
  also be set any time from Settings. "You've earned a name" lands where "give us a name" repels.

### The name is *generated*, not demanded (an artist-name generator)

The strongest way to kill blank-page friction is to **offer a name rather than ask for one** — in
the lineage of the Wu-Tang Name Generator that famously handed Donald Glover "Childish Gambino."
Being present at the naming is a small ritual, and it fits the Red Moon myth. So the
after-first-session moment presents a **generated artist name** the player can:

- **Accept** it, **reroll** for another, or **override** with their own free text — and change it
  any time in Settings. The generator is a *spark, never an imposition*; free-typing is always one
  tap away for people who arrive with a name.

**Decided shape:**

- **Mixed patterns.** A small set of weighted patterns — mostly evocative two-word combos with the
  occasional single strong word (e.g. *Vega · Velvet Wolf · Ember · Midnight Ash · Hollow Moon*).
  Widest range, lowest cringe risk vs. a single fixed template.
- **Deterministic, then random.** The **first** offered name is seeded from the player's intake
  answers so it feels fated / *theirs*; **reroll** spins randomly from there. If the intake was
  skipped, it falls back to a device seed — so a name is always on offer.

Guardrails that keep it on-brand and safe:

- **Curation is the whole game.** Small, hand-picked, evocative word pools in the **Red Moon
  register** — mythic, dusk-lit, cinematic — **not** the jokey Wu-Tang register. A tight curated
  pool beats a huge random one.
- **Safe by construction.** Curated pools **plus a blocklist** so no combination lands somewhere
  offensive or unfortunate — a name generator that ships a bad combo on day one is a real risk.
- **Local, deterministic, pure.** `seed → name` is a pure, **unit-tested** selection over curated
  data. No network, no PII, no external service; the pools are just data the team curates.

**Phasing — the generator is deferrable.** It is *not* on the critical path for the Profile
feature. Profile v1 ships with the artist name as a **plain free-typed field** plus the greeting;
the after-first-session moment starts as a simple "what should we call you?" prompt. The generator
is a **later slice** that upgrades that prompt from a blank field to an offered name — the greeting
is indifferent to whether the name was typed or generated, so nothing downstream waits on it.

### The greeting contract (tone is the whole point)

The greeting is where the name is redeemed, so it carries Red Moon's register, not the funnel's:

- **With a name:** a single quiet line — e.g. *"Evening, Vega."* Time-of-day aware, cinematic,
  dusk-lit, restrained.
- **Without a name:** an equally warm, name-free line — never a nag to set one, never a blank
  "Hello, ." The name-free state is a first-class design, not a degraded one.
- **Tone rules:** one line; no exclamation marks; no "Rockstar mode 🚀🔥" register; no streak
  guilt; Futura + design tokens; theme-aware. Quiet beats loud.

### What the curation fields actually change (no theatre)

A profile that collects influences and then changes nothing is theatre. Before build, the
profile must have **named consumers**. The first, concrete ones:

- **Preset / exercise ordering:** surface presets that match declared influences & experience first.
- **Tempo defaults & session length:** seed from minutes-per-day and level.
- **Planner emphasis mix (Pro, ADR 0112):** the "Today's session" generator weights toward the
  declared goal and genres. This is the profile's strongest consumer and the main reason to build it.

If a field has no consumer, it does not ship.

### Implementation shape

- **`Profile` — a single local SwiftData `@Model`.** One row. Fields: `artistName: String?`,
  plus the curation fields.
- **Heed the enum-attr migration crash.** Do **not** store the taste/goal/experience enums
  directly on the `@Model` — back each with a primitive (raw `String`/`Int`) + a computed enum
  accessor. In-memory tests pass with stored enums; the device traps on migration. (Known gotcha;
  see `docs/swiftdata-gotchas.md`.)
- **Pure profile logic stays pure** (per the pure-logic rule): the greeting selection
  (time-of-day → line, name / no-name branch), the **artist-name generator** (`seed → name` over
  curated pools + blocklist), and any profile→ordering weighting are UI-free and **unit-tested**.
  Tempo/planner-weighting math already lives behind the pure boundary; the profile feeds it, it
  does not import SwiftUI.
- **Greeting reads the profile via `Environment`;** name-free fallback is the default path, not an
  edge case.
- **No AI, no network.** A future Oracle (ADR 0092) may read the profile as curated context, but
  that is out of scope here and the profile never leaves the device without an explicit, later,
  opt-in decision of its own.

### Build phasing (slices)

Sequenced so each slice ships something whole and nothing waits on a later one:

- **Slice 1 — identity core.** `Profile` model + Settings editor + **free-typed artist name** + the
  **home greeting** (name line + name-free fallback) + the after-first-session "what should we call
  you?" prompt. Emotionally the richest half, cheapest to build, no dependency on the planner.
- **Slice 2 — intake + first consumers.** The 4-question skippable intake writing the curation
  fields, wired to **preset/exercise ordering + tempo/session defaults** (consumers that exist
  today).
- **Slice 3 — planner emphasis.** Wire the curation fields into the "Today's session" emphasis mix
  — lands **with / after** the Pro planner (ADR 0112), its strongest consumer.
- **Slice 4 — name generator.** Upgrade the naming prompt from a blank field to an **offered name**
  (mixed patterns, deterministic-then-random, curated pools + blocklist). Pure add-on; deferrable.

## Consequences

- Pocket gains declared intent for curation **without** an account, a login screen, a backend, or
  any PII — so no new App Privacy burden at review.
- The planner (ADR 0112, Pro) gets a real seed instead of pure inference; this is the feature's
  main justification and its strongest consumer.
- The home greeting becomes a small, daily identity reinforcement — the intangible that makes the
  artist frame stick — at the cost of a tone the team must hold the line on.
- Reverses "no profiles," but only the **local, no-account** shape — accounts remain off the table.
- Still never grades the player (ADR 0070): the profile records who they want to be and what they
  want to play, never how well they played.
- One-profile-per-device / no cross-device sync is an accepted limitation while there is no backend;
  revisitable if accounts ever return.

## Alternatives considered

- **The Justin-style demographic funnel** (age band, "biggest challenge," commitment quiz, plan
  reveal, paywall). Rejected — its tone and manipulation are off-brand, age/PII adds review burden,
  and cohort segmentation serves marketing, not the player.
- **Real name / personal info in the profile.** Rejected — PII with no upside; the artist name does
  the identity job better and collects nothing sensitive.
- **Demand the artist name on first launch.** Rejected — blank-page friction; "earned after a
  session" converts better and respects the "pick it up and play" promise.
- **A required intake wall before the app is usable.** Rejected — contradicts the play-first promise;
  the intake is short, skippable, and enriching, never gating.
- **Skip the greeting, keep the name as a stored field.** Rejected — with no visible payoff the name
  is a dead field; the greeting is what makes it worth asking for.
- **Cloud profile / account.** Out of scope — accounts were deliberately dropped; sync needs a
  backend Pocket does not have and does not want yet.
