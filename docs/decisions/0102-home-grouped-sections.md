# 0102 — Group the home's nav strips into titled sections

- **Status:** Accepted
- **Date:** 2026-07-21 (`pocket-164-home-grouped-sections`)

## Context

The home hub (`HomeView`, ADR 0044) grew its top-level destinations one ADR at a
time — Song library, Metronome, Practice (ADR 0046), Journal (ADR 0100), Toolkit
(ADR 0096) — each landing as another full-width nav strip in a single flat
`VStack`, each carrying its own identity hue (terracotta · plum · teal · gold ·
indigo). At five same-weight, one-hue-each strips the run reads as clutter, and
the palette is effectively spent: a sixth destination (**Red Moon Oracle**, the
AI space, ADR 0092) has no calm slot and no free hue to claim without either
inventing a sixth accent or making two strips share one and losing the
one-hue-per-destination logic.

The problem isn't the row *count* — it's that five peers of identical visual
weight compete flatly with no hierarchy. Reviewed against layout alternatives
(2026-07-21, with an interactive mockup): a real tab bar (large architectural
change, ~5-tab ceiling), a 2-column tile grid (loses the subtitles and the calm
list feel), and merging destinations were all weighed. Grouping the existing
strips into titled sections was chosen as the lowest-risk change that restores
hierarchy while keeping every destination top-level and reusing `HomeNavCard`
untouched.

## Decision

### 1 — Titled sections replace the flat strip run
A new presentational `HomeSection` (uppercase eyebrow header + a tight stack of
its strips) wraps the destinations. Sections breathe at the 20-pt rhythm; strips
within a section stay tight at 10 pt. The header carries `.isHeader` so VoiceOver
announces the grouping. The strip view-builders (`practiceCard`, `metronomeCard`,
…) and — critically — **their accessibility labels are unchanged**; only their
container and order change. Those labels are the UI-test contract (cards are
selected by label, not position), so the regroup is nearly free on the test side.

### 2 — Interim two-section split, three when Oracle ships
Because Oracle isn't built yet, and a section holding a lone Toolkit would read as
odd, the interim is **two** sections:

- **Practice** — Practice · Metronome
- **Your stuff** — Song library · Journal · Toolkit

When Red Moon Oracle lands, Toolkit moves out of "Your stuff" into a new **Learn**
section beside Oracle — a one-card move plus one new card, scoped as that
feature's own PR. "Your stuff" is a deliberately temporary home for Toolkit
(impersonal *reference* material); it gets its right label ("Learn") on the split.

### 3 — The durable rule
New top-level home destinations join an existing **section** (or open a new one),
never a sixth flat peer strip. This is what keeps the home calm as it accrues
places, and it supersedes the ADR-0100/0096 framing of destinations as ordinal
strips ("4th strip", "5th strip").

## Alternatives considered

- **A real bottom tab bar.** Rejected for now: the biggest architectural shift
  (root moves from a card-scroll to a `TabView`), and the ~5-tab ceiling only buys
  room if paired with merging — deferred, not foreclosed.
- **2-column tile grid.** Rejected: compact, but drops the one-line subtitles and
  the calmer list feel the current design leans on.
- **Merge Oracle into Toolkit (no new top-level place).** A viable deeper fix if
  AI stays a single surface; kept open. Grouping doesn't block it — Oracle can
  still debut inside Toolkit later without reopening this ADR.
- **Give Oracle a sixth hue in the existing flat list.** Rejected: that is exactly
  the crowding this ADR resolves.

## Consequences

- No model change, no new hue; `HomeNavCard` and all accessibility labels are
  untouched, so existing home UI tests keep passing by construction.
- `PracticeRunUITests` gains a scroll-into-view guard (Practice is no longer
  assumed at a fixed offset); the stale ordinal comment in `ToolkitUITests` is
  reworded to the section model.
- The Oracle PR is pre-scoped: move Toolkit into a new "Learn" section + add the
  Oracle card. This ADR records that split as the expected next step.
