# 0117 — Practice stats & the Progress screen: measure effort, never performance; streaks are opt-in

- **Status:** Accepted — **rescoped 2026-07-31** (`pocket-209-session-block-model`), then **amended the same
  day** (`pocket-214-practice-log-progress-screen`) to un-defer the near horizons of the Progress screen. The
  log is built now at a corrected granularity, and it is read by the per-exercise tempo trajectory **and** a
  Progress screen holding This week · This month · All-time. Still deferred: This year, the year-in-review
  card, streaks, the weekly goal, and the `PracticeStatsCard` evolution. See **Scope** below — the rest of
  this ADR stands as the design the deferred parts resume from.
  **Slice 1 built 2026-07-31** (`pocket-214`): the `PracticeRun` log, the pure `PracticeLog` /
  `TempoTrajectory` layer, the write seam (corrected — see *The write seam*), and the per-exercise tempo
  trajectory on `ExerciseDetailSheet`. **Slice 2 built the same day**: `TempoRecord`,
  `PracticeProgress`, and the Progress screen (This week · This month · All-time) — reached from the
  **Journal** toolbar, not the home card, which turned out no longer to exist (see the correction under
  *Scope*). Still deferred: the year tier, the wrapped card, streaks, and the home-summary evolution.
- **Date:** 2026-07-24 (`pocket-195-practice-stats-adr`)
- **Builds on:** ADR 0070 (Pocket never grades the player — no scoring, pitch, timing, or pass/fail). ADR 0102 (Home is grouped sections with a strict "don't add a sixth same-weight peer" rule). ADR 0113 (local, account-free `Profile`; the greeting's tone rules — "no streak guilt"). ADR 0112 (freemium; where a stat might sit behind Pro is called out below). ADR 0092 (a future Oracle may read aggregated effort as context, never as a grade).
- **Supersedes:** nothing. Extends the existing derived `PracticeStats.Summary` / `PracticeStatsCard` (cumulative counts, no persistence) into a full stats surface.

## Context

We want practice stats that keep players coming back — glanceable daily/weekly/monthly/yearly/all-time
measures. Today the app has a **first slice already**: `PracticeStats.Summary` rolls up loops,
exercises, loops mastered, and journal notes, and `PracticeStatsCard` renders them as a "Your progress"
tile row. That slice is **fully derived** — it counts what's already stored and needs no new
persistence, and it hides on an empty library so first launch isn't a wall of zeros.

Two things force a decision before we go further.

**1. There are two fundamentally different kinds of stat, and only one is free.**

- **Inventory / cumulative counts** — loops made, exercises, notes written, loops mastered. Derivable
  today, zero new storage. But they measure *library size*, not effort, and some can **go down** when
  a user deletes an exercise or loop — a demotivating surprise for a "progress" surface.
- **Time-windowed activity** — minutes today, this week's bars, this month's heatmap, yearly hours,
  streaks. **None of this is derivable** from current data, because the app does not log *timestamped
  practice events*. Every "daily/weekly/monthly/yearly" number in the original ask depends on a new
  append-only session log. This is the real engineering work, and it touches SwiftData — which this
  project has a documented set of device-only footguns around (see `docs/swiftdata-gotchas.md`).

Naming this fork up front stops the presentation conversation from quietly hiding a persistence project.

**2. ADR 0070 constrains *which* stats are even legal.** Pocket never grades playing. So every stat
here must measure **showing up and doing the work**, never *how well* it was played. This is a feature,
not a limitation: effort-and-consistency stats are more motivating and less shame-inducing than accuracy
grades, and they can't collapse into discouragement on a bad day. A subtle consequence: tempo is
recorded as a **factual log of what was practiced** ("practiced the A-minor run at 120 BPM"), never as a
score ("you scored 120"). The language stays on the effort side.

## Decision

Add a **timestamped practice-session log** and build a dedicated **Progress screen** on top of it, with
**two presentation tiers**:

1. **Home keeps exactly one glanceable summary row** — the evolved `PracticeStatsCard`, a *promise* —
   which **taps through to** …
2. **A full Progress screen** — the *payoff* — holding This week / This month / This year / All-time,
   plus an **opt-in** streaks section.

All stats measure effort, never performance (ADR 0070). Everything is local; nothing leaves the device.

### Scope

The original scope bundled a persistence project with a five-horizon presentation project. Splitting them
lets the **schema** land before the first external cohort — which is the part that is expensive to change
later, because schema churn costs testers their accumulated history — while the presentation lands when
there is usage to shape it.

The first rescope (`pocket-209`) deferred the presentation entirely. The **amendment** (`pocket-214`) puts
most of it back, split by **horizon** rather than treated as one block. The stated reason to wait was that
the screen's shape should be informed by usage that does not exist yet — but the cohort *is* how that usage
arrives, and a stats surface nobody can see produces no signal about stats. That is the argument this ADR
already accepted one level down, when it refused to ship the log with no surface at all. What survives it is
the **year tier**, which cannot be read before a year has passed no matter who is looking.

**Tracking is not the same as reading.** The log records from the first run either way; deferring the screen
never cost a single row. What un-deferring buys is the **visible payoff** — a retention argument, not a data
one — so the horizons are judged on when they become legible to a new installer, not on when the data exists.

**In scope now:**

- the log `@Model` at the granularity corrected below,
- the pure aggregation layer over `[SessionRecord]` value structs,
- writes at the **natural-completion hook** the run screens already own — `engine.onRampFinished` /
  `model.onFinished` — rather than at the Done screens named when this was drafted (see *The write seam*
  below),
- the **per-exercise tempo trajectory** in `ExerciseProgressSection`, beside the mastery dots and "last
  practised" that already live there,
- a **Progress screen** carrying **This week**, **This month** and **All-time**, reached by making the
  existing `PracticeStatsCard` tappable.

**The entry point is a destination, not the card evolution.** The deferred evolution is re-leading a home
summary with a live number and restructuring the tiles around it — a change to Home's grouped layout
(ADR 0102) that is not worth making twice, once now and once when the year tier lands.

**Corrected during Slice 2's build: the entry point is the Journal toolbar, not the home card.** This ADR
assumed `PracticeStatsCard` was still on Home and needed only a push. It isn't. The "Your progress" strip
was **deliberately removed** in the 2026-07-09 home-hub rework (`a0c754e1`, R1 — *"Dropped the 'Your
progress' stats strip"*), two weeks before this ADR was written, and the file has been dead code ever
since. There was nothing to make tappable.

Progress is therefore reached from the **Journal** space (ADR 0100), which is already the read-only,
cross-cutting practice-history destination — Progress is practice history, so it belongs behind the same
door. This serves the deferral's actual purpose better than the original wording did: Home's grouped
layout is **completely untouched**, so ADR 0102's grouping is churned exactly once, when the year tier and
the card evolution land together. The two-tier design (Home promises, Progress pays off) is not abandoned
— it is what the deferred card evolution will build, on a destination that already exists.

`PracticeStatsCard.swift` is left in place, still unreferenced. Its tiles are re-drawn on the Progress
screen's all-time wall, so it is now superseded rather than merely unused; deleting it is a tidy-up worth
doing when the deferred home-summary evolution is picked up, and this paragraph exists so the next reader
doesn't take its presence as evidence that Home shows stats.

**Deferred (design below stands; build later):** the **This year** section — total hours, longest streak of
the year, month-by-month trend — and the year-in-review **"wrapped"** card, plus the `PracticeStatsCard`
evolution. A year view over five weeks of history is a wall of one month, and wrapped is both the most
re-engaging artefact here and the designated Pro candidate: spending it before there is anyone to re-engage
is the wrong order. This is also where most of the presentation *work* lives.

**Deferred entirely — streaks**, including the opt-in switch, the weekly-goal framing and the streak
freeze. Those mitigations exist to contain a retention lever whose effect cannot be observed with no
users; building them now would be guessing at a problem we have no signal on. The reasoning below is kept
because it is the decision we will resume from, not because it ships now.

**Two elements of the week/month design go with the streaks, not with the charts.** Both re-introduce
habit-pressure through the back door after it was deliberately deferred, so they are held on the same
reasoning:

- **A denominator on days-active.** "4 of 7" states a target of seven. Show the count alone.
- **The week-over-week ▲/▼ delta.** It is the first element in this design that can read as a verdict on a
  bad week. Without it the chart is a mirror; with it, it is a report card the player did not ask for.

Shipping the near horizons without streaks or a goal is deliberate: the week chart describes what happened
and prescribes nothing, which is what ADR 0113's no-guilt rule asks for anyway.

**Why the trajectory is still called out separately.** It is a *unit-level* read the original ADR did not
have — everything on the Progress screen windows at the **session** level. "I played this at 76 in June and
I'm at 104 now" is the motivating artefact, and it needs the corrected granularity to exist at all.

**Empty states are the real design work in this slice, not the charts.** A fresh install has no rows, and the
existing card dodges this by hiding on an empty library. A screen the player can navigate to cannot hide, so
each horizon needs an honest first-week answer — the cohort meets these surfaces at zero, and a wall of
zeroes is the first impression the original derived card was explicitly built to avoid.

### The session log — the foundation everything time-windowed needs

A new append-only SwiftData `@Model`, **one row per unit-run** — not, as originally specified, one row per
completed practice sit:

- `startedAt: Date`, `durationSeconds: Double` (or `endedAt: Date`) — the spine of every time window.
- `kind` — exercise · routine · loop · recording — stored as a **primitive raw `String`**, not a stored
  enum, with a computed accessor. (Heed the enum-attr migration crash: in-memory tests pass with stored
  enums; the device traps on migration. `docs/swiftdata-gotchas.md`.)
- Optional loose references (exercise / routine identifier as a primitive) so a run can attribute
  minutes to *what* was practiced without a hard relationship that complicates migration or deletion.
- Optional `tempoBPM: Int?` — the factual tempo log, for tempo-record surfacing. Not a grade.
- Optional `notesPerBeat: Int?` — the rhythm the tempo was measured in (ADR 0121). A tempo without its
  rhythm is not comparable to another tempo, so a trajectory that ignores it would plot 90 BPM in
  sixteenths against 90 BPM in quarters as "no progress".

**Why per-unit-run.** A sitting is not the thing a player improves at — a *unit* is. One row per sit with a
single `tempoBPM` cannot express a routine of six exercises practised at six different tempos: it collapses
to one row and one number, and the trajectory that motivates the whole feature becomes underivable. One row
per unit-run is strictly more information at the same write cost, and **sittings are derived by grouping
rows on time**, so every session-level stat below still works. Going the other way — starting per-sit and
migrating to per-unit later — would mean asking testers to give up their history.

### The write seam — corrected during Slice 1's build

This ADR originally named **two** write seams: the standalone run's post-run completion offer (ADR 0079)
and the routine player's per-block Done screen. Building it showed those are the wrong place. Both are
*optional* surfaces — the Done screen is skipped entirely when auto-advance is on, never appears at all
for an ear-training block (ADR 0104), and can be left by the back button — so logging there would silently
drop completed practice on three ordinary paths. What it collects (a self-rating, a note, a promote) is
optional; **the minutes are not**.

The log therefore writes at the **natural-completion hook** each run screen already owns, one step
earlier: `engine.onRampFinished` in `ExerciseRunView`, `model.onFinished` in `LoopRunView`. That is *one*
seam rather than two, because a routine block **is** the same run screen with a `RoutineRunContext` — so
the standalone case and the routine case cannot drift apart. The context gained a `routineUID` so a block
still knows what it was practised inside.

The same hook fires only when a ramp runs its full course, which settles a question the original wording
left open: **a run stopped by hand logs nothing.** The log records completed unit-runs, and an aborted run
has no honest length or tempo to claim. A multi-rep block logs one row per rep, which is correct — a rep
is a run.

Design rules for the log:

- **Append-only and cheap.** One insert per completed unit-run. No mutation, no per-tick writes. A routine
  of six blocks writes six rows at its six existing Done seams, not one row at the end.
- **Deletion-safe.** Deleting an exercise must **not** delete its history — the minutes were still
  practised. References are loose (id copies), not cascading relationships, so a stat like "lifetime
  hours" never silently drops when the library is pruned. This is the deliberate opposite of the
  inventory counts' weakness.
- **Aggregation is pure and unit-tested.** All windowing/streak/roll-up math lives behind the pure-logic
  boundary (per AGENTS.md) over plain value structs (`[SessionRecord]`), free of SwiftUI/SwiftData —
  the off-by-one-prone code (day boundaries, week starts, streak breaks, "mastered" thresholds) is
  exactly what breaks silently and so exactly what must be tested. The view runs its `@Query`, maps to
  values, and hands them to the aggregator — mirroring how `PracticeStats.summarize` already works.

### Two tiers of presentation — *partly built, per Scope above*

**Home — one row, no sprawl.** ADR 0102's "don't add a sixth same-weight peer" rule holds: we do **not**
spread five time horizons across the hub. Today Home is **untouched** (see the correction above — the
card it was to have been hung off no longer exists). *Deferred:* a home summary row evolves to:

- lead with the **most motivating live number** (once the log exists: minutes today / this week against
  the player's goal — or the streak *only if they opted in*),
- keep 2–3 supporting tiles,
- be **tappable → pushes the Progress screen.**

Home stays a *promise*; it never becomes the ledger.

**The Progress screen — the full breadth**, sectioned by horizon so the hub stays lean:

- **This week — BUILT.** A 7-day minutes bar chart (the *shape* teaches more than any single number),
  days active as a bare count, and total minutes. Legible on day two. ~~days active "4 of 7"~~ and
  ~~this-week-vs-last-week (▲/▼)~~ are held with the streaks — see Scope.
- **This month — BUILT.** A contribution-style calendar heatmap, best day, tempo records set this month.
  Populates within two or three weeks and is the most legible "am I showing up" artefact in the design;
  it is the same aggregation as the week, bucketed differently.
- **This year — DEFERRED.** Total hours framed big ("You practiced 87 hours this year"), longest streak of
  the year, month-by-month trend, and a **year-in-review / "wrapped"** card (most-practiced exercise,
  favourite instrument, tempo PRs, first-vs-last). The wrapped card is the single most re-engaging /
  shareable artifact here and is worth building well — which is precisely why it waits for a year of data
  and an audience to re-engage.
- **All-time — BUILT, minus the streak row.** Lifetime hours & sessions ("since you started, 6 May 2026")
  and the **cumulative inventory counts as an achievement / milestone wall** (loops made, exercises, journal
  entries written, loops mastered; hours milestones at 10/50/100/500). Meaningful from the second session.
  ~~Longest-ever streak~~ and ~~7/30/100/365-day streak badges~~ ship with streaks. This is where the counts
  the current card shows belong — as *achievements in context*, not as raw peers competing with the practice
  CTA on Home.

**Activity leads, inventory supports.** Effort/activity measures (minutes, sessions, reps, journal
entries *written*, tempo PRs) only ever go up, so they carry the motivation. Inventory counts (how many
loops exist) are secondary texture on the All-time wall, never the headline.

### Streaks are opt-in — off by default — *deferred entirely, per Scope above*

Streaks are a double-edged lever: a broken daily streak triggers loss-aversion guilt and is a known
churn driver, and it clashes head-on with ADR 0113's greeting rule ("no streak guilt"). So:

- **Off by default; the player explicitly turns streaks on** in Settings. A user who never opts in sees
  no streak anywhere — no nag, no dimmed flame, no "you broke it."
- **For those who opt in, ship the mitigations from the start:**
  - a **weekly goal** ("practice 4 days this week") as the default framing, not daily-only, so one
    missed day doesn't nuke months of history;
  - a **streak freeze / rest day** so a single gap is forgiven.
- **Measured against the self, never others.** Consistent with ADR 0113, progress is compared to the
  player's *own* goal and *own* past — never a leaderboard or "87% of learners" cohort. Comparison to
  strangers demotivates most learners and is the funnel tone this project rejects.

### Tone (inherited from ADR 0113)

The Progress surface carries Red Moon's register, not a gamification arcade: quiet copy, no exclamation
marks, no "streak 🔥🚀" theatrics, no guilt for a missed day, Futura + design tokens, theme-aware. A
stat is a mirror the player chose to look into, not a scoreboard shouting at them.

### Where Pro fits (ADR 0112)

Basic stats (this week, all-time counts, the Home row) stay **free** — they reinforce the core habit and
should never be gated. The **year-in-review "wrapped"** card and any richer analytics are natural
**Pro** candidates if we want a paywall touchpoint, but this ADR does not gate anything by default;
the gating line is a monetization decision deferred to when the paywall actually ships.

**Settled 2026-07-31, now that the paywall has shipped (ADR 0112):** the log and Slice 1's tempo trajectory
are **free**. Gating a player's own practice history would put the retention payoff behind the purchase it
is supposed to motivate, and ADR 0112's line is *run, don't author* — history is neither. The "wrapped"
card remains the Pro candidate when it is built.

## Consequences

- The app gains a durable, append-only record of practice effort — the substrate not just for stats but
  for any future planner feedback or Oracle context (ADR 0092), which may read **aggregated effort**,
  never a grade.
- Still never grades the player (ADR 0070): every measure is effort/consistency/volume; tempo is a
  factual log, not a score.
- Home stays lean (ADR 0102): one evolving summary row that promises, one Progress screen that pays off.
- Streaks exist for the players who want them and are invisible to those who don't — the guilt risk is
  opt-in, and mitigated even then.
- New persistence carries the SwiftData migration/deletion footguns; the log is primitive-typed,
  loosely-referenced, and its aggregation is pure and unit-tested to contain them.
- Inventory counts that can decrease are demoted to an achievement wall, so "progress" never appears to
  go backwards when a user prunes their library.
- A one-per-device, no-sync limitation (no backend, no account) applies to history as it does to the
  profile; revisitable only if accounts ever return.

**From the 2026-07-31 rescope:**

- The schema lands before the first external cohort, so testers' history survives the presentation work
  that follows. This is the whole reason for splitting the slice.
- Per-unit-run rows are more numerous than per-sit rows — a 6-block routine writes 6. Still trivial
  (one insert per completed block, no per-tick writes), and every session-level stat is recoverable by
  grouping on time. Aggregation must do that grouping rather than assuming one row per sitting.
- Streaks being deferred means the app ships to the cohort with **no** habit-pressure mechanic at all.
  That is the honest baseline to measure return rate against: if people come back without a streak, the
  streak was never what brought them.

**From the `pocket-214` amendment (same day):**

- The cohort now meets a real payoff surface, so the log generates signal about **what players look at**,
  not only that it recorded correctly. That was the gap the horizon-blind deferral left open.
- **The marginal cost is smaller than "the Progress screen" sounds.** The aggregation layer was already in
  scope and is where the off-by-one risk lives (day boundaries, week starts, roll-ups); it is already
  required to be pure and unit-tested. The week and month views are two bucketings of values that have to
  exist anyway, and All-time reuses the counts `PracticeStats` already derives.
- **Home's layout is still untouched**, so the ADR 0102 grouping is churned once — when the year tier and
  the card evolution land together — rather than twice.
- **The year tier now has a precondition, not just a date.** It ships when there is a year of history to
  read, which also means the wrapped card is built against real data rather than imagined data.
- **Three surfaces must handle zero rows**, where the deferred design had one that could hide itself. This
  is the slice's main new design cost, and it is front-loaded onto exactly the moment a tester first opens
  the app.
- **Two design elements were reclassified as habit-pressure** (the days-active denominator, the
  week-over-week delta) and travel with streaks. Anyone building the week view from the bullet list above
  will find them struck through there; the reasoning is in Scope.

## Alternatives considered

- **Derive time-windowed stats from existing data (no session log).** Rejected — impossible; there are
  no timestamped practice events to window. Any daily/weekly/monthly number requires the log.
- **Put all five horizons on Home.** Rejected — violates ADR 0102's no-sixth-peer rule and buries the
  practice CTA under a stats wall. One row on Home; the rest lives one tap away.
- **Streaks on by default (the standard habit-app pattern).** Rejected — loss-aversion guilt is a churn
  driver and contradicts ADR 0113's "no streak guilt." Opt-in with weekly-goal + freeze respects the
  players who want streaks without punishing everyone else.
- **Leaderboards / social comparison.** Rejected — off-brand, needs accounts/backend we don't have, and
  comparison to strangers demotivates learners. Measure against the self.
- **Lead with inventory counts (loops made, exercises).** Rejected as the headline — they measure
  library size, not effort, and can decrease on deletion. Kept only as an achievement wall.
- **Any accuracy/performance stat** (pitch, timing, "how clean was that run"). Rejected outright —
  ADR 0070. The player is the judge; the app counts effort, not quality.
- **Store `kind` as a stored SwiftData enum.** Rejected — the documented enum-attr migration crash;
  primitive raw value + computed accessor instead.

**From the 2026-07-31 rescope:**

- **One row per practice sit (the original spec).** Rejected — a routine of six exercises at six tempos
  collapses to one row and one `tempoBPM`, making the per-exercise trajectory underivable. Per-unit-run
  costs the same per write and derives sittings by grouping on time.
- **Ship the log with no surface at all.** Rejected — invisible to the cohort, so it generates no product
  signal during exactly the window it was sequenced to serve, and an unread schema is an untested one.
- **Ship the whole ADR as originally scoped before the cohort.** Rejected — the Progress screen, heatmaps,
  wrapped card and streak machinery are weeks of presentation work whose shape should be informed by usage
  data that does not exist yet. The schema is the only part that must precede the cohort.
- **Log the tempo without its rhythm.** Rejected — ADR 0121 bound a command tempo to the rhythm it was
  measured in for exactly this reason; a trajectory that ignores `notesPerBeat` reads a rhythm change as
  progress or regression that never happened.

**From Slice 1's build:**

- **Write the log on the Done screens** (this ADR's original wording). Rejected — see *The write seam*.
  Those surfaces are optional and skippable; the minutes aren't.
- **Plot every logged tempo on one trajectory line, whatever rhythm it was played at.** Rejected for the
  reason above — so the trajectory covers only the **most recently practised** rhythm and says how many
  runs at other rhythms it set aside, rather than showing a shorter history that reads as the whole story.
- **Log the summited reach rather than the command.** Rejected — command is the tempo the drill is
  consolidated at and the one a promote moves, so it is what a trajectory should trace. It is also read
  *before* the Done screen's optional promote lands, so a row records the tempo that was played, not the
  one the player agreed to next.
- **One `tempoBPM` field with a unit discriminator, covering loops too.** Rejected — a loop's tempo is a
  percent of original (ADR 0082), a different axis entirely. Two fields that are never both set
  (`tempoBPM`, `tempoPercent`) beat one field whose meaning must be decoded before it can be compared.

**From the `pocket-214` amendment:**

- **Keep the whole Progress screen deferred (the `pocket-209` position).** Rejected — it makes the cohort
  unable to generate signal about the surface it was sequenced to serve, and it treats four horizons with
  very different day-one legibility as one indivisible block.
- **Un-defer the Progress screen in full, year tier included.** Rejected — a year view over five weeks of
  history shows one month, and the wrapped card is the most re-engaging artefact in the design *and* the
  designated Pro candidate. Building it before there is anyone to re-engage spends it for nothing, and it
  is where most of the presentation work lives.
- **Evolve `PracticeStatsCard` now so Home leads with a live number.** Rejected — the destination is what
  the screen needs; re-leading the card restructures Home's grouped layout (ADR 0102), which would then be
  restructured again when the year tier lands. A tap-through costs nothing and forecloses nothing.

**From Slice 2's build (the entry point):**

- **Restore the dropped "Your progress" strip to Home and make it tappable**, as this ADR literally
  specified. Rejected — it undoes a deliberate 2026-07-09 decision, and this ADR's *own* reason for
  leaving the card alone was to avoid churning Home twice. Reviving it to hang a push off would be the
  churn, just earlier.
- **Add a "Progress" nav card to Home's "Your stuff" section.** Rejected, though it was the closest thing
  to the ADR's stated intent and would not have broken ADR 0102's no-sixth-peer rule (it is a fourth card
  *inside* a section). It still re-adds weight Home deliberately shed, and it spends the Home change now
  rather than once, later, alongside the year tier.
- **Reach Progress from the Practice space.** Rejected — Practice is where you *do* the work; Journal is
  where you *read back* what you did. A history surface belongs with the history surface.
- **Keep "days active — 4 of 7" and the week-over-week ▲/▼.** Rejected — both are weekly-goal and
  streak-shaped framing under a different name, and shipping them while explicitly deferring streaks would
  re-introduce the habit-pressure lever without any of the mitigations designed to contain it (weekly goal,
  freeze, opt-in). Descriptive now; a target only if and when streaks ship with their guards.
