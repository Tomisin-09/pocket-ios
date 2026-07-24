# 0117 — Practice stats & the Progress screen: measure effort, never performance; streaks are opt-in

- **Status:** Proposed
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

### The session log — the foundation everything time-windowed needs

A new append-only SwiftData `@Model`, one row per completed practice sit:

- `startedAt: Date`, `durationSeconds: Double` (or `endedAt: Date`) — the spine of every time window.
- `kind` — exercise · routine · loop · recording — stored as a **primitive raw `String`**, not a stored
  enum, with a computed accessor. (Heed the enum-attr migration crash: in-memory tests pass with stored
  enums; the device traps on migration. `docs/swiftdata-gotchas.md`.)
- Optional loose references (exercise / routine identifier as a primitive) so a session can attribute
  minutes to *what* was practiced without a hard relationship that complicates migration or deletion.
- Optional `tempoBPM: Int?` — the factual tempo log, for tempo-record surfacing. Not a grade.

Design rules for the log:

- **Append-only and cheap.** One insert per completed session. No mutation, no per-tick writes.
- **Deletion-safe.** Deleting an exercise must **not** delete its history — the minutes were still
  practised. References are loose (id copies), not cascading relationships, so a stat like "lifetime
  hours" never silently drops when the library is pruned. This is the deliberate opposite of the
  inventory counts' weakness.
- **Aggregation is pure and unit-tested.** All windowing/streak/roll-up math lives behind the pure-logic
  boundary (per AGENTS.md) over plain value structs (`[SessionRecord]`), free of SwiftUI/SwiftData —
  the off-by-one-prone code (day boundaries, week starts, streak breaks, "mastered" thresholds) is
  exactly what breaks silently and so exactly what must be tested. The view runs its `@Query`, maps to
  values, and hands them to the aggregator — mirroring how `PracticeStats.summarize` already works.

### Two tiers of presentation

**Home — one row, no sprawl.** ADR 0102's "don't add a sixth same-weight peer" rule holds: we do **not**
spread five time horizons across the hub. The existing `PracticeStatsCard` evolves to:

- lead with the **most motivating live number** (once the log exists: minutes today / this week against
  the player's goal — or the streak *only if they opted in*),
- keep 2–3 supporting tiles,
- be **tappable → pushes the Progress screen.**

Home stays a *promise*; it never becomes the ledger.

**The Progress screen — the full breadth**, sectioned by horizon so the hub stays lean:

- **This week** — a 7-day minutes bar chart (the *shape* teaches more than any single number), days
  active (e.g. "4 of 7"), total minutes, and this-week-vs-last-week (▲/▼).
- **This month** — a contribution-style calendar heatmap, best day, tempo records set this month.
- **This year** — total hours framed big ("You practiced 87 hours this year"), longest streak of the
  year, month-by-month trend, and a **year-in-review / "wrapped"** card (most-practiced exercise,
  favourite instrument, tempo PRs, first-vs-last). The wrapped card is the single most re-engaging /
  shareable artifact here and is worth building well.
- **All-time** — lifetime hours & sessions ("since you started, 6 May 2026"), longest-ever streak, and
  the **cumulative inventory counts as an achievement / milestone wall** (loops made, exercises, journal
  entries written, loops mastered; milestone badges at 10/50/100/500 h and 7/30/100/365-day streaks).
  This is where the counts the current card shows belong — as *achievements in context*, not as raw
  peers competing with the practice CTA on Home.

**Activity leads, inventory supports.** Effort/activity measures (minutes, sessions, reps, journal
entries *written*, tempo PRs) only ever go up, so they carry the motivation. Inventory counts (how many
loops exist) are secondary texture on the All-time wall, never the headline.

### Streaks are opt-in — off by default

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
