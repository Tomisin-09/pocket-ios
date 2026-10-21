# ADR 0267 — Jump back in reaches a loop, in the mode you left it

- **Status:** Accepted. Built on `pocket-383-jump-back-into-a-loop`.
- **Date:** 2026-10-21
- **Amends:** ADR 0193 — **D1**, *"Four values, and `Loop` is not one of them"*. `Loop` becomes a
  fifth value, and its date comes from the practice log, so it still adds no column. D2 to D6 stand:
  the choosing is pure, a pin with nothing behind it falls back, two doors write one key, the eyebrow
  stays fixed, every gated shape draws its lock, and the key is cleared under `-uiTesting`.
- **Relates to:** 0117 (the practice log this reads) · 0137 D2a (the planner reads loop recency off
  the same log) · 0142 J5a, 0228 and 0265 (the rule for which mode a loop opens in, now shared) ·
  0256 D2–D3 and 0263 D3 (every route to a gated screen meets the wall; two pushed loop screens
  didn't) · 0232 (Map the song's mode hold, which pushes the same screen) ·
  0189 (no schema change).
- **Schema:** none. One bounded `@Query` on Home over `PracticeRun.kindRaw`.

## Context

Tomisin, before preparing the 1.4 release: *"with the jump back in feature, you can jump back into a
song, an exercise or routine but you can't do it for a loop / train your ear / improvise."*

0193 D1 left `Loop` out because `lastPracticed` exists on `Song`, `Routine` and `Exercise` and nowhere
else, and adding one to `Loop` would be "a schema change made for a card". That was right about the
column. It was not a reason to leave loops out, because the data was already on disk somewhere else.
The practice log writes a `PracticeRun` for every loop run you start directly, and each row carries
what the card needs: the loop (`unitUID`), the mode (`kind` is `.loop`, `.earLoop` or `.improvise`),
when (`startedAt`), and `routineUID == nil`. The planner already reads loop recency this way
(`PracticeLog.lastPracticedByUnit`, 0137 D2a).

## Decision

### D1 — One `Loop` value, and the card names the mode

`JumpBackInPreference` gains `.loop`, so the values are *Most recent · Song · Routine · Exercise ·
Loop*. The trainer, ear training and improvise are ways to practise a loop, not three kinds of thing,
so they share one value. The card reopens the loop in the mode of its newest run, and its second line
says which: *Slow Bend · Train your ear*.

**Rejected: three values** (*Loop*, *Train your ear*, *Improvise*). That makes seven entries in a hold
menu, and pinning *Improvise* would keep offering an old jam over a loop you have practised a dozen
times since.

`ResumeKind.loop` is declared last, so a loop loses every tie (song · routine · exercise · loop).

### D2 — The date and the mode come from the log, and only from runs on their own

`HomeFeed.loopResumeCandidates` takes the log's records and returns one candidate per loop, its
newest run, newest first. It differs from the planner's reading twice:

- **It keeps the mode.** The planner asks *when did you last work on this material*. The card has to
  know which screen to reopen.
- **It drops runs inside a routine.** A loop block is the routine's run. Counting it would put a
  routine's own loop block on the card in place of the routine you just played.

Home then takes the first candidate whose loop still exists and can open in some mode.

### D3 — A bounded, live query on a plain column

Home queries the newest 50 loop-mode rows (`HomeFeed.recentLoopRunLimit`), filtered on `kindRaw` and
sorted by `startedAt`. The `routineUID` test runs in memory, because an optional comparison in a
`#Predicate` freezes the main thread (`docs/swiftdata-gotchas.md`).

- **Bounded**, because Home has refused an unbounded query over the log twice (`HomeStatsStrip`,
  `completedSittingCount`). The cost is one edge: if all 50 are inside routines or on deleted loops,
  Home finds no loop and the card falls back as 0193 D3 does. That takes 50 routine loop blocks since
  the last loop you ran on its own.
- **Live**, not a fetch when Home appears. Ear training and improvise write their row in
  `.onDisappear`, which can land after Home's `.onAppear` (0265 D4 saw both orders), and a fetch would
  miss the run just finished.

### D4 — One rule for which mode a loop opens in

`LoopModeAccess.mode(preferring:for:)` returns the mode asked for while the loop still allows it,
else the first it does, else `nil`. It is the rule `JournalOwnerRoute` already applied privately
(0142 J5a, 0228 D2, 0265 D3), and both now call it. A loop whose backing-track flag came off after an
improvise run reopens in the trainer or ear training, not on a screen it can't run.

### D5 — One view pushes a loop in a mode, and every host behind it is gated

`LoopModeScreen(loop:mode:)` is the one switch over `LoopRunView`, `EarTrainingScreen` and
`ImproviseScreen`. Home, the Loops library, the Journal's captions and a piece's hold in Map the song
all push it.

Writing it turned up a gap: `EarTrainingScreen` and `ImproviseScreen` had **no `PlanGated`**, while
`LoopRunView` and both sheet hosts did. The Loops library sits inside the gated Practice hub, so it
hid nothing. But two free screens push them too. **Map the song** is free (0256 D2), and holding a
piece offers *Train your ear* and *Improvise*. The **Journal** went free in 0263, whose D3 says a free
player who taps one of those captions reads the wall. In both places a free player got the screen.
Both screens now wrap their body in `PlanGated(.earTraining)` and `PlanGated(.improvise)`, as
0256 D3 requires: the gate sits on the screen, so every route meets it.

### D6 — What the loop card draws

- **Title:** the loop's name, or *Untitled loop*, as the Loops library writes it.
- **Second line:** the song's title and the mode's label.
- **Last practised:** the run's `startedAt`.
- **Readout:** the loop's mastery for the trainer and ear training. Improvise draws none: a bed to solo
  over isn't something you rate yourself on, which is also why its run logs no tempo.
- **Lock:** drawn while the plan is off, because all three launches are the plan's (0256 D2).

## Consequences

- The Settings footer and the manual (`reference/home-and-library.md`, `reference/settings.md`) name
  five values, and say a loop opens in the mode you last used.
- **No Home reshoot.** `PracticeHistorySeed` stamps the newest song at today 00:00. Its newest loop
  row on its own is yesterday at 14:00, so the seeded card resolves to the same song.
- A free player who opens ear training or improvise from a Journal caption or from Map the song now
  meets the wall, as 0256 D2 put both modes on the plan's side.
- Pure and unit-tested: `HomeFeedTests` (the resume kind with a loop, the fallback, the ties, the
  candidates, the kind-to-mode map) and `LoopModeAccessTests` (the shared mode rule).
  `JournalOwnerRouteTests` and `TakeModeBackfillTests` pin the rules that moved, unchanged.
- `TakeModeBackfill.mode(for:)` moved to `PracticeRunKind.loopRunMode`, where Core can read it.
