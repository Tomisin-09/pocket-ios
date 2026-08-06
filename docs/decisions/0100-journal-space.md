# 0100 — A centralised Journal space (notes + takes), and tagging the completion note

- **Status:** Accepted
- **Date:** 2026-07-21 (`pocket-162-journal-space`)

## Context

Journal entries (ADR 0038/0058) and practice takes (ADR 0069) are today only
reachable **inside their owner** — a loop's edit sheet, an exercise/loop run
screen's review bar. There's no way to see your practice history *across
everything* in one place. Wave 2's "build first" item (plan-of-attack
2026-07-20, Note 8) asks for a centralised journal.

Refined in design (2026-07-21, with an interactive mockup):

- It's **notes and takes together**, on one timeline — a personal, reflective
  record of your playing, not just text.
- Both `JournalEntry` and `Recording` are **polymorphic over their owner**
  (loop / exercise / song). So the feed is **cross-cutting**: it spans song
  loops (Library) *and* exercises (Practice). That's the deciding structural
  fact — it belongs *above* both, not nested inside either, and not inside the
  Toolkit hub (ADR 0096), which is deliberately impersonal *reference* while a
  journal is personal *history*.

Separately, a user-testing capture: the post-run completion screen
(`RoutineBlockDoneView`, ADR 0079/0082) offers only a **plain note** — no kind
tag — so every end-of-run note lands as a generic `.note`, even though the full
composer has 🎯 Goal / ⚡️ Breakthrough / 🧗 Struggle / 📝 Note / 🎬 Session. The
moment right after a run is when "breakthrough" vs "struggle" is truest.

## Decision

### 1 — A top-level, read-only Journal space
A new top-level Home destination (`JournalTabView`), wired as the **4th** nav
strip (between Practice and Toolkit; Toolkit stays last), in its own warm-**gold**
`journal` identity — a fifth home hue kept clear of the teal · plum · terracotta
triad and the indigo reference hub.

- **Read-only, by design.** Reflection, not authoring — writing/editing entries
  stays in the per-owner `JournalSheet`. The one exception is **takes**, which
  play in place (playing *is* their nature), through the shared `RecordingPlayer`.
  **Amended 2026-08-05 — see below: every row can now be deleted, and a take
  renamed. Editing still lives in the per-owner sheet.** **Delete is a
  press-and-hold only — there is no delete swipe on this feed, nor on a unit's
  Takes list.** That departs from the libraries, which offer both, and the reason
  is what the row *is*: an exercise deleted by a stray swipe can be built again,
  but a note about how a session went, and a recording of someone playing, cannot.
  A swipe is the gesture most easily fired by accident while scrolling a list, so
  the destructive verb is behind the deliberate gesture and the Undo toast is the
  second line, not the first. Rename stays a swipe as well as a hold — it destroys
  nothing, and it is the verb reached for repeatedly. A note's hold menu offers
  Delete alone; a take's offers Rename then Delete.
- **One merged timeline.** Notes + takes are merged newest-first, day-grouped
  (reusing `JournalGrouping.byDay`), with a segmented **All / Notes / Takes**
  filter — the escape valve as the aggregate grows.
- **Owner attribution.** Unlike the per-owner sheet, the aggregated feed must say
  *what* each item is about: a **loop** reads `"<song> · <loop>"`, an **exercise**
  `"<name> · exercise"`, a song-owned take its title — tinted in the gold accent.
- **Search + sort.** A `.searchable` field matches free text against each item's
  owner (song / loop / exercise name), its **exercise template**, and its **date**
  (`JournalTimeline.searchHaystack` — token-AND, so "scales jul" narrows), and a
  toolbar toggle flips the day order **Newest ↔ Oldest**. Both stay pure/tested; the
  view composes scope → search → group → order.

All the merge / filter / owner-label logic is the pure, UI-free `JournalTimeline`
(unit-tested); the view only queries (two unfiltered `@Query`s — no optional
`#Predicate`, which starves the main thread, ADR-era gotcha), groups, and renders.
**No model change** — it reads `JournalEntry`/`Recording` as they stand.

### 2 — Tag the completion note
`RoutineBlockDoneView` gains a compact **kind selector** (the same five chips,
default `.note`), and its `onContinue` hands back the chosen `EntryKind` alongside
the note. The three hosts (`ExerciseRunView`, `LoopRunView`, `RoutinePlayerView`)
thread it into `JournalWriter.add(kind:)`. Doing nothing keeps the old behaviour
(a plain note). Neutral framing — a label, never a verdict (ADR 0070). Tagged
entries flow straight into the Journal space's filter.

## Alternatives considered

- **Journal as a Toolkit section.** Rejected: Toolkit is impersonal reference;
  personal history reads as the odd one out there, and it's a tap further away.
- **Journal nested under Practice.** Rejected: half its content is song-loop
  entries (Library), which have nothing to do with the Practice space — nesting
  would hide half of what the journal holds.
- **Notes-only surface.** Rejected: notes *and* takes together is what makes it a
  substantial place rather than a thin tab.

## Consequences

- A fifth home hue (`Gold`/`journal` tokens) enters the palette; the hue is
  verified in-context (design brief §3).
- The completion `onContinue` signature changes (adds `kind`) — a mechanical
  update at three call sites, covered by the build.
- Future: the read-only stance leaves room to add a note→owner deep link later
  (jump back to the loop/exercise to keep practising) without reopening this ADR.
